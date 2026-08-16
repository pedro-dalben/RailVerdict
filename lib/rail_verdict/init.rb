# frozen_string_literal: true

require "pathname"

module RailVerdict
  module Init
    CONFIGURATION = <<~YAML
      version: 1
      mode: no_new_debt
      analyzers:
        rubocop:
          enabled: true
          required: true
    YAML

    module_function

    def write(root:, config_path:, force: false)
      path = Pathname.new(config_path.to_s)
      path = Pathname.new(File.expand_path(path.to_s, root)) unless path.absolute?
      if path.exist? && !force
        return [2, "configuration already exists: #{relative_path(path.to_s, root)}; use --force to overwrite"]
      end
      parent = path.dirname
      return [2, "configuration directory does not exist: #{relative_path(parent.to_s, root)}"] unless parent.directory?

      File.write(path, CONFIGURATION)
      [0, "initialized #{relative_path(path.to_s, root)}"]
    rescue SystemCallError => error
      [2, "could not write configuration: #{error.message}"]
    end

    def relative_path(path, root)
      Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
    end
    private_class_method :relative_path
  end
end
