#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron.HTTP.Response do
  defstruct [:request]

  alias HTTProt.Headers
  alias HTTProt.Status

  defimpl Cauldron.Response do
    def status(self, code) when code |> is_integer do
      status(self, { code, Status.to_string(code) })
    end

    def status(self, { code, text }) when code |> is_integer and text |> is_binary do
      :gen_server.cast self.request.handler, { self, :status, code, text }

      self
    end

    def headers(self, headers) when headers |> is_list do
      headers(self, Headers.parse(headers))
    end

    def headers(self, headers) do
      :gen_server.cast self.request.handler, { self, :headers, headers }

      self
    end

    def stream(self, path) when path |> is_binary do
      unless File.exists?(path) do
        raise File.Error, reason: :enoent, action: "open", path: path
      end

      :gen_server.cast self.request.handler, { self, :stream, path }

      self
    end

    def stream(self, io) when io |> is_pid or io |> is_port do
      stream(self, self.request.handler, io, 4096)

      self
    end

    def stream(self, acc, fun) when fun |> is_function do
      stream(self, self.request.handler, fun, acc)

      self
    end

    defp stream(self, handler, fun, acc) when fun |> is_function do
      case fun.(acc) do
        :eof ->
          :gen_server.cast handler, { self, :chunk, nil }

        { data, acc } ->
          :gen_server.cast handler, { self, :chunk, data }

          stream(self, handler, fun, acc)
      end
    end

    defp stream(self, handler, io, chunk_size) do
      case IO.binread(io, chunk_size) do
        :eof ->
          :gen_server.cast handler, { self, :chunk, nil }

        data ->
          :gen_server.cast handler, { self, :chunk, data }

          stream(self, handler, io, chunk_size)
      end
    end

    def body(self, body) do
      :gen_server.cast self.request.handler, { self, :body, body }

      self
    end

    def send(self, chunk) do
      :gen_server.cast self.request.handler, { self, :chunk, chunk }

      self
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(response, _opts) do
      concat ["#Cauldron.Response<", to_string(response.request.method), " ", to_string(response.request.uri), ">"]
    end
  end
end
