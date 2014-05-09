#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron.HTTP.Request do
  alias Cauldron.Utils, as: U

  defstruct [:connection, :handler, :id, :method, :uri, :version, :headers]

  @doc """
  Check if the request is the last in the pipeline.
  """
  @spec last?(t) :: boolean
  def last?(self) do
    if connection = self.headers["Connection"] do
      U.downcase(connection) != "keep-alive"
    else
      true
    end
  end

  defimpl Cauldron.Request do
    alias Cauldron.Response, as: R

    def has_body?(self) do
      self.headers["Content-Length"] != nil or self.headers["Transfer-Encoding"] == "chunked"
    end

    def method(self) do
      self.method
    end

    def uri(self) do
      self.uri
    end

    def headers(self) do
      self.headers
    end

    def read(self, size \\ 4096) do
      :gen_server.call self.handler, { self, :read, :chunk, size }
    end

    def body(self) do
      :gen_server.call self.handler, { self, :read, :all }
    end

    def reply(self) do
      %Cauldron.HTTP.Response{request: self}
    end

    def reply(self, path) when path |> is_binary do
      self |> reply |> R.status(200) |> R.headers([]) |> R.stream(path)
    end

    def reply(self, code) do
      self |> reply |> R.status(code) |> R.headers([]) |> R.body("")
    end

    def reply(self, code, io) when io |> is_pid or io |> is_port do
      self |> reply |> R.status(code) |> R.headers([]) |> R.stream(io)
    end

    def reply(self, code, body) do
      self |> reply |> R.status(code) |> R.headers([]) |> R.body(body)
    end

    def reply(self, code, acc, fun) when fun |> is_function do
      self |> reply |> R.status(code) |> R.headers([]) |> R.stream(acc, fun)
      reply(self).status(code).headers([]).stream(acc, fun)
    end

    def reply(self, code, headers, body) do
      self |> reply |> R.status(code) |> R.headers(headers) |> R.body(body)
    end

    def reply(self, code, headers, acc, fun) when fun |> is_function do
      self |> reply |> R.status(code) |> R.headers(headers) |> R.stream(acc, fun)
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(request, _opts) do
      concat ["#Cauldron.Request<", to_string(request.method), " ", to_string(request.uri), ">"]
    end
  end
end
