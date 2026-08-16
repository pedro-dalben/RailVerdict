require "json"

if ARGV.include?("--version")
  puts "1.88.0"
else
  files = [
    {
      "path" => "app/models/user.rb",
      "offenses" => [
        {
          "cop_name" => "Style/StringLiterals",
          "severity" => "convention",
          "message" => "Prefer double-quoted strings unless you need single quotes",
          "location" => { "start_line" => 4, "last_line" => 4 }
        },
        {
          "cop_name" => "Lint/UselessAssignment",
          "severity" => "warning",
          "message" => "Useless assignment to variable - value",
          "location" => { "start_line" => 12, "last_line" => 12 }
        }
      ]
    },
    {
      "path" => "app/controllers/users_controller.rb",
      "offenses" => [
        {
          "cop_name" => "Style/StringLiterals",
          "severity" => "convention",
          "message" => "Prefer double-quoted strings unless you need single quotes",
          "location" => { "start_line" => 7, "last_line" => 7 }
        }
      ]
    },
    {
      "path" => "app/models/user.rb",
      "offenses" => [
        {
          "cop_name" => "Style/StringLiterals",
          "severity" => "convention",
          "message" => "Prefer double-quoted strings unless you need single quotes",
          "location" => { "start_line" => 4, "last_line" => 4 }
        }
      ]
    }
  ]
  puts JSON.generate("files" => files.reverse)
end
