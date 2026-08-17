# frozen_string_literal: true

require "mcp"

module RailVerdict
  module MCP
    class Server
      PROTOCOL_VERSION = "2025-11-25"
      SERVER_NAME = "railverdict"
      SERVER_TITLE = "RailVerdict"
      INSTRUCTIONS = "RailVerdict is a read-only verifier. It never edits source, creates commits, or mutates baselines/waivers. Use verify -> list_findings -> get_finding -> build_repair_packet -> external edit -> verify_repair -> PASS/FAIL/INCOMPLETE. Gate FAIL is a successful result, not a protocol error. AI tools are advisory and off by default."

      attr_reader :repository_root

      def initialize(repository_root: nil)
        @repository_root = RepositoryRoot.resolve(repository_root)
        @mutex = Mutex.new
        @cache = Cache.new
        @mcp_server = build_mcp_server
      end

      def serve
        diagnostics_to_stderr
        trap_signals
        transport = ::MCP::Server::Transports::StdioTransport.new(@mcp_server)
        transport.open
      ensure
        ProcessRunner.registry.terminate_all rescue nil
      end

      def mcp_server
        @mcp_server
      end

      def cache
        @cache
      end

      private

      def build_mcp_server
        config = ::MCP::Configuration.new(protocol_version: PROTOCOL_VERSION)
        server = ::MCP::Server.new(
          name: SERVER_NAME,
          title: SERVER_TITLE,
          version: RailVerdict::VERSION,
          instructions: INSTRUCTIONS,
          configuration: config,
          capabilities: { tools: { listChanged: false } }
        )
        register_tools(server)
        server
      end

      def register_tools(mcp_server)
        require_relative "tools/verify"
        require_relative "tools/list_findings"
        require_relative "tools/get_finding"
        require_relative "tools/build_repair_packet"
        require_relative "tools/verify_repair"
        require_relative "tools/explain"
        require_relative "tools/investigate"

        [
          Tools::Verify,
          Tools::ListFindings,
          Tools::GetFinding,
          Tools::BuildRepairPacket,
          Tools::VerifyRepair,
          Tools::Explain,
          Tools::Investigate
        ].each do |tool_class|
          instance = tool_class.new(server: self)
          mcp_server.define_tool(
            name: instance.tool_name,
            title: instance.tool_title,
            description: instance.tool_description,
            input_schema: instance.tool_input_schema,
            output_schema: instance.tool_output_schema,
            annotations: instance.tool_annotations
          ) do |**args|
            instance.call(**args)
          end
        end
      end

      def diagnostics_to_stderr
      end

      def trap_signals
        %w[INT TERM].each do |sig|
          Signal.trap(sig) do
            ProcessRunner.registry.terminate_all rescue nil
            exit(sig == "INT" ? 130 : 0)
          end
        end
      rescue ArgumentError
        nil
      end
    end
  end
end
