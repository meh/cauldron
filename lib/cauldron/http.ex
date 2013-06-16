defmodule Cauldron.HTTP do
  @moduledoc """

                 +------------+
                 | Connection |
                 +------------+
                       |
  +--------+      +---------+      +--------+
  | Writer |<---->| Handler |<---->| Reader |
  +--------+      +---------+      +--------+
                     ^   ^
                     |   |
    +----------+     |   |     +----------+
    | Callback |<----+   +---->| Callback |
    +----------+               +----------+

  """

  alias Cauldron.HTTP.Headers, as: H
  alias Cauldron.HTTP.Request, as: Req
  alias Cauldron.HTTP.Response, as: Res

  alias Data.Dict, as: D
  alias Data.Seq, as: S

  defrecordp :state, no_more_input: false

  @doc false
  def handler(connection, fun) do
    Process.flag(:trap_exit, true)

    writer = Process.spawn_link __MODULE__, :writer, [Kernel.self, connection]
    reader = Process.spawn_link __MODULE__, :reader, [Kernel.self, connection]

    handler(writer, reader, fun, HashDict.new)
  end

  defp handler(writer, reader, fun, requests) do
    receive do
      Req[method: method, uri: uri, id: id] = request ->
        requests = D.put(requests, id, state())

        Process.spawn_link fn ->
          fun.(method, uri, request)
        end

        handler(writer, reader, fun, requests)

      { Req[id: id], _, :read, :discard } ->
        discard_body(id)

        handler(writer, reader, fun, requests)

      { Req[id: id], pid, :read, :chunk } ->
        request = D.get(requests, id)

        if state(request, :no_more_input) do
          pid <- { :read, nil }
        else
          # we can block here given if there's still input a new request hasn't
          # come in yet, and there's no reason to be writing while the body is
          # being read (unless you're doing chunking, then you'd be reading by chunk
          # and there's no issue anyway)
          receive do
            { ^id, :input, nil } ->
              request = state(request, no_more_input: true)
              pid <- { :read, nil }

            { ^id, :input, chunk } ->
              pid <- { :read, chunk }
          end
        end

        handler(writer, reader, fun, D.put(requests, id, request))

      { Req[id: id], pid, :read, :all } ->
        request = D.get(requests, id)

        if state(request, :no_more_input) do
          pid <- { :read, nil }
        else
          pid <- { :read, read_rest(id) }

          request = state(request, no_more_input: true)
        end

        handler(writer, reader, fun, D.put(requests, id, request))

      { Res[request: Req[id: id, version: version]], :status, code, text }  ->
        writer <- { id, :status, version, code, text }

        handler(writer, reader, fun, requests)

      { Res[request: Req[id: id]], :headers, headers } ->
        writer <- { id, :headers, headers }

        handler(writer, reader, fun, requests)

      { Res[request: Req[id: id]], :body, body } ->
        writer <- { id, :body, body }

        handler(writer, reader, fun, D.delete(requests, id))

      { Res[request: Req[id: id]], :chunk, nil } ->
        writer <- {id, :chunk, nil }

        handler(writer, reader, fun, D.delete(requests, id))

      { Res[request: Req[id: id]], :chunk, chunk } ->
        writer <- {id, :chunk, chunk }

        handler(writer, reader, fun, requests)

      { :EXIT, pid, _reason } when pid in [writer, reader] ->
        case Process.info(Kernel.self, :links) do
          { :links, links } ->
            Enum.each links, Process.exit(&1, :aborted)

          _ ->
            nil
        end

      # a callback process ended, that means nothing
      { :EXIT, _pid, _reason } ->
        handler(writer, reader, fun, requests)
    end
  end

  defp discard_body(id) do
    receive do
      { ^id, :input, nil } ->
        nil

      { ^id, :input, _ } ->
        discard_body(id)
    end
  end

  defp read_rest(id) do
    read_rest([], id) |> :lists.reverse |> iolist_to_binary
  end

  defp read_rest(acc, id) do
    receive do
      { ^id, :input, nil } ->
        acc

      { ^id, :input, chunk } ->
        read_rest([acc | chunk], id)
    end
  end

  @doc false
  def reader(handler, connection) do
    reader(handler, connection, 0)
  end

  defp reader(handler, connection, id) do
    case request(connection) do
      { method, path, version } ->
        headers = headers(connection)
        host    = headers["Host"] || "localhost"
        port    = connection.listener.port
        uri     = URI.parse("#{if connection.secure?, do: "https", else: "http"}://#{host}:#{port}#{path}")

        request = Req[ connection: connection,
                       handler:    handler,
                       id:         id,
                       method:     method,
                       uri:        uri,
                       version:    version,
                       headers:    headers ]

        connection.socket.options(packet: :raw)

        handler <- request

        if length = headers["Content-Length"] do
          read_body(handler, id, request.connection.socket, request.connection.listener.chunk_size, binary_to_integer(length))
        else
          if headers["Transfer-Encoding"] == "chunked" do
            read_body(handler, id, request.connection.socket, request.connection.listener.chunk_size)
          else
            no_body(handler, id)
          end
        end

        reader(handler, connection, id + 1)

      nil ->
        nil
    end
  end

  defp request(connection) do
    connection.socket.options(packet: :line)

    case connection.socket.recv! do
      nil ->
        nil

      line ->
        [method, path, "HTTP/" <> version] = String.split(line)

        { method, path, version }
    end
  end

  defp headers(connection) do
    connection.socket.options(packet: :line)

    headers([], connection.socket) |> H.from_list
  end

  defp headers([], socket) do
    [header(String.rstrip(socket.recv!))] |> headers(socket)
  end

  defp headers([{ name, value } = last | rest], socket) do
    case String.rstrip(socket.recv!) do
      "" ->
        [last | rest]

      " " <> more ->
        [{ name, [value, String.lstrip(more)] } | rest] |> headers(socket)

      line ->
        [header(line), last | rest] |> headers(socket)
    end
  end

  defp header(line) do
    [name, value] = String.split(line, ":", global: false)

    { String.rstrip(name), String.lstrip(value) }
  end

  defp read_body(handler, id, _, _, 0) do
    no_body(handler, id)
  end

  defp read_body(handler, id, socket, chunk_size, length) when length <= chunk_size do
    handler <- { id, :input, socket.recv!(length) }

    read_body(handler, id, socket, chunk_size, 0)
  end

  defp read_body(handler, id, socket, chunk_size, length) do
    handler <- { :input, socket.recv!(chunk_size) }

    read_body(handler, id, chunk_size, length - chunk_size)
  end

  defp read_body(_handler, _id, _socket, _chunk_size) do
    throw :unimplemented
  end

  defp no_body(handler, id) do
    handler <- { id, :input, nil }
  end

  @doc false
  def writer(handler, connection) do
    writer(handler, connection, 0, nil)
  end

  defp writer(handler, connection, id, headers) do
    receive do
      { ^id, :status, version, code, text } ->
        connection.socket.send ["HTTP/", version, " ", integer_to_binary(code), " ", text, "\r\n"]

        writer(handler, connection, id, headers)

      { ^id, :headers, headers } ->
        writer(handler, connection, id, headers)

      { ^id, :body, body } ->
        write_headers(connection.socket, D.put(headers, "Content-Length", iolist_size(body)))
        connection.socket.send(iolist_to_binary(body))

        writer(handler, connection, id + 1, nil)

      { ^id, :chunk, nil } ->
        if headers do
          write_headers(connection.socket, D.put(headers, "Transfer-Encoding", "chunked"))
        end

        connection.socket.send("0\r\n")

        writer(handler, connection, id + 1, nil)

      { ^id, :chunk, chunk } ->
        if headers do
          write_headers(connection.socket, D.put(headers, "Transfer-Encoding", "chunked"))
        end

        connection.socket.send([:io_lib.format("~.16b", [iolist_size(chunk) |> integer_to_binary]), "\r\n"])
        connection.socket.send(chunk)

        writer(handler, connection, id, nil)
    end
  end

  defp write_headers(socket, headers) do
    S.each headers, fn { name, value } ->
      socket.send! [name, ": ", to_binary(value), "\r\n"]
    end

    socket.send! "\r\n"
  end
end
