# frozen_string_literal: true

module RailVerdict
  module Intelligence
    module Orchestrator
      def self.explain(outcome:, finding_ref:, configuration: nil, provider: nil, cache: nil)
        config = configuration || outcome.configuration
        unless config&.ai_enabled?
          return { analysis: nil, failure: AIFailure.new(code: "disabled", message: "AI is disabled"), manifest: nil }
        end

        manifest = ContextBuilder.build(outcome: outcome, finding_ref: finding_ref)
        budget = Budget.new(config.ai_budgets)
        begin
          budget.enforce!(manifest)
        rescue AIFailure => failure
          return { analysis: nil, failure: failure, manifest: manifest }
        rescue StandardError => e
          failure = e.is_a?(AIFailure) ? e : AIFailure.new(code: "budget_exhausted", message: e.message)
          return { analysis: nil, failure: failure, manifest: manifest }
        end

        redaction = Redactor.redact(manifest, trust: config.ai_remote_trust)
        if redaction.secret_detected && config.ai_remote_enabled? && config.ai_remote_trust == "full"
          return { analysis: nil, failure: AIFailure.new(code: "secret_detected", message: "probable secret detected; remote transmission blocked"), manifest: manifest }
        end
        manifest = redaction.manifest || manifest

        unless config.ai_remote_enabled?
          return { analysis: nil, failure: AIFailure.new(code: "disabled", message: "remote AI not enabled"), manifest: manifest }
        end

        cache_key = nil
        if cache&.enabled?
          cache_key = cache.key_for(
            fingerprint: manifest.fingerprint,
            context_hash: manifest.context_hash,
            provider: provider.class.name,
            model: config.ai_config&.fetch("model", "unknown") || "unknown",
            prompt_version: PROMPT_VERSION,
            schema_version: AIAnalysis::SCHEMA_VERSION
          )
          cached = cache.read(cache_key)
          return { analysis: cached, failure: nil, manifest: manifest } if cached
        end

        prompt = Prompt.build(manifest)
        prov = provider || (config.ai_config&.dig("provider") == "openai_compat" ? Providers::OpenAICompatProvider.new(endpoint: config.ai_config.dig("remote", "endpoint") || Providers::OpenAICompatProvider::ENDPOINT) : Providers::FakeProvider.new)
        request = AIProvider::Request.new(
          manifest: manifest.to_json_hash,
          prompt: prompt,
          model: config.ai_config&.fetch("model", nil),
          timeouts: { connect: 5, read: 30 }
        )

        result = prov.analyze(request)
        if result.analysis && cache_key && cache&.enabled?
          cache.write(cache_key, result.analysis)
        end

        { analysis: result.analysis, failure: result.failure, manifest: manifest }
      rescue ArgumentError => error
        { analysis: nil, failure: AIFailure.new(code: "context_rejected", message: error.message), manifest: nil }
      rescue StandardError => error
        { analysis: nil, failure: AIFailure.new(code: "provider_unavailable", message: error.message[0, 512]), manifest: nil }
      end

      def self.investigate(outcome:, configuration: nil, provider: nil, cache: nil, limit: 3)
        findings = outcome.findings || []
        selected = Budget.select_findings(findings, limit: [limit, 3].min)
        selected.map do |finding|
          explain(outcome: outcome, finding_ref: finding.id, configuration: configuration, provider: provider, cache: cache)
        end
      end
    end
  end
end
