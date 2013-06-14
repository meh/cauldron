defmodule Example do
  def handle(method, URI.Info[path: path], req) do
    :timer.sleep 100

    IO.puts "#{method} #{path}"
    IO.puts to_binary(req.headers)
    IO.puts req.body
  end
end
