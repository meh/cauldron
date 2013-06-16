defrecord Cauldron.HTTP.Response, request: nil do
  def status(code, self) when is_integer(code) do
    status({ code, text_for(code) }, self)
  end

  def status({ code, text }, self) when is_integer(code) and is_binary(text) do
    self.request.handler <- { self, :status, code, text }

    self
  end

  def headers(headers, self) when is_list(headers) do
    self.request.handler <- { self, :headers, Cauldron.HTTP.Headers.from_list(headers) }

    self
  end

  def headers(headers, self) do
    self.request.handler <- { self, :headers, headers }

    self
  end

  def stream(acc, fun, self) when is_function(fun) do
    stream(self, self.request.handler, fun, acc)

    self
  end

  def stream(io, self) do
    stream(self, self.request.handler, io, self.request.connection.listener.chunk_size)

    self
  end

  defp stream(self, handler, fun, acc) when is_function(fun) do
    case fun.(acc) do
      :eof ->
        handler <- { self, :chunk, nil }

      { data, acc } ->
        handler <- { self, :chunk, data }

        stream(self, handler, fun, acc)
    end
  end

  defp stream(self, handler, io, chunk_size) do
    case IO.binread(io, chunk_size) do
      :eof ->
        handler <- { self, :chunk, nil }

      data ->
        handler <- { self, :chunk, data }

        stream(self, handler, io, chunk_size)
    end
  end

  def body(body, self) do
    self.request.handler <- { self, :body, body }

    self
  end

  def send(chunk, self) do
    self.request.handler <- { self, :chunk, chunk }

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
