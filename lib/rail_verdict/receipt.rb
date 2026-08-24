# frozen_string_literal: true

require "digest"
require "json"

require_relative "canonical_json"
require_relative "repository_state"
require_relative "schema_validator"

module RailVerdict
  class Receipt
    SCHEMA_VERSION = "1.0"
    ID_PATTERN = /\Asha256:[0-9a-f]{64}\z/
    MAX_DOCUMENT_BYTES = 256 * 1024
    VOLATILE_TEST_KEYS = %w[duration_seconds seed].freeze

    class BuildError < RailVerdict::Error
      attr_reader :code

      def initialize(code, message)
        @code = code.to_s
        super(message)
      end
    end

    attr_reader :document

    # Builds a Verification Receipt v1 document from a guarded Check outcome.
    # Fails closed (BuildError with a deterministic code) when repository state
    # cannot be proven stable across the verification.
    def self.build(outcome:, railverdict_version: RailVerdict::VERSION, pr_intelligence_document: nil, repair_packet_id: nil, environment_ruby_version: RUBY_VERSION)
      result = outcome&.result
      raise BuildError.new(:receipt_unavailable, "verification outcome is required") if result.nil?

      pre = outcome.repository_state_pre
      post = outcome.repository_state_post
      unless pre && pre.available? && post && post.available?
        reason = [pre, post].compact.map(&:unavailable_reason).compact.first || :repository_state_unavailable
        raise BuildError.new(:repository_state_unavailable, "repository state could not be determined: #{reason}")
      end
      if pre.digest != post.digest
        raise BuildError.new(:repository_changed_during_verification, "repository changed while verification was running")
      end

      components = post.components
      changed_scope = changed_scope_of(result)
      payload = {
        "schema_version" => SCHEMA_VERSION,
        "railverdict_version" => railverdict_version.to_s,
        "environment" => {
          "ruby_version" => environment_ruby_version.to_s,
          "analyzer_versions" => sorted_analyzer_versions(outcome)
        },
        "verification_mode" => changed_scope ? "changed" : "full",
        "changed_scope" => changed_scope,
        "repository_state" => {
          "head" => components.fetch("head"),
          "index_digest" => components.fetch("index_digest"),
          "worktree_digest" => components.fetch("worktree_digest"),
          "configuration_digest" => components.fetch("configuration_digest"),
          "baseline_digest" => components.fetch("baseline_digest"),
          "waivers_digest" => components.fetch("waivers_digest")
        },
        "gate_projection" => gate_projection(result),
        "pr_intelligence" => pr_intelligence_binding(pr_intelligence_document),
        "repair" => repair_binding(repair_packet_id)
      }
      document = payload.merge("receipt_id" => id_for(payload))
      errors = SchemaValidator.validate_receipt(document)
      raise BuildError.new(:receipt_schema_violation, "receipt failed its own schema: #{errors.join('; ')}") unless errors.empty?

      deep_freeze(document)
    end

    def self.deep_freeze(value)
      case value
      when Hash
        value.each { |key, child| key.freeze if key.is_a?(String); deep_freeze(child) }
        value.freeze
      when Array
        value.each { |child| deep_freeze(child) }
        value.freeze
      when String
        value.freeze
      else
        value
      end
    end

    def self.id_for(payload)
      "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(payload))}"
    end

    def self.sorted_analyzer_versions(outcome)
      versions = {}
      context_versions = outcome.context&.analyzer_versions
      if context_versions.is_a?(Hash) && !context_versions.empty?
        context_versions.each do |key, value|
          versions[key.to_s] = RailVerdict::Analyzers::Shared.canonical_tool_version(value)
        end
      else
        Array(outcome.result.analyzer_results).each do |analyzer|
          next unless analyzer.tool_version.is_a?(String) && !analyzer.tool_version.strip.empty?

          versions[analyzer.analyzer] = RailVerdict::Analyzers::Shared.canonical_tool_version(analyzer.tool_version)
        end
      end
      versions.sort.to_h
    end
    private_class_method :sorted_analyzer_versions

    def self.changed_scope_of(result)
      git = result.git
      return nil unless git.is_a?(Hash) && git["base"]

      scope = { "base" => git["base"] }
      scope["merge_base"] = git["merge_base"] if git["merge_base"]
      scope
    end
    private_class_method :changed_scope_of

    def self.gate_projection(result)
      schema_h = result.to_schema_h
      {
        "completion_status" => schema_h.fetch("completion_status"),
        "gate" => schema_h.fetch("gate"),
        "policy_status" => schema_h.fetch("policy_status"),
        "findings" => schema_h.fetch("findings").sort_by { |finding| finding.fetch("fingerprint") },
        "analyzer_evidence" => schema_h.fetch("analyzer_results").map do |analyzer|
          {
            "analyzer" => analyzer.fetch("analyzer"),
            "execution_status" => analyzer.fetch("execution_status"),
            "tool_version" => analyzer.key?("tool_version") ? analyzer.fetch("tool_version") : nil
          }
        end.sort_by { |entry| entry.fetch("analyzer") },
        "operational_failure_codes" => schema_h.fetch("operational_failures").map { |failure| failure.fetch("code") }.sort,
        "decision_reason_codes" => schema_h.fetch("decision_reasons").map { |reason| reason.fetch("code") }.sort
      }
    end
    private_class_method :gate_projection

    def self.pr_intelligence_binding(document)
      return nil if document.nil?

      digest = Digest::SHA256.hexdigest(CanonicalJSON.generate(PRIntelligence.stable_projection(document)))
      { "digest" => "sha256:#{digest}" }
    end
    private_class_method :pr_intelligence_binding

    def self.repair_binding(packet_id)
      return nil if packet_id.nil? || packet_id.to_s.empty?

      unless packet_id.match?(ID_PATTERN)
        raise BuildError.new(:invalid_repair_packet_id, "repair packet id must be a sha256: identity")
      end

      { "packet_id" => packet_id }
    end
    private_class_method :repair_binding

    # Parses and structurally validates a receipt document.
    # Returns [receipt_or_nil, invalid_reason_code_or_nil].
    def self.parse(text)
      if text.bytesize > MAX_DOCUMENT_BYTES
        return [nil, :receipt_too_large]
      end

      document = begin
        JSON.parse(text)
      rescue JSON::ParserError
        return [nil, :receipt_malformed]
      end
      parse_document(document)
    end

    def self.parse_document(document)
      unless document.is_a?(Hash)
        return [nil, :receipt_malformed]
      end
      unless document["schema_version"] == SCHEMA_VERSION
        return [nil, :incompatible_receipt_version]
      end

      errors = SchemaValidator.validate_receipt(document)
      return [nil, :receipt_schema_invalid] unless errors.empty?

      stored_id = document["receipt_id"]
      identity_payload = document.reject { |key, _| key == "receipt_id" }
      expected = id_for(identity_payload)
      return [nil, :receipt_integrity_failed] unless stored_id == expected

      [new(document.freeze), nil]
    end

    def self.load(path)
      text = begin
        File.binread(path)
      rescue StandardError
        return [nil, :receipt_unreadable]
      end
      parse(text)
    end

    def initialize(document)
      @document = document
    end

    def receipt_id
      @document.fetch("receipt_id")
    end

    def gate
      @document.dig("gate_projection", "gate")
    end

    def completion_status
      @document.dig("gate_projection", "completion_status")
    end

    def repository_state_projection
      components = state_components_of(@document.fetch("repository_state"))
      {
        "schema_version" => RepositoryState::SCHEMA_VERSION,
        "digest" => "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(components))}",
        "components" => components
      }
    end

    def state_components_of(state)
      {
        "head" => state.fetch("head"),
        "index_digest" => state.fetch("index_digest"),
        "worktree_digest" => state.fetch("worktree_digest"),
        "configuration_digest" => state.fetch("configuration_digest"),
        "baseline_digest" => state.fetch("baseline_digest"),
        "waivers_digest" => state.fetch("waivers_digest")
      }
    end
    private :state_components_of

    Validation = Struct.new(:status, :reasons, :gate, :completion_status, :current_repository_digest, keyword_init: true)

    FRESH = "fresh"
    STALE = "stale"
    INVALID = "invalid"
    UNAVAILABLE = "unavailable"

    # Full black-box evaluation of a serialized receipt document against the
    # current state: integrity first (invalid), then freshness.
    # Returns [validation_document, receipt_or_nil].
    def self.evaluate(document_text, current_state:, railverdict_version: RailVerdict::VERSION, environment_ruby_version: RUBY_VERSION, current_analyzer_versions: nil)
      receipt, reason = parse(document_text)
      if reason
        return [validation_document(
          Validation.new(status: INVALID, reasons: [reason.to_s], gate: nil, completion_status: nil, current_repository_digest: nil),
          receipt_id: embedded_receipt_id(document_text)
        ), nil]
      end

      validation = validate_freshness(
        receipt: receipt,
        current_state: current_state,
        railverdict_version: railverdict_version,
        environment_ruby_version: environment_ruby_version,
        current_analyzer_versions: current_analyzer_versions
      )
      [validation_document(validation, receipt_id: receipt.receipt_id), receipt]
    end

    def self.embedded_receipt_id(document_text)
      parsed = begin
        JSON.parse(document_text)
      rescue StandardError
        return nil
      end
      id = parsed.is_a?(Hash) ? parsed["receipt_id"] : nil
      id.is_a?(String) && id.match?(ID_PATTERN) ? id : nil
    end
    private_class_method :embedded_receipt_id

    def self.validation_document(validation, receipt_id:)
      document = {
        "schema_version" => SCHEMA_VERSION,
        "status" => validation.status,
        "receipt_id" => receipt_id,
        "reasons" => validation.reasons,
        "gate" => validation.gate,
        "completion_status" => validation.completion_status,
        "current_repository_digest" => validation.current_repository_digest
      }
      errors = SchemaValidator.validate_receipt_validation(document)
      raise RailVerdict::Error, "receipt-validation-v1 failed: #{errors.join('; ')}" unless errors.empty?

      document
    end
    private_class_method :validation_document

    # Validates a parsed receipt against the current observable state.
    # Analyzer versions cannot be observed without spawning analyzers, so
    # callers that possess fresh analyzer versions may supply them via
    # +current_analyzer_versions+; otherwise that comparison is skipped and
    # evidence remains bound through the canonical gate projection digest.
    def self.validate_freshness(receipt:, current_state:, railverdict_version: RailVerdict::VERSION, environment_ruby_version: RUBY_VERSION, current_analyzer_versions: nil)
      unless current_state.available?
        return Validation.new(
          status: UNAVAILABLE,
          reasons: ["repository_state_unavailable:#{current_state.unavailable_reason}"],
          gate: receipt&.gate,
          completion_status: receipt&.completion_status,
          current_repository_digest: nil
        )
      end

      stored = receipt.repository_state_projection.fetch("components")
      current = current_state.components
      reasons = []
      reasons << "head_changed" if stored.fetch("head") != current.fetch("head")
      reasons << "index_changed" if stored.fetch("index_digest") != current.fetch("index_digest")
      reasons << "worktree_changed" if stored.fetch("worktree_digest") != current.fetch("worktree_digest")
      reasons << "configuration_changed" if stored.fetch("configuration_digest") != current.fetch("configuration_digest")
      reasons << "baseline_changed" if stored.fetch("baseline_digest") != current.fetch("baseline_digest")
      reasons << "waivers_changed" if stored.fetch("waivers_digest") != current.fetch("waivers_digest")

      environment = receipt.document.fetch("environment")
      reasons << "railverdict_version_changed" if receipt.document.fetch("railverdict_version") != railverdict_version.to_s
      reasons << "ruby_version_changed" if environment.fetch("ruby_version") != environment_ruby_version.to_s
      if current_analyzer_versions.is_a?(Hash) && !current_analyzer_versions.empty? &&
         environment.fetch("analyzer_versions") != current_analyzer_versions.sort.to_h.transform_values(&:to_s)
        reasons << "analyzer_environment_changed"
      end

      Validation.new(
        status: reasons.empty? ? FRESH : STALE,
        reasons: reasons.sort,
        gate: receipt.gate,
        completion_status: receipt.completion_status,
        current_repository_digest: current_state.digest
      )
    end
  end
end
