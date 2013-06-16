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
    response(self).status(code)
  end

  def response(code, body, self) do
    response(code, self).headers(Cauldron.HTTP.Headers.new).body(body)
  end

  def response(code, headers, body, self) do
    response(code, self).status(code).headers(headers).body(body)
  end
end

defimpl Binary.Inspect, for: Cauldron.HTTP.Request do
  def inspect(request, _opts) do
    "#Cauldron.Request<#{request.method} #{request.uri} #{inspect request.headers}>"
  end
end
