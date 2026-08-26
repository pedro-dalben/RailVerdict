# frozen_string_literal: true

require "digest"
require "json"

require_relative "canonical_json"
require_relative "schema_validator"

module RailVerdict
  class Handoff
    SCHEMA_VERSION = "1.0"
    ID_PATTERN = /\Asha256:[0-9a-f]{64}\z/
    MAX_DOCUMENT_BYTES = 256 * 1024

    class BuildError < RailVerdict::Error
      attr_reader :code
      def initialize(code, message)
        @code = code.to_s
        super(message)
      end
    end

    attr_reader :document

    def self.build(receipt:, evidence_set:, railverdict_version: RailVerdict::VERSION, evidence_provenance: nil, source_scope: nil)
      raise BuildError.new(:handoff_unavailable, "receipt is required") if receipt.nil? || !receipt.is_a?(Hash)
      raise BuildError.new(:handoff_unavailable, "evidence_set is required") if evidence_set.nil? || !evidence_set.is_a?(Hash)

      # Validate receipt structurally (reuse Receipt validation without re-persisting)
      errors = SchemaValidator.validate_receipt(receipt)
      raise BuildError.new(:receipt_schema_invalid, errors.join("; ")) unless errors.empty?

      payload = {
        "schema_version" => SCHEMA_VERSION,
        "railverdict_version" => railverdict_version.to_s,
        "receipt" => receipt,
        "evidence_set" => normalize_evidence_set(evidence_set)
      }
      payload["evidence_provenance"] = normalize_provenance(evidence_provenance) if evidence_provenance
      payload["source_scope"] = normalize_scope(source_scope) if source_scope

      document = payload.merge("handoff_id" => id_for(payload))
      errors = SchemaValidator.validate_handoff(document)
      raise BuildError.new(:handoff_schema_violation, errors.join("; ")) unless errors.empty?
      raise BuildError.new(:handoff_too_large, "handoff exceeds #{MAX_DOCUMENT_BYTES} bytes") if JSON.generate(document).bytesize > MAX_DOCUMENT_BYTES

      deep_freeze(document)
    end

    def self.id_for(payload)
      "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(payload))}"
    end

    def self.normalize_evidence_set(set)
      # Ensure deterministic ordering: sorted by analyzer, findings sorted by fingerprint
      results = Array(set["analyzer_results"] || set[:analyzer_results]).map do |ar|
        h = {
          "analyzer" => ar["analyzer"] || ar[:analyzer],
          "execution_status" => ar["execution_status"] || ar[:execution_status]
        }
        tv = ar["tool_version"] || ar[:tool_version]
        h["tool_version"] = tv.nil? ? nil : tv.to_s
        findings = Array(ar["findings"] || ar[:findings]).map { |f| f.is_a?(Hash) ? f : {} }.sort_by { |f| f["fingerprint"] || "" }
        h["findings"] = findings if findings.any?
        h
      end.sort_by { |ar| ar["analyzer"] }
      { "analyzer_results" => results }
    end
    private_class_method :normalize_evidence_set

    def self.normalize_provenance(prov)
      return nil unless prov.is_a?(Hash)
      out = {}
      av = prov["analyzer_versions"] || prov[:analyzer_versions]
      if av.is_a?(Hash) && av.any?
        coerced = av.reject { |_, value| value.nil? }.transform_values { |value| value.to_s }
        out["analyzer_versions"] = coerced.sort.to_h unless coerced.empty?
      end
      db = prov["advisory_db_revision"] || prov[:advisory_db_revision]
      out["advisory_db_revision"] = db.to_s if db
      out
    end
    private_class_method :normalize_provenance

    def self.normalize_scope(scope)
      return nil unless scope.is_a?(Hash)
      out = {}
      vm = scope["verification_mode"] || scope[:verification_mode]
      out["verification_mode"] = vm.to_s if vm
      cb = scope["changed_base"] || scope[:changed_base]
      out["changed_base"] = cb.to_s if cb
      mb = scope["changed_merge_base"] || scope[:changed_merge_base]
      out["changed_merge_base"] = mb.to_s if mb
      out
    end
    private_class_method :normalize_scope

    def self.deep_freeze(value)
      case value
      when Hash then value.each { |k, v| k.freeze if k.is_a?(String); deep_freeze(v) }; value.freeze
      when Array then value.each { |c| deep_freeze(c) }; value.freeze
      when String then value.freeze
      else value
      end
    end

    def self.parse(text)
      return [nil, :handoff_too_large] if text.bytesize > MAX_DOCUMENT_BYTES
      document = begin JSON.parse(text) rescue return [nil, :handoff_malformed] end
      parse_document(document)
    end

    def self.parse_document(document)
      return [nil, :handoff_malformed] unless document.is_a?(Hash)
      return [nil, :incompatible_handoff_version] unless document["schema_version"] == SCHEMA_VERSION
      errors = SchemaValidator.validate_handoff(document)
      return [nil, :handoff_schema_invalid] unless errors.empty?
      stored = document["handoff_id"]
      payload = document.reject { |k, _| k == "handoff_id" }
      expected = id_for(payload)
      return [nil, :handoff_integrity_failed] unless stored == expected
      [deep_freeze(document), nil]
    end
  end
end
