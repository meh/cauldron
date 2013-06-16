defrecord Cauldron.HTTP.Request, connection: nil,
                                 handler: nil,
                                 id: nil,
                                 method: nil,
                                 uri: nil,
                                 version: nil,
                                 headers: nil do
  alias Cauldron.HTTP.Response, as: Response

  def recv(self) do
    self.handler <- { self, Kernel.self, :read, :chunk }

    receive do
      { :read, chunk } ->
        chunk
    end
  end

  def body(self) do
    self.handler <- { self, Kernel.self, :read, :all }

    receive do
      { :read, body } ->
        body
    end
  end

  def response(self) do
    Response[request: self]
  end

  def response(code, self) do
    response(self).status(code).headers([]).body("")
  end

  def response(code, io, self) when is_pid(io) do
    response(self).status(code).headers([]).stream(io)
  end

  def response(code, body, self) do
    response(self).status(code).headers([]).body(body)
  end

  def response(code, acc, fun, self) when is_function(fun) do
    response(self).status(code).headers([]).stream(acc, fun)
  end

  def response(code, headers, body, self) do
    response(self).status(code).headers(headers).body(body)
  end

  def response(code, headers, acc, fun, self) when is_function(fun) do
    response(self).status(code).headers(headers).stream(acc, fun)
  end
end

defimpl Binary.Inspect, for: Cauldron.HTTP.Request do
  def inspect(request, _opts) do
    "#Cauldron.Request<#{request.method} #{request.uri} #{inspect request.headers}>"
  end
end
