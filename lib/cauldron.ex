#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron do
  @moduledoc %S"""

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

  defrecord Listener, monitor: nil, debug: false, socket: nil, port: nil, acceptors: 1, backlog: 128, chunk_size: 4096, secure: nil do
    def secure?(Listener[secure: nil]), do: false
    def secure?(Listener[]),            do: true

    def cert(Listener[secure: nil]), do: nil
    def cert(Listener[secure: sec]), do: sec[:cert]

    def to_options(Listener[backlog: backlog, secure: nil]) do
      [backlog: backlog, buffer: 16 * 1024, automatic: false]
    end

    def to_options(Listener[backlog: backlog, secure: secure]) do
      Keyword.merge(secure, [backlog: backlog, buffer: 16 * 1024, automatic: false,
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

  def open(callback, options // []) do
    Process.spawn __MODULE__, :monitor, [callback, options]
  end

  @doc false
  def monitor(callback, options) do
    Process.flag(:trap_exit, true)

    listen = Keyword.get(options, :listen, [[port: 80]])
    debug  = Keyword.get(options, :debug, false)

    Enum.each listen, fn desc ->
      listener = Listener.new(desc)
      listener = listener.monitor(Kernel.self)
      listener = listener.debug(debug)
      listener = listener.socket(if listener.secure? do
        Socket.SSL.listen!(listener.port, listener.to_options)
      else
        Socket.TCP.listen!(listener.port, listener.to_options)
      end)

      Enum.each 1 .. (listener.acceptors), fn _ ->
        Process.spawn_link __MODULE__, :acceptor, [listener, callback]
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
  def acceptor(Listener[socket: socket, monitor: monitor] = listener, callback) do
    socket     = socket |> Socket.accept!(automatic: false)
    connection = Connection.new(listener: listener, socket: socket)
    connection = connection.protocol(if connection.secure? do
      socket |> Socket.SSL.negotiated_protocol
    end || "http/?")

    { :ok, process } = case connection.protocol do
      "http/" <> _ ->
        Cauldron.HTTP.start(connection, callback)

      "spdy/" <> _ ->
        Cauldron.SPDY.start(connection, callback)
    end

    socket |> Socket.process(process)

    monitor <- { connection, :connected }

    acceptor(listener, callback)
  end
end
