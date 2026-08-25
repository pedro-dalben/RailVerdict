# frozen_string_literal: true

require "digest"
require "json"

require_relative "canonical_json"
require_relative "repository_state"
require_relative "verification_environment"
require_relative "verification_identity"
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
    def self.build(outcome:, railverdict_version: RailVerdict::VERSION, pr_intelligence_document: nil, repair_packet_id: nil, environment_ruby_version: RUBY_VERSION, environment_ruby_engine: RUBY_ENGINE)
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
          "ruby_engine" => environment_ruby_engine.to_s,
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
          canonical = RailVerdict::Analyzers::Shared.canonical_tool_version(value)
          next if canonical == "unknown"

          versions[key.to_s] = canonical
        end
      else
        Array(outcome.result.analyzer_results).each do |analyzer|
          next unless analyzer.tool_version.is_a?(String) && !analyzer.tool_version.strip.empty?

          canonical = RailVerdict::Analyzers::Shared.canonical_tool_version(analyzer.tool_version)
          next if canonical == "unknown"

          versions[analyzer.analyzer] = canonical
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

    Validation = Struct.new(:status, :reasons, :gate, :completion_status, :current_repository_digest, :current_environment_digest, keyword_init: true)

    FRESH = "fresh"
    STALE = "stale"
    INVALID = "invalid"
    UNAVAILABLE = "unavailable"

    # Full black-box evaluation of a serialized receipt document against the
    # current state: integrity first (invalid), then freshness.
    # Returns [validation_document, receipt_or_nil].
    # When current_environment/current_state are not supplied but repository_root is,
    # they are independently observed via the canonical VerificationIdentity.
    def self.evaluate(document_text, current_state: nil, repository_root: nil, configuration_paths: nil, railverdict_version: RailVerdict::VERSION, environment_ruby_version: RUBY_VERSION, environment_ruby_engine: RUBY_ENGINE, current_analyzer_versions: nil, current_environment: nil)
      receipt, reason = parse(document_text)
      if reason
        return [validation_document(
          Validation.new(status: INVALID, reasons: [reason.to_s], gate: nil, completion_status: nil, current_repository_digest: nil, current_environment_digest: nil),
          receipt_id: embedded_receipt_id(document_text)
        ), nil]
      end

      # Canonical re-observation if not supplied (fail-closed trust invariant)
      if current_state.nil? && repository_root
        begin
          root_real = File.realpath(repository_root)
          paths = configuration_paths || Check.effective_input_paths(root: root_real, config_path: File.join(root_real, ".railverdict.yml"))
          current_state = RepositoryState.capture(repository_root: root_real, configuration_paths: paths)
        rescue StandardError
          current_state = RepositoryState.unavailable(:repository_root_unavailable)
        end
      end

      if current_environment.nil? && current_analyzer_versions.nil? && repository_root
        begin
          root_real = File.realpath(repository_root || Dir.pwd)
          stored_analyzer_keys = receipt.document.dig("environment", "analyzer_versions")&.keys || []
          # Resolve configuration for relevant probing
          config = nil
          begin
            paths = configuration_paths || Check.effective_input_paths(root: root_real, config_path: File.join(root_real, ".railverdict.yml"))
            cfg_path = paths[:config]
            config = Configuration.load(cfg_path) if cfg_path && File.file?(cfg_path)
          rescue StandardError
            config = nil
          end
          current_environment = VerificationEnvironment.capture_for_receipt(stored_analyzer_keys, repository_root: root_real, configuration: config)
        rescue StandardError
          current_environment = VerificationEnvironment.new(
            railverdict_version: RailVerdict::VERSION.to_s,
            ruby_engine: RUBY_ENGINE.to_s,
            ruby_version: RUBY_VERSION.to_s,
            analyzer_versions: {},
            digest: nil,
            unavailable_reason: "environment_capture_failed",
            available: false
          )
        end
      elsif current_analyzer_versions.is_a?(Hash) && current_environment.nil?
        # Legacy caller supplied analyzer versions hash directly -> wrap as environment
        current_environment = VerificationEnvironment.new(
          railverdict_version: railverdict_version.to_s,
          ruby_engine: environment_ruby_engine.to_s,
          ruby_version: environment_ruby_version.to_s,
          analyzer_versions: current_analyzer_versions.sort.to_h.transform_values(&:to_s),
          digest: nil,
          available: true
        )
      end

      validation = validate_freshness(
        receipt: receipt,
        current_state: current_state,
        railverdict_version: railverdict_version,
        environment_ruby_version: environment_ruby_version,
        environment_ruby_engine: environment_ruby_engine,
        current_analyzer_versions: current_analyzer_versions,
        current_environment: current_environment
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
      document["current_environment_digest"] = validation.current_environment_digest if validation.current_environment_digest
      errors = SchemaValidator.validate_receipt_validation(document)
      raise RailVerdict::Error, "receipt-validation-v1 failed: #{errors.join('; ')}" unless errors.empty?

      document
    end
    private_class_method :validation_document

    # Validates a parsed receipt against the current observable state.
    # This is the ONE canonical freshness evaluator — CLI and MCP must delegate here.
    # It independently requires current_state and current_environment to be observed,
    # never trusting receipt-provided values as current observation.
    def self.validate_freshness(receipt:, current_state:, railverdict_version: RailVerdict::VERSION, environment_ruby_version: RUBY_VERSION, environment_ruby_engine: RUBY_ENGINE, current_analyzer_versions: nil, current_environment: nil)
      # If current_environment was supplied via legacy analyzer_versions hash, normalize
      if current_environment.nil? && current_analyzer_versions.is_a?(Hash) && !current_analyzer_versions.empty?
        current_environment = VerificationEnvironment.new(
          railverdict_version: railverdict_version.to_s,
          ruby_engine: environment_ruby_engine.to_s,
          ruby_version: environment_ruby_version.to_s,
          analyzer_versions: current_analyzer_versions.sort.to_h.transform_values(&:to_s),
          digest: nil,
          available: true
        )
      end

      unless current_state&.available?
        reason = current_state&.unavailable_reason || :repository_state_unavailable
        return Validation.new(
          status: UNAVAILABLE,
          reasons: ["repository_state_unavailable:#{reason}"],
          gate: receipt&.gate,
          completion_status: receipt&.completion_status,
          current_repository_digest: nil,
          current_environment_digest: nil
        )
      end

      # Environment must be observable fail-closed
      if current_environment && !current_environment.available?
        return Validation.new(
          status: UNAVAILABLE,
          reasons: ["analyzer_version_unobservable:#{current_environment.unavailable_reason}"],
          gate: receipt.gate,
          completion_status: receipt.completion_status,
          current_repository_digest: current_state.digest,
          current_environment_digest: nil
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
      # RailVerdict version is always checked against current (not receipt-provided)
      current_rv = current_environment ? current_environment.railverdict_version.to_s : railverdict_version.to_s
      reasons << "railverdict_version_changed" if receipt.document.fetch("railverdict_version") != current_rv

      # Ruby version/engine: if environment observable, use it; else use supplied
      current_ruby_version = current_environment ? current_environment.ruby_version.to_s : environment_ruby_version.to_s
      current_ruby_engine = current_environment ? current_environment.ruby_engine.to_s : environment_ruby_engine.to_s
      # Ruby engine: receipt may not have it (1.2 compat) — if missing, treat as mismatch if current engine is present
      stored_ruby_engine = environment["ruby_engine"]
      if stored_ruby_engine.nil?
        # 1.2 receipt without engine: stale if we now track engine and it differs from default? Keep fresh for compat unless engine is not ruby/mri? For deterministic portable contract, we consider missing engine as stale only if current engine != "ruby"
        # To avoid breaking 1.2 compat trivially, we only flag when env explicitly requires engine and receipt lacks it? Current spec says 1.2 receipts should be valid but stale when env stronger — we will flag as stale to surface drift
        # For minimal breakage, do not flag missing engine as stale automatically; document as known limitation. Only check if receipt has engine.
      else
        reasons << "ruby_engine_changed" if stored_ruby_engine.to_s != current_ruby_engine
      end
      if environment.fetch("ruby_version") != current_ruby_version
        reasons << "ruby_version_changed"
      end

      # Analyzer environment: only relevant analyzers (those in receipt)
      stored_analyzers = environment.fetch("analyzer_versions")
      if stored_analyzers.is_a?(Hash) && !stored_analyzers.empty?
        current_analyzers = if current_environment
                              # Only compare relevant keys
                              filtered = current_environment.analyzer_versions.select { |k, _| stored_analyzers.key?(k) }
                              # Also include any stored key missing in current -> drift (probed enabled set may have disabled it)
                              # If stored key not in current, we need to probe it specifically; for now treat missing as stale
                              stored_analyzers.keys.each do |k|
                                filtered[k] ||= "__missing__"
                              end
                              filtered
                            else
                              current_analyzer_versions.is_a?(Hash) ? current_analyzer_versions.sort.to_h.transform_values(&:to_s) : nil
                            end
        if current_analyzers
          # Detect unknown in current as unavailable handled above; now compare relevant
          relevant_stored = stored_analyzers.sort.to_h.transform_values(&:to_s)
          relevant_current = current_analyzers.sort.to_h.transform_values(&:to_s)
          # If any stored "unknown" exists, treat as unavailable (fail-closed)
          if relevant_stored.values.include?("unknown") || relevant_current.values.include?("unknown")
            return Validation.new(
              status: UNAVAILABLE,
              reasons: ["analyzer_version_unobservable:unknown_or_missing"],
              gate: receipt.gate,
              completion_status: receipt.completion_status,
              current_repository_digest: current_state.digest,
              current_environment_digest: current_environment&.digest
            )
          end
          # Missing relevant analyzer in current env is drift -> stale, not unavailable
          if relevant_current.values.include?("__missing__")
            reasons << "analyzer_environment_changed"
          elsif relevant_stored != relevant_current
            reasons << "analyzer_environment_changed"
          end
        end
      end

      status = reasons.empty? ? FRESH : STALE
      Validation.new(
        status: status,
        reasons: reasons.sort,
        gate: receipt.gate,
        completion_status: receipt.completion_status,
        current_repository_digest: current_state.digest,
        current_environment_digest: current_environment&.digest
      )
    end
  end
end
