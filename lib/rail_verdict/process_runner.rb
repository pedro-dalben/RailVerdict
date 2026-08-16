# frozen_string_literal: true

module RailVerdict
  class ProcessRunner
    class DirectoryError < RailVerdict::Error; end

    DEFAULT_TIMEOUT_SECONDS = 30.0
    DEFAULT_MAX_STDOUT_BYTES = 4 * 1024 * 1024
    DEFAULT_MAX_STDERR_BYTES = 64 * 1024
    READ_CHUNK_BYTES = 64 * 1024
    TERM_GRACE_SECONDS = 0.1
    REAP_POLL_SECONDS = 0.01

    ENV_ALLOWLIST = %w[
      PATH HOME GEM_HOME GEM_PATH RUBYLIB RUBYOPT LANG
    ].freeze
    FORCED_ENV = { "LC_ALL" => "C.UTF-8", "TZ" => "UTC" }.freeze

    RunResult = Struct.new(
      :status, :exit_code, :signal, :stdout, :stderr,
      :stdout_truncated, :stderr_truncated, :detail,
      keyword_init: true
    )

    class << self
      def run(executable, argv, chdir:, timeout_seconds: DEFAULT_TIMEOUT_SECONDS,
              max_stdout_bytes: DEFAULT_MAX_STDOUT_BYTES, max_stderr_bytes: DEFAULT_MAX_STDERR_BYTES)
        directory = verify_directory(chdir)
        argv = argv.map { |element| validate_argv_element(element) }
        env = build_env

        stdout_read, stdout_write = IO.pipe
        stderr_read, stderr_write = IO.pipe
        pid = nil

        begin
          pid = Process.spawn(
            env,
            [executable, File.basename(executable)],
            *argv,
            chdir: directory,
            pgroup: true,
            in: :close,
            out: stdout_write,
            err: stderr_write
          )
        rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, ArgumentError => error
          return spawn_failure_result(error)
        end

        registry.register(pid)
        stdout_write.close
        stderr_write.close

        execute_child(pid, stdout_read, stderr_read, timeout_seconds, max_stdout_bytes, max_stderr_bytes)
      ensure
        registry.unregister(pid) if pid
        [stdout_read, stdout_write, stderr_read, stderr_write].compact.each do |io|
          io.close unless io.closed?
        end
      end

      def registry
        @registry ||= Registry.new
      end

      def build_env
        env = ENV.keys.to_h { |key| [key, nil] }
        ENV_ALLOWLIST.each do |key|
          value = ENV[key]
          env[key] = value unless value.nil?
        end
        env.merge(FORCED_ENV)
      end

      private

      def spawn_failure_result(error)
        RunResult.new(
          status: :spawn_failed,
          exit_code: nil,
          signal: nil,
          stdout: String.new(encoding: Encoding::UTF_8),
          stderr: String.new(encoding: Encoding::UTF_8),
          stdout_truncated: false,
          stderr_truncated: false,
          detail: "#{error.class}: #{error.message}"
        )
      end

      def verify_directory(chdir)
        directory = File.realpath(chdir)
        raise DirectoryError, "working directory is not a usable directory: #{chdir}" unless File.directory?(directory)

        directory
      rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR
        raise DirectoryError, "working directory is not usable: #{chdir}"
      end

      def validate_argv_element(element)
        raise ArgumentError, "argv elements must be strings" unless element.is_a?(String)
        raise ArgumentError, "argv elements cannot contain NUL bytes" if element.include?("\u0000")

        element
      end

      def execute_child(pid, stdout_read, stderr_read, timeout_seconds, max_stdout_bytes, max_stderr_bytes)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
        output = { buffer: String.new(encoding: Encoding::BINARY), cap: max_stdout_bytes, truncated: false }
        errors = { buffer: String.new(encoding: Encoding::BINARY), cap: max_stderr_bytes, truncated: false }
        streams = { stdout_read => output, stderr_read => errors }

        timed_out = drain_streams(streams, deadline) == :timed_out
        status, timed_out = await_child(pid, deadline, timed_out)
        build_result(status, timed_out, output, errors, timeout_seconds)
      end

      def drain_streams(streams, deadline)
        open_streams = streams.keys

        until open_streams.empty?
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return :timed_out if remaining <= 0

          ready = IO.select(open_streams, nil, nil, remaining)
          next unless ready

          ready.first.each do |io|
            next unless read_stream(io, streams.fetch(io))

            io.close
            open_streams.delete(io)
          end
        end

        nil
      end

      def read_stream(io, stream_state)
        loop do
          chunk = io.read_nonblock(READ_CHUNK_BYTES, exception: false)
          return true if chunk.nil?
          return false if chunk == :wait_readable

          stream_state[:buffer] << chunk
          if stream_state[:buffer].bytesize > stream_state.fetch(:cap)
            stream_state[:truncated] = true
            return true
          end
        end
      end

      def await_child(pid, deadline, already_timed_out)
        loop do
          if already_timed_out || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            terminate_process_group(pid)
            _, status = Process.waitpid2(pid)
            return [status, true]
          end

          reaped_pid, status = Process.waitpid2(pid, Process::WNOHANG)
          return [status, false] if reaped_pid

          sleep REAP_POLL_SECONDS
        end
      end

      def build_result(status, timed_out, output, errors, timeout_seconds)
        if timed_out
          return RunResult.new(
            status: :timed_out,
            exit_code: nil,
            signal: nil,
            stdout: encode_output(output[:buffer]),
            stderr: encode_output(errors[:buffer]),
            stdout_truncated: output[:truncated],
            stderr_truncated: errors[:truncated],
            detail: "process exceeded the #{timeout_seconds}s monotonic timeout and was terminated"
          )
        end

        if status.exited?
          RunResult.new(
            status: :exited,
            exit_code: status.exitstatus,
            signal: nil,
            stdout: encode_output(output[:buffer]),
            stderr: encode_output(errors[:buffer]),
            stdout_truncated: output[:truncated],
            stderr_truncated: errors[:truncated],
            detail: nil
          )
        else
          signal_name = signal_name_for(status)
          RunResult.new(
            status: :signaled,
            exit_code: nil,
            signal: signal_name,
            stdout: encode_output(output[:buffer]),
            stderr: encode_output(errors[:buffer]),
            stdout_truncated: output[:truncated],
            stderr_truncated: errors[:truncated],
            detail: "process terminated by signal #{signal_name}"
          )
        end
      end

      def signal_name_for(status)
        return nil unless status.signaled?

        Signal.signame(status.termsig)
      rescue RuntimeError
        "SIG#{status.termsig}"
      end

      def encode_output(bytes)
        bytes.dup.force_encoding(Encoding::UTF_8).scrub("\uFFFD").freeze
      end

      def terminate_process_group(pid)
        signal_group(pid, "TERM")
        grace_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TERM_GRACE_SECONDS
        while process_group_alive?(pid) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < grace_deadline
          sleep REAP_POLL_SECONDS
        end
        signal_group(pid, "KILL") if process_group_alive?(pid)
      end

      def signal_group(pid, signal)
        Process.kill(signal, -pid)
      rescue Errno::ESRCH, Errno::EINVAL
        begin
          Process.kill(signal, pid)
        rescue Errno::ESRCH
          nil
        end
      end

      def process_group_alive?(pid)
        Process.kill(0, -pid)
        true
      rescue Errno::ESRCH
        false
      end
    end

    class Registry
      def initialize
        @pids = {}
      end

      def register(pid)
        @pids[pid] = true
      end

      def unregister(pid)
        @pids.delete(pid)
      end

      def size
        @pids.size
      end

      def terminate_all
        pids = @pids.keys
        return if pids.empty?

        pids.each { |pid| signal_group(pid, "TERM") }
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + ProcessRunner::TERM_GRACE_SECONDS
        sleep 0.01 while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        pids.each do |pid|
          signal_group(pid, "KILL")
          begin
            Process.waitpid(pid)
          rescue Errno::ECHILD
            nil
          end
        end
        @pids.clear
      end

      private

      def signal_group(pid, signal)
        Process.kill(signal, -pid)
      rescue Errno::ESRCH, Errno::EINVAL, Errno::EPERM
        begin
          Process.kill(signal, pid)
        rescue Errno::ESRCH, Errno::EPERM
          nil
        end
      end
    end
  end
end
