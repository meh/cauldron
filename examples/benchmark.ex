defmodule Benchmark do
  def handle("GET", uri, request) do
    request.reply(200, "Hello, World!")
  end
end
