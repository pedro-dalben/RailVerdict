# frozen_string_literal: true

module RailVerdict
  # Deterministic Rails-aware change surface detection.
  #
  # Every surface is a pure function of changed file paths. Each reported
  # surface carries its evidence paths; nothing is ever asserted without
  # evidence. Detection tier is explicit:
  # - "detected": strong Rails path convention (reliable).
  # - "inferred": filename heuristic, documented as such (see AUTHENTICATION,
  #   PUBLIC_API, and the name-pattern tier of SECURITY).
  module ChangeSurfaces
    MAX_EVIDENCE = 20

    # id => { label, detection, matchers: [lambdas], default_risk }
    # default_risk nil means the surface is not sensitive by default.
    SURFACES = {
      "security" => {
        "label" => "Security",
        "detection" => "mixed",
        "default_risk" => "critical",
        "matchers" => [
          lambda { |path| path.start_with?("config/credentials/") || path == "config/credentials.yml.enc" },
          lambda { |path| path == "config/master.key" || path == "config/credentials.key" },
          lambda { |path| path.start_with?("config/initializers/") && path.match?(/secret|credential|csp|secure_headers|ssl|force_ssl/i) }
        ]
      },
      "authorization" => {
        "label" => "Authorization",
        "detection" => "detected",
        "default_risk" => "high",
        "matchers" => [
          lambda { |path| path.start_with?("app/policies/") },
          lambda { |path| path == "app/models/ability.rb" || path.end_with?("/ability.rb") },
          lambda { |path| path.include?("/abilities/") && path.end_with?(".rb") }
        ]
      },
      "authentication" => {
        "label" => "Authentication",
        "detection" => "inferred",
        "default_risk" => "high",
        "matchers" => [
          lambda { |path| path == "config/initializers/devise.rb" },
          lambda { |path| path.match?(%r{\Aapp/controllers/.*sessions?_controller\.rb\z}) },
          lambda { |path| path.match?(%r{\Aapp/controllers/.*(passwords|registrations|unlocks|confirmations|omniauth_callbacks)_controller\.rb\z}) },
          lambda { |path| path.start_with?("app/models/") && File.basename(path).match?(/session|token|password/i) }
        ]
      },
      "migration" => {
        "label" => "Migration",
        "detection" => "detected",
        "default_risk" => "high",
        "matchers" => [lambda { |path| path.start_with?("db/migrate/") }]
      },
      "database" => {
        "label" => "Database",
        "detection" => "detected",
        "default_risk" => "medium",
        "matchers" => [
          lambda { |path| path == "db/schema.rb" || path == "db/structure.sql" },
          lambda { |path| path.start_with?("app/models/") }
        ]
      },
      "dependencies" => {
        "label" => "Dependencies",
        "detection" => "detected",
        "default_risk" => "medium",
        "matchers" => [
          lambda { |path| %w[Gemfile Gemfile.lock].include?(path) },
          lambda { |path| path.end_with?(".gemspec") }
        ]
      },
      "public_api" => {
        "label" => "Public API",
        "detection" => "inferred",
        "default_risk" => "medium",
        "matchers" => [
          lambda { |path| path.start_with?("app/controllers/api/") },
          lambda { |path| path.match?(%r{\Aapp/controllers/v\d+/.+\.rb\z}) },
          lambda { |path| path.start_with?("app/views/api/") }
        ]
      },
      "routes" => {
        "label" => "Routes",
        "detection" => "detected",
        "default_risk" => "medium",
        "matchers" => [
          lambda { |path| path == "config/routes.rb" || path.start_with?("config/routes/") }
        ]
      },
      "background_jobs" => {
        "label" => "Background jobs",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [
          lambda { |path| path.start_with?("app/jobs/") || path.start_with?("app/workers/") },
          lambda { |path| path.match?(%r{\Aconfig/(sidekiq.*|initializers/sidekiq.*)\z}) }
        ]
      },
      "controllers" => {
        "label" => "Controllers",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [lambda { |path| path.start_with?("app/controllers/") }]
      },
      "models" => {
        "label" => "Models",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [lambda { |path| path.start_with?("app/models/") }]
      },
      "views" => {
        "label" => "Views",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [lambda { |path| path.start_with?("app/views/") }]
      },
      "mailers" => {
        "label" => "Mailers",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [lambda { |path| path.start_with?("app/mailers/") }]
      },
      "storage" => {
        "label" => "Storage",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [
          lambda { |path| path.start_with?("storage/") },
          lambda { |path| path.match?(%r{\Aconfig/storage.*\.yml\z}) }
        ]
      },
      "initializers" => {
        "label" => "Initializers",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [lambda { |path| path.start_with?("config/initializers/") }]
      },
      "configuration" => {
        "label" => "Configuration",
        "detection" => "detected",
        "default_risk" => "medium",
        "matchers" => [lambda { |path| path == "config" || path.start_with?("config/") }]
      },
      "test_infrastructure" => {
        "label" => "Test infrastructure",
        "detection" => "detected",
        "default_risk" => nil,
        "matchers" => [
          lambda { |path| %w[spec/spec_helper.rb spec/rails_helper.rb test/test_helper.rb].include?(path) },
          lambda { |path| path.start_with?("spec/support/") || path.start_with?("test/support/") }
        ]
      },
      "shared_infrastructure" => {
        "label" => "Shared infrastructure",
        "detection" => "detected",
        "default_risk" => "medium",
        "matchers" => [
          lambda { |path| %w[app/models/application_record.rb app/controllers/application_controller.rb app/jobs/application_job.rb app/mailers/application_mailer.rb app/helpers/application_helper.rb].include?(path) },
          lambda { |path| %w[config/application.rb config/environment.rb config/boot.rb].include?(path) },
          lambda { |path| path.start_with?("config/environments/") }
        ]
      }
    }.freeze

    RISK_LEVELS = %w[low medium high critical].freeze

    module_function

    # Returns { id => { available, changed, evidence, additional_evidence_count,
    # detection, sensitive, reason? } }.
    def detect(changed_paths, available:)
      paths = Array(changed_paths).compact.uniq.sort
      SURFACES.to_h do |id, spec|
        if !available
          [id, { "available" => false, "changed" => false, "evidence" => [],
                  "additional_evidence_count" => 0, "detection" => spec["detection"],
                  "sensitive" => false, "reason" => "git_scope_unavailable" }]
        else
          evidence = paths.select { |path| spec["matchers"].any? { |m| safe_match(m, path) } }
          head = evidence.first(MAX_EVIDENCE)
          [id, { "available" => true, "changed" => !evidence.empty?,
                  "evidence" => head,
                  "additional_evidence_count" => [evidence.length - head.length, 0].max,
                  "detection" => spec["detection"],
                  "sensitive" => !spec["default_risk"].nil? && !evidence.empty? }]
        end
      end
    end

    # Project-defined sensitive areas from configuration review.sensitive_paths:
    # { name => [glob, ...] }. Returns array of
    # { name, changed, evidence, additional_evidence_count }.
    def project_sensitive(changed_paths, sensitive_config, available:)
      config = sensitive_config.is_a?(Hash) ? sensitive_config : {}
      paths = Array(changed_paths).compact.uniq.sort
      config.filter_map do |name, patterns|
        name = name.to_s
        next if name.empty? || !patterns.is_a?(Array)

        if !available
          { "name" => name, "available" => false, "changed" => false,
            "evidence" => [], "additional_evidence_count" => 0,
            "reason" => "git_scope_unavailable" }
        else
          evidence = paths.select do |path|
            patterns.any? { |pattern| glob_match(pattern.to_s, path) }
          end
          head = evidence.first(MAX_EVIDENCE)
          { "name" => name, "available" => true, "changed" => !evidence.empty?,
            "evidence" => head,
            "additional_evidence_count" => [evidence.length - head.length, 0].max }
        end
      end
    end

    def glob_match(pattern, path)
      return false if pattern.empty?

      File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
    rescue StandardError
      false
    end

    def safe_match(matcher, path)
      matcher.call(path) == true
    rescue StandardError
      false
    end
    private_class_method :safe_match
  end
end
