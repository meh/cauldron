#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron do
  @moduledoc %B"""

        +---------+-------------+-------------+----------+
        |         |             |             |          |
        |    +----------+  +----------+  +----------+    |
        |    | Acceptor |  | Acceptor |  | Acceptor |    |
        |    +----------+  +----------+  +----------+    |
        |         ^             ^             ^          |
        |         |             |             |          |
        |         +-------------+-------------+          |
        |                       |                        |
        |                  +---------+                   |
        |            +---->| Monitor |<----+             |
        |            |     +---------+     |             |
  +------------+     |                     |       +------------+
  | Connection |     |                     |       | Connection |
  +------------+     |                     |       +------------+
        |            |                     |             |
        |       +---------+           +---------+        |
        +------>| Handler |           | Handler |<-------+
                +---------+           +---------+

  """

  defrecord Listener, monitor: nil, socket: nil, port: nil, acceptors: 1, backlog: 128, chunk_size: 4096, secure: nil do
    def secure?(Listener[secure: nil]), do: false
    def secure?(Listener[]),            do: true

    def cert(Listener[secure: nil]), do: nil
    def cert(Listener[secure: sec]), do: sec[:cert]

    def to_options(Listener[backlog: backlog, secure: nil]) do
      [backlog: backlog, automatic: false]
    end

    def to_options(Listener[backlog: backlog, secure: secure]) do
      Keyword.merge(secure, [backlog: backlog, automatic: false,
        advertisted_protocols: ["spdy/2", "spdy/3", "http/1.0", "http/1.1"]])
    end
  end

  defrecord Connection, listener: nil, socket: nil, protocol: nil do
    def secure?(Connection[socket: socket]) when is_record(socket, Socket.TCP) do
      false
    end

    def secure?(Connection[socket: socket]) when is_record(socket, Socket.SSL) do
      true
    end
  end

  def open(options // [], fun) do
    if is_atom(fun) do
      fun = function(fun, :handle, 3)
    end

    Process.spawn __MODULE__, :monitor, [fun, options]
  end

  @doc false
  def monitor(fun, options) do
    Process.flag(:trap_exit, true)

    listen = Keyword.get(options, :listen, [[port: 80]])

    Enum.each listen, fn desc ->
      listener = Listener.new(desc)
      listener = listener.monitor(Kernel.self)
      listener = listener.socket(if listener.secure? do
        Socket.SSL.listen!(listener.port, listener.to_options)
      else
        Socket.TCP.listen!(listener.port, listener.to_options)
      end)

      Enum.each 1 .. (listener.acceptors), fn _ ->
        Process.spawn_link __MODULE__, :acceptor, [listener, fun]
      end
    end

    monitor
  end

  defp monitor do
    receive do
      { Connection[] = _connection, :connected } ->
        nil

      { Connection[] = _connection, :disconnected } ->
        nil

      { :EXIT, _pid, _reason } ->
        nil
    end

    monitor
  end

  @doc false
  def acceptor(listener, fun) do
    connection = Connection.new(listener: listener, socket: listener.socket.accept!(automatic: false))
    connection = connection.protocol(if connection.secure? do
      connection.socket.negotiated_protocol
    end || "http/?")

    listener.monitor <- { connection, :connected }

    connection.socket.process!(case connection.protocol do
      "http/" <> _ ->
        Process.spawn Cauldron.HTTP, :handler, [connection, fun]

      "spdy/" <> _ ->
        Process.spawn Cauldron.SPDY, :handler, [connection, fun]
    end)

    acceptor(listener, fun)
  end
end
