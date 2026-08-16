code = ARGV[0].to_i
index = 1

while index < ARGV.length
  case ARGV[index]
  when "--stdout"
    STDOUT.write(ARGV[index + 1])
    index += 2
  when "--stderr"
    STDERR.write(ARGV[index + 1])
    index += 2
  else
    index += 1
  end
end

exit code
