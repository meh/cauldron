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
  alias Cauldron.HTTP.Request, as: R
  alias Data.Dictionary, as: D

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
      { R[method: method, uri: uri, id: id] = request } ->
        requests = D.put(requests, id, state())

        Process.spawn_link fn ->
          fun.(method, uri, request)
        end

        handler(writer, reader, fun, requests)

      { R[id: id], _, :read, :discard } ->
        discard_body(id)

        handler(writer, reader, fun, requests)

      { R[id: id], pid, :read, :chunk } ->
        request = D.get(requests, id)

        if state(request, :no_more_input) do
          pid <- { :read, :end }
        else
          # we can block here given if there's still input a new request hasn't
          # come in yet, and there's no reason to be writing while the body is
          # being read (unless you're doing chunking, then you'd be reading by chunk
          # and there's no issue anyway)
          receive do
            { R[id: ^id], :input, :end } ->
              request = state(request, no_more_input: true)
              pid <- { :read, :end }

            { R[id: ^id], :input, chunk } ->
              pid <- { :read, chunk }
          end
        end

        handler(writer, reader, fun, D.put(requests, id, request))

      { R[id: id], pid, :read, :all } ->
        request = D.get(requests, id)

        if state(request, :no_more_input) do
          pid <- { :read, :end }
        else
          pid <- { :read, read_rest(id) }

          request = state(request, no_more_input: true)
        end

        handler(writer, reader, fun, D.put(requests, id, request))

      { :response, response } ->
        IO.inspect response

        handler(writer, reader, fun, requests)

      { :EXIT, pid, reason } when pid in [writer, reader] ->
        case Process.info(Kernel.self, :links) do
          { :links, links } ->
            Enum.each links, Process.exit(&1, :aborted)

          _ ->
            nil
        end

      { :EXIT, _pid, _reason } ->
        handler(writer, reader, fun, requests)
    end
  end

  defp discard_body(id) do
    receive do
      { R[id: ^id], :input, :end } ->
        nil

      { R[id: ^id], :input, _ } ->
        discard_body(id)
    end
  end

  defp read_rest(id) do
    read_rest("", id)
  end

  defp read_rest(acc, id) do
    receive do
      { R[id: ^id], :input, :end } ->
        acc

      { R[id: ^id], :input, chunk } ->
        read_rest(acc <> chunk, id)
    end
  end

  @doc false
  def reader(handler, connection) do
    reader(handler, connection, 0)
  end

  defp reader(handler, connection, id) do
    request = request(connection)
    headers = headers(connection)

    request = case request do
      { method, path, version } ->
        host = headers["Host"] || "localhost"
        port = connection.listener.port
        uri  = URI.parse("#{if connection.secure?, do: "https", else: "http"}://#{host}:#{port}#{path}")

        R[ connection: connection,
           handler:    handler,
           id:         id,
           method:     method,
           uri:        uri,
           version:    version,
           headers:    headers ]
    end

    connection.socket.options(packet: :raw)

    handler <- { request }

    if length = headers["Content-Length"] do
      read_body(request, request.connection.socket, request.connection.listener.chunk_size, binary_to_integer(length))
    else
      if headers["Transfer-Encoding"] == "chunked" do
        read_body(request, request.connection.socket, request.connection.listener.chunk_size)
      else
        no_body(request)
      end
    end

    reader(handler, connection, id + 1)
  end

  defp request(connection) do
    connection.socket.options(packet: :line)

    [method, path, "HTTP/" <> version] = String.split(connection.socket.recv!)

    { method, path, version }
  end

  defp headers(connection) do
    connection.socket.options(packet: :line)

    headers([], connection.socket) |> H.from_list
  end

  defp headers([], socket) do
    [header(socket.recv!)] |> headers(socket)
  end

  defp headers([{ name, value } = last | rest], socket) do
    case String.rstrip(socket.recv!) do
      "" ->
        [last | rest]

      " " <> more ->
        [{ name, "#{value} #{String.lstrip(more)}" } | rest] |> headers(socket)

      line ->
        [header(line), last | rest] |> headers(socket)
    end
  end

  defp header(line) do
    [name, value] = String.split(line, ":", global: false)

    { String.rstrip(name), String.strip(value) }
  end

  defp read_body(request, _, _, 0) do
    no_body(request)
  end

  defp read_body(request, socket, chunk_size, length) when length <= chunk_size do
    request.handler <- { request, :input, socket.recv!(length) }

    read_body(request, socket, chunk_size, 0)
  end

  defp read_body(request, socket, chunk_size, length) do
    request.handler <- { request, :input, socket.recv!(chunk_size) }

    read_body(request, chunk_size, length - chunk_size)
  end

  defp read_body(request, socket, chunk_size) do

  end

  defp no_body(request) do
    request.handler <- { request, :input, :end }
  end

  @doc false
  def writer(handler, connection) do
    writer(handler, connection, HashDict.new)
  end

  defp writer(handler, connection, state) do
    receive do
      _ -> nil
    end

    writer(handler, connection, state)
  end
end
