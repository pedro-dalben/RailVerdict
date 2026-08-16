# frozen_string_literal: true

require "psych"

module RailVerdict
  module StrictYaml
    class Error < RailVerdict::Error
      attr_reader :property_path

      def initialize(message, property_path: nil)
        super(message)
        @property_path = property_path
      end
    end

    PLAIN = Psych::Nodes::Scalar::PLAIN
    INTEGER = /\A[-+]?[0-9]+\z/
    FLOAT = /\A[-+]?[0-9]*\.[0-9]+(?:[eE][-+]?[0-9]+)?\z/
    FLOAT_EXPONENT = /\A[-+]?[0-9]+[eE][-+]?[0-9]+\z/

    def self.parse(text, source_path)
      document =
        begin
          Psych.parse(text)
        rescue Psych::SyntaxError => error
          raise Error.new(
            "#{source_path}: YAML syntax error: #{error.message.lines.first.to_s.strip}",
            property_path: "$"
          )
        end

      materialize(document&.root, "$")
    end

    def self.materialize(node, path)
      case node
      when nil
        nil
      when Psych::Nodes::Mapping
        materialize_mapping(node, path)
      when Psych::Nodes::Sequence
        materialize_sequence(node, path)
      when Psych::Nodes::Scalar
        materialize_scalar(node, path)
      when Psych::Nodes::Alias
        raise Error.new("#{path}: aliases are not permitted", property_path: path)
      else
        raise Error.new("#{path}: unsupported YAML node", property_path: path)
      end
    end

    def self.materialize_mapping(node, path)
      reject_tag(node, path)
      reject_anchor(node, path)
      children = node.children || []
      result = {}
      seen = {}
      children.each_slice(2) do |key_node, value_node|
        raise Error.new("#{path}: mapping entries require a key and a value", property_path: path) if value_node.nil?

        key = mapping_key(key_node, path)
        if seen.key?(key)
          raise Error.new("#{path}.#{key}: duplicate key #{key.inspect}", property_path: "#{path}.#{key}")
        end

        seen[key] = true
        result[key] = materialize(value_node, "#{path}.#{key}")
      end
      result
    end

    def self.materialize_sequence(node, path)
      reject_tag(node, path)
      reject_anchor(node, path)
      (node.children || []).each_with_index.map do |child, index|
        materialize(child, "#{path}[#{index}]")
      end
    end

    def self.materialize_scalar(node, path)
      reject_tag(node, path)
      reject_anchor(node, path)
      return node.value.dup.force_encoding(Encoding::UTF_8) unless node.style == PLAIN

      resolve_plain_scalar(node.value)
    end

    def self.mapping_key(node, path)
      case node
      when Psych::Nodes::Scalar
        node.value.to_s
      when Psych::Nodes::Alias
        raise Error.new("#{path}: aliases are not permitted in mapping keys", property_path: path)
      else
        raise Error.new("#{path}: mapping keys must be scalars", property_path: path)
      end
    end

    def self.resolve_plain_scalar(value)
      case value
      when "", "~", "null", "Null", "NULL"
        nil
      when "true", "True", "TRUE"
        true
      when "false", "False", "FALSE"
        false
      when INTEGER
        Integer(value)
      when FLOAT, FLOAT_EXPONENT
        Float(value)
      else
        value.dup
      end
    end

    def self.reject_tag(node, path)
      tag = node.tag
      return if tag.nil? || tag.empty?

      raise Error.new("#{path}: explicit YAML tags are not permitted", property_path: path)
    end

    def self.reject_anchor(node, path)
      anchor = node.respond_to?(:anchor) ? node.anchor : nil
      return if anchor.nil? || anchor.empty?

      raise Error.new("#{path}: anchors are not permitted", property_path: path)
    end

    private_class_method :materialize, :materialize_mapping, :materialize_sequence,
                         :materialize_scalar, :mapping_key, :resolve_plain_scalar,
                         :reject_tag, :reject_anchor
  end
end
