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

  def reply(self) do
    Response[request: self]
  end

  def reply(path, self) when is_binary(path) do
    reply(self).status(200).headers([]).stream(path)
  end

  def reply(code, self) do
    reply(self).status(code).headers([]).body("")
  end

  def reply(code, io, self) when is_pid(io) do
    reply(self).status(code).headers([]).stream(io)
  end

  def reply(code, body, self) do
    reply(self).status(code).headers([]).body(body)
  end

  def reply(code, acc, fun, self) when is_function(fun) do
    reply(self).status(code).headers([]).stream(acc, fun)
  end

  def reply(code, headers, body, self) do
    reply(self).status(code).headers(headers).body(body)
  end

  def reply(code, headers, acc, fun, self) when is_function(fun) do
    reply(self).status(code).headers(headers).stream(acc, fun)
  end
end

defimpl Binary.Inspect, for: Cauldron.HTTP.Request do
  def inspect(request, _opts) do
    "#Cauldron.Request<#{request.method} #{request.uri} #{inspect request.headers}>"
  end
end
