#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defrecord Cauldron.HTTP.Request, connection: nil,
                                 handler: nil,
                                 id: nil,
                                 method: nil,
                                 uri: nil,
                                 version: nil,
                                 headers: nil do
  alias __MODULE__, as: Req
  alias Cauldron.HTTP.Response, as: Res

  def last?(Req[headers: headers]) do
    headers["Connection"] == nil or headers["Connection"] == "close"
  end

  def recv(Req[handler: handler] = self) do
    handler <- { self, Kernel.self, :read, :chunk }

    receive do
      { :read, chunk } ->
        chunk
    end
  end

  def body(Req[handler: handler] = self) do
    handler <- { self, Kernel.self, :read, :all }

    receive do
      { :read, body } ->
        body
    end
  end

  def reply(self) do
    Res.new(request: self)
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
