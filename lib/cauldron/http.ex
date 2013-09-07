#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

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

  use GenServer.Behaviour

  alias Cauldron.Connection
  alias Cauldron.Listener
  alias Cauldron.Utils

  alias Cauldron.HTTP.Headers, as: H
  alias Cauldron.HTTP.Request, as: Req
  alias Cauldron.HTTP.Response, as: Res

  alias Data.Dict
  alias Data.Seq

  defrecord Handler, connection: nil, callback: nil, reader: nil, writer: nil, streaming: false, state: nil
  defrecord State, id: 0, reading: nil, writing: nil, requests: []
  defrecord Current, recipient: nil, headers: []
  defrecord Instance, request: nil, no_more_input: false

  def start(connection, callback) do
    callback = if callback |> is_atom do
      &callback.handle/3
    end

    :gen_server.start __MODULE__, [connection, callback], []
  end

  def init([ Connection[socket: socket] = connection, callback ]) do
    Process.flag :trap_exit, true

    socket |> Socket.packet! :http_bin
    socket |> Socket.active!

    { :ok, Handler[connection: connection, callback: callback, state: State[]] }
  end

  def terminate(_reason, Handler[connection: Connection[socket: socket]]) do
    socket |> Socket.close
  end

  def handle_info({ :http, _socket, { :http_request, method, path, version } }, Handler[state: State[id: id] = state] = handler) do
    state = state.reading Current[recipient: { method |> to_string |> Utils.upcase, path, version }]
    state = state.id id + 1

    { :noreply, handler.state(state) }
  end

  def handle_info({ :http, _socket, { :http_header, _, name, _, value } }, Handler[state: State[reading: Current[recipient: request, headers: headers]] = state] = handler) do
    state = state.reading Current[recipient: request, headers: [{ name, value } | headers]]

    { :noreply, handler.state(state) }
  end

  def handle_info({ :http, socket, :http_eoh }, Handler[connection: connection, callback: callback, reader: reader, state: State[id: id, reading: Current[recipient: { method, path, version }, headers: headers], requests: requests] = state] = handler) do
    uri     = create_uri(path, connection, headers)
    request = Req[
      connection: connection,
      handler:    Process.self,
      id:         id,
      method:     method,
      uri:        uri,
      version:    version,
      headers:    headers |> Enum.reverse |> H.from_list]

    if request.has_body? do
      unless reader do
        reader  = Process.spawn_link __MODULE__, :reader, [Process.self, connection]
        handler = handler.reader reader
      end

      socket |> Socket.passive!
      reader <- request
    end

    pid = Process.spawn_link fn ->
      callback.(method, uri, request)
    end

    state = state.requests requests
      |> Dict.put(pid, request)
      |> Dict.put(id, Instance[request: request])

    { :noreply, handler.state(state) }
  end

  def handle_info({ :tcp_closed, _ }, _handler) do
    { :stop, :normal, _handler }
  end

  # the reader died
  def handle_info({ :EXIT, pid, _reason }, Handler[reader: pid] = _handler) do
    { :noreply, _handler }
  end

  # the writer died
  def handle_info({ :EXIT, pid, _reason }, Handler[writer: pid] = _handler) do
    { :noreply, _handler }
  end

  # a callback process ended
  def handle_info({ :EXIT, _pid, :normal }, _handler) do
    { :noreply, _handler }
  end

  # a callback process errored
  def handle_info({ :EXIT, pid, reason }, Handler[connection: Connection[listener: Listener[debug: debug]], state: State[requests: requests]] = _handler) do
    case requests |> Dict.get(pid) do
      Req[id: id] = request ->
        if requests |> Dict.has_key?(id) do
          if debug do
            request.reply(500, reason |> inspect)
          else
            request.reply(500)
          end
        end

      _ ->
        nil
    end

    { :noreply, _handler }
  end

  def handle_call({ Req[id: id], :read, :discard }, _from, Handler[reader: reader] = _handler) do
    reader <- { id, :discard }

    { :reply, :ok, _handler }
  end

  def handle_call({ Req[id: id], :read, :chunk }, _from, Handler[reader: reader, state: State[requests: requests] = state] = handler) do
    request = requests |> Dict.get(id)

    if request.no_more_input do
      { :reply, nil, handler }
    else
      reader <- { id, :read, :chunk }

      receive do
        { ^reader, :chunk, nil } ->
          state = state.requests requests |> Dict.put(id, request.no_more_input(true))

          { :reply, nil, handler.state(state) }

        { ^reader, :chunk, chunk } ->
          { :reply, chunk, handler }
      end
    end
  end

  def handle_call({ Req[id: id], :read, :all }, _from, Handler[reader: reader, state: State[requests: requests] = state] = handler) do
    request = requests |> Dict.get(id)

    if request.no_more_input do
      { :reply, nil, handler }
    else
      reader <- { id, :read, :all }

      receive do
        { ^reader, :all, body } ->
          state = state.requests requests |> Dict.put(id, request.no_more_input(true))

          { :reply, body, handler.state(state) }
      end
    end
  end

  def handle_cast({ :reader, :done }, Handler[streaming: streaming, connection: Connection[socket: socket]] = _handler) do
    unless streaming do
      socket |> Socket.packet! :http_bin
      socket |> Socket.active!
    end

    { :noreply, _handler }
  end

  def handle_cast({ :writer, :done, Res[request: req] }, Handler[connection: Connection[socket: socket]] = handler) do
    socket |> Socket.packet! :http_bin
    socket |> Socket.active!

    if req.last? do
      { :stop, :normal, handler }
    else
      { :noreply, handler.streaming(false) }
    end
  end

  def handle_cast({ Res[request: Req[id: id, version: version] = req] = res, :status, code, text }, Handler[writer: writer, connection: Connection[socket: socket] = connection, state: State[] = state] = handler) do
    cond do
      writer ->
        writer <- { res, :status, code, text }

      id == 1 and req.last? ->
        state   = state.writing Current[recipient: res]
        handler = handler.state state

        write_status(socket, version, code, text)

      true ->
        writer  = Process.spawn_link __MODULE__, :writer, [Process.self, connection]
        handler = handler.writer writer

        writer <- { res, :status, code, text }
    end

    { :noreply, handler }
  end

  def handle_cast({ Res[] = res, :headers, headers }, Handler[writer: writer, state: State[writing: Current[recipient: recipient]] = state] = handler) do
    cond do
      writer ->
        writer <- { res, :headers, headers }

      true ->
        state   = state.writing Current[recipient: recipient, headers: headers]
        handler = handler.state state
    end

    { :noreply, handler }
  end

  def handle_cast({ Res[] = res, :body, body }, Handler[writer: writer, connection: Connection[socket: socket], state: State[writing: Current[headers: headers]] = state] = handler) do
    cond do
      writer ->
        writer <- { res, :body, body }

      true ->
        headers = headers |> H.put("Connection", "close")
        headers = headers |> H.put("Content-Length", iolist_size(body))

        write_headers(socket, headers)
        write_body(socket, body)

        state   = state.writing nil
        handler = handler.state state
    end

    { :noreply, handler }
  end

  def handle_cast({ Res[] = res, :chunk, chunk }, Handler[writer: writer, connection: Connection[socket: socket], state: State[writing: current] = state] = handler) do
    cond do
      writer ->
        writer <- { res, :chunk, chunk }

      true ->
        case current do
          Current[headers: headers] ->
            headers = headers |> H.put("Connection", "close")
            headers = headers |> H.put("Transfer-Encoding", "chunked")

            write_headers(socket, headers)

            state   = state.writing nil
            handler = handler.state state

          nil ->
            nil
        end

        write_chunk(socket, chunk)
    end

    { :noreply, handler }
  end

  def handle_cast({ Res[] = res, :stream, path }, _handler) do
    { :noreply, _handler }
  end

  defp create_uri({ :abs_path, path }, Connection[listener: Listener[port: port]] = connection, headers) do
    destructure [path, fragment], String.split(path, "#", global: false)
    destructure [path, query], String.split(path, "?", global: false)

    if authority = Dict.get(headers, "Host") do
      destructure [host, port], String.split(authority, ":", global: false)

      port = binary_to_integer(port || "80")
    else
      authority = "localhost:#{port}"
      host      = "localhost"
    end

    if auth = Dict.get(headers, "Authorization") do
      case auth do
        "Basic " <> rest ->
          userinfo = :base64.decode(rest)

        _ ->
          userinfo = nil
      end
    end

    URI.Info[ scheme:    if(connection.secure?, do: "https", else: "http"),
              authority: authority,
              host:      host,
              port:      port,
              userinfo:  userinfo,
              path:      path,
              query:     query,
              fragment:  fragment ]
  end

  defp create_uri({ :absoluteURI, scheme, host, port, path }, _connection, _headers) do
    destructure [path, fragment], String.split(path, "#", global: false)
    destructure [path, query], String.split(path, "?", global: false)

    port = case port do
      :undefined ->
        if scheme == :http do
          80
        else
          443
        end

      port ->
        port
    end

    URI.Info[ scheme:    atom_to_binary(scheme),
              authority: "#{host}:#{port}",
              host:      host,
              port:      port,
              path:      path,
              query:     query,
              fragment:  fragment ]
  end

  defp create_uri({ :scheme, host, port }, _connection, _headers) do
    URI.Info[ host: host,
              port: binary_to_integer(port) ]
  end

  defp create_uri(path, _connection, _headers) when path |> is_binary do
    path
  end

  @doc false
  def reader(handler, Connection[listener: Listener[chunk_size: chunk_size], socket: socket] = _connection) do
    receive do
      Req[id: id, headers: headers] ->
        cond do
          length = H.get(headers, "Content-Length") ->
            socket |> Socket.packet! :raw

            read_body(id, socket, chunk_size, length)

          H.get(headers, "Transfer-Encoding") == "chunked" ->
            socket |> Socket.packet! :line

            read_body(id, socket, chunk_size)
        end

        :gen_server.cast handler, { :reader, :done }

      { id, :discard } ->
        discard_body(id)

      { id, :read, :chunk } ->
        handler <- { Process.self, :chunk, read_chunk(id) }

      { id, :read, :all } ->
        handler <- { Process.self, :all, read_all(id) }
    end

    reader(handler, _connection)
  end

  defp read_body(id, _, _, 0) do
    Process.self <- { id, nil }
  end

  defp read_body(id, socket, chunk_size, length) when length <= chunk_size do
    Process.self <- { id, socket |> Socket.Stream.recv!(length) }

    read_body(id, socket, chunk_size, 0)
  end

  defp read_body(id, socket, chunk_size, length) do
    Process.self <- { :input, socket |> Socket.Stream.recv!(chunk_size) }

    read_body(id, chunk_size, length - chunk_size)
  end

  defp read_body(id, socket, chunk_size) do
    throw :unimplemented
  end

  defp discard_body(id) do
    receive do
      { ^id, :input, chunk } when chunk != nil ->
        discard_body(id)

      { ^id, :input, nil } ->
        nil
    end
  end

  defp read_chunk(id) do
    receive do
      { ^id, chunk } ->
        chunk
    end
  end

  defp read_all(id) do
    read_all([], id) |> Enum.reverse |> iolist_to_binary
  end

  defp read_all(acc, id) do
    case read_chunk(id) do
      nil ->
        acc

      chunk ->
        [chunk | acc] |> read_all(id)
    end
  end

  defp write_status(socket, { major, minor }, code, text) do
    socket |> Socket.Stream.send! [
      "HTTP/", "#{major}.#{minor}", " ",
      integer_to_binary(code), " ",
      text, "\r\n"
    ]
  end

  defp write_headers(socket, headers) do
    Seq.each headers, fn { name, value } ->
      socket |> Socket.Stream.send! [name, ": ", to_string(value), "\r\n"]
    end

    socket |> Socket.Stream.send! "\r\n"
  end

  defp write_body(socket, body) do
    socket |> Socket.Stream.send! body
  end

  defp write_chunk(socket, nil) do
    socket |> Socket.Stream.send! "0\r\n\r\n"
  end

  defp write_chunk(socket, chunk) do
    socket |> Socket.Stream.send! [
      :io_lib.format("~.16b", [iolist_size(chunk)]), "\r\n",
      chunk, "\r\n"
    ]
  end
end
