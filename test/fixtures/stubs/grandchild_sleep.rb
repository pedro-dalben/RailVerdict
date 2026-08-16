require "rbconfig"

Process.spawn(RbConfig.ruby, File.expand_path("sleep_forever.rb", __dir__))
sleep 60
