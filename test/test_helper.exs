"test/support/**/*.ex"
|> Path.wildcard()
|> Enum.each(&Code.require_file/1)

ExUnit.start()
