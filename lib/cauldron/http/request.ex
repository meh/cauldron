defrecord Cauldron.HTTP.Request, connection: nil,
                                 handler: nil,
                                 id: nil,
                                 method: nil,
                                 uri: nil,
                                 version: nil,
                                 headers: nil do
  def body(self, options // [])

  def body(self, [chunk: true]) do
    self.handler <- { self, Kernel.self, :read, :chunk }

    receive do
      { :read, :end } ->
        nil

      { :read, chunk } ->
        chunk
    end
  end

  def body(self, [discard: true]) do
    self.handler <- { self, Kernel.self, :read, :discard }
  end

  def body(self, []) do
    self.handler <- { self, Kernel.self, :read, :all }

    receive do
      { :read, :end } ->
        nil

      { :read, body } ->
        body
    end
  end
end

defimpl Binary.Inspect, for: Cauldron.HTTP.Request do
  def inspect(request, _opts) do
    "#Cauldron.Request[HTTP #{request.version}]<#{request.method} #{inspect request.uri} #{inspect request.headers}>"
  end
end
