stream = ARGV[0] == "stderr" ? STDERR : STDOUT
chunk = "x" * 65_536

loop do
  begin
    stream.write(chunk)
    stream.flush
  rescue Errno::EPIPE, IOError
    break
  end
end
