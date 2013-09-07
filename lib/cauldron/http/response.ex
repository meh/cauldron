#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defrecord Cauldron.HTTP.Response, request: nil do
  alias __MODULE__, as: Res
  alias Cauldron.HTTP.Request, as: Req
  alias Cauldron.HTTP.Headers
  alias Cauldron.Connection
  alias Cauldron.Listener

  @doc """
  Send the HTTP status.
  """
  @spec status(integer | { integer, String.t }, t) :: t
  def status(code, self) when is_integer(code) do
    status({ code, text_for(code) }, self)
  end

  def status({ code, text }, Res[request: Req[handler: handler]] = self) when is_integer(code) and is_binary(text) do
    :gen_server.cast handler, { self, :status, code, text }

    self
  end

  @doc """
  Send the HTTP headers.
  """
  @spec headers(Headers.t, t) :: t
  def headers(headers, Res[request: Req[handler: handler]] = self) when is_list(headers) do
    :gen_server.cast handler, { self, :headers, Headers.from_list(headers) }

    self
  end

  def headers(headers, Res[request: Req[handler: handler]] = self) do
    :gen_server.cast handler, { self, :headers, headers }

    self
  end

  @doc """
  Stream a file or an IO device.
  """
  @spec stream(String.t | :io.device, t) :: t
  def stream(path, Res[request: Req[handler: handler]] = self) when is_binary(path) do
    unless File.exists?(path) do
      raise File.Error, reason: :enoent, action: "open", path: path
    end

    :gen_server.cast handler, { self, :stream, path }

    self
  end

  def stream(io, Res[request: Req[connection: Connection[listener: Listener[chunk_size: chunk_size]], handler: handler]] = self) when is_pid(io) or is_port(io) do
    stream(self, handler, io, chunk_size)

    self
  end

  @doc """
  Stream a response body with a generator function.
  """
  @spec stream(term, (term -> { iolist, term })) :: t
  def stream(acc, fun, Res[request: Req[handler: handler]] = self) when is_function(fun) do
    stream(self, handler, fun, acc)

    self
  end

  defp stream(self, handler, fun, acc) when is_function(fun) do
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

  @doc """
  Send the passed binary as body.
  """
  @spec body(iolist, t) :: t
  def body(body, Res[request: Req[handler: handler]] = self) do
    :gen_server.cast handler, { self, :body, body }

    self
  end

  @doc """
  Send a chunk.
  """
  def send(chunk, Res[request: Req[handler: handler]] = self) do
    :gen_server.cast handler, { self, :chunk, chunk }

    self
  end

  defp text_for(100), do: "Continue"
  defp text_for(101), do: "Switching Protocols"
  defp text_for(102), do: "Processing"
  defp text_for(200), do: "OK"
  defp text_for(201), do: "Created"
  defp text_for(202), do: "Accepted"
  defp text_for(203), do: "Non-Authoritative Information"
  defp text_for(204), do: "No Content"
  defp text_for(205), do: "Reset Content"
  defp text_for(206), do: "Partial Content"
  defp text_for(207), do: "Multi-Status"
  defp text_for(226), do: "IM Used"
  defp text_for(300), do: "Multiple Choices"
  defp text_for(301), do: "Moved Permanently"
  defp text_for(302), do: "Found"
  defp text_for(303), do: "See Other"
  defp text_for(304), do: "Not Modified"
  defp text_for(305), do: "Use Proxy"
  defp text_for(306), do: "Switch Proxy"
  defp text_for(307), do: "Temporary Redirect"
  defp text_for(400), do: "Bad Request"
  defp text_for(401), do: "Unauthorized"
  defp text_for(402), do: "Payment Required"
  defp text_for(403), do: "Forbidden"
  defp text_for(404), do: "Not Found"
  defp text_for(405), do: "Method Not Allowed"
  defp text_for(406), do: "Not Acceptable"
  defp text_for(407), do: "Proxy Authentication Required"
  defp text_for(408), do: "Request Timeout"
  defp text_for(409), do: "Conflict"
  defp text_for(410), do: "Gone"
  defp text_for(411), do: "Length Required"
  defp text_for(412), do: "Precondition Failed"
  defp text_for(413), do: "Request Entity Too Large"
  defp text_for(414), do: "Request-URI Too Long"
  defp text_for(415), do: "Unsupported Media Type"
  defp text_for(416), do: "Requested Range Not Satisfiable"
  defp text_for(417), do: "Expectation Failed"
  defp text_for(418), do: "I'm a teapot"
  defp text_for(422), do: "Unprocessable Entity"
  defp text_for(423), do: "Locked"
  defp text_for(424), do: "Failed Dependency"
  defp text_for(425), do: "Unordered Collection"
  defp text_for(426), do: "Upgrade Required"
  defp text_for(428), do: "Precondition Required"
  defp text_for(429), do: "Too Many Requests"
  defp text_for(431), do: "Request Header Fields Too Large"
  defp text_for(500), do: "Internal Server Error"
  defp text_for(501), do: "Not Implemented"
  defp text_for(502), do: "Bad Gateway"
  defp text_for(503), do: "Service Unavailable"
  defp text_for(504), do: "Gateway Timeout"
  defp text_for(505), do: "HTTP Version Not Supported"
  defp text_for(506), do: "Variant Also Negotiates"
  defp text_for(507), do: "Insufficient Storage"
  defp text_for(510), do: "Not Extended"
  defp text_for(511), do: "Network Authentication Required"
end

defimpl Inspect, for: Cauldron.HTTP.Response do
  import Inspect.Algebra

  def inspect(response, _opts) do
    concat ["#Cauldron.Response<", to_string(response.request.method), " ", to_string(response.request.uri), ">"]
  end
end
