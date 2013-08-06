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

  alias Cauldron.Connection
  alias Cauldron.Listener
  alias Cauldron.Utils

  alias Cauldron.HTTP.Headers, as: H
  alias Cauldron.HTTP.Request, as: Req
  alias Cauldron.HTTP.Response, as: Res

  alias Data.Dict
  alias Data.Seq

  defrecordp :state, request: nil, no_more_input: false

  @doc false
  def handler(connection, module) when is_atom module do
    if {:unix, :darwin} = :os.type do
      connection.socket.options(recv: [buffer: 10240])
    end
    handler(connection, function(module, :handle, 3))
  end

  def handler(connection, fun) do
    Process.flag(:trap_exit, true)

    writer = Process.spawn_link __MODULE__, :writer, [Kernel.self, connection]
    reader = Process.spawn_link __MODULE__, :reader, [Kernel.self, connection]

    handler(connection, writer, reader, fun, HashDict.new)
  end

  defp handler(Connection[socket: socket, listener: Listener[debug: debug]] = connection, writer, reader, fun, requests) do
    receive do
      Req[method: method, uri: uri, id: id] = request ->
        pid = Process.spawn_link fn ->
          fun.(method, uri, request)
        end

        handler(connection, writer, reader, fun, requests
          |> Dict.put(pid, request)
          |> Dict.put(id, state(request: request)))

      { Req[id: id], _, :read, :discard } ->
        discard_body(id)

        handler(connection, writer, reader, fun, requests)

      { Req[id: id], pid, :read, :chunk } ->
        state = Dict.get(requests, id)

        if state(state, :no_more_input) do
          pid <- { :read, nil }
        else
          # we can block here given if there's still input a new request hasn't
          # come in yet, and there's no reason to be writing while a chunk is
          # being read
          receive do
            { ^id, :input, nil } ->
              state = state(state, no_more_input: true)
              pid <- { :read, nil }

            { ^id, :input, chunk } ->
              pid <- { :read, chunk }
          end
        end

        handler(connection, writer, reader, fun, Dict.put(requests, id, state))

      { Req[id: id], pid, :read, :all } ->
        state = Dict.get(requests, id)

        if state(state, :no_more_input) do
          pid <- { :read, nil }
        else
          pid <- { :read, read_rest(id) }

          state = state(state, no_more_input: true)
        end

        handler(connection, writer, reader, fun, Dict.put(requests, id, state))

      { Res[request: Req[id: id, version: version]], :status, code, text }  ->
        writer <- { id, :status, version, code, text }

        handler(connection, writer, reader, fun, requests)

      { Res[request: Req[id: id]], :headers, headers } ->
        writer <- { id, :headers, headers }

        handler(connection, writer, reader, fun, requests)

      { Res[request: Req[id: id]], :body, body } ->
        discard_if(Dict.get(requests, id), id)
        writer <- { id, :body, body }

        handler(connection, writer, reader, fun, requests)

      { Res[request: Req[id: id]], :chunk, nil } ->
        discard_if(Dict.get(requests, id), id)
        writer <- { id, :chunk, nil }

        handler(connection, writer, reader, fun, requests)

      { Res[request: Req[id: id]], :chunk, chunk } ->
        writer <- { id, :chunk, chunk }

        handler(connection, writer, reader, fun, requests)

      { Res[request: Req[id: id]], :stream, path } ->
        socket.process!(writer)
        writer <- { id, :stream, path }

        handler(connection, writer, reader, fun, requests)

      { id, :done } ->
        state = Dict.get(requests, id)

        if state(state, :request).last? do
          socket.shutdown

          Process.exit(writer, :kill)
          Process.exit(reader, :kill)
        else
          handler(connection, writer, reader, fun, Dict.delete(requests, id))
        end

      # reader or writer died
      { :EXIT, pid, _reason } when pid in [writer, reader] ->
        case Process.info(Kernel.self, :links) do
          { :links, links } ->
            Enum.each links, Process.exit(&1, :aborted)

          _ ->
            nil
        end

      # a callback process ended
      { :EXIT, pid, :normal } ->
        handler(connection, writer, reader, fun, Dict.delete(requests, pid))

      # a callback process errored
      { :EXIT, pid, reason } ->
        Req[id: id] = request = Dict.get(requests, pid)

        if Data.contains?(requests, id) do
          if debug do
            request.reply(500, inspect(reason))
          else
            request.reply(500)
          end
        end

        handler(connection, writer, reader, fun, Dict.delete(requests, pid))
    end
  end

  defp discard_if(state, id) do
    unless state(state, :no_more_input) do
      discard_body(id)
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
    case read_rest([], id) do
      [] ->
        nil

      result ->
        iolist_to_binary(result)
    end
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

  defp reader(handler, Connection[socket: socket, listener: Listener[port: port, chunk_size: chunk_size]] = connection, id) do
    socket.packet!(:http_bin)

    case request(connection) do
      { method, path, version } ->
        if headers = headers(connection) do
          uri = case path do
            { :abs_path, path } ->
              { path, query, fragment } = split(path)

              if authority = Dict.get(headers, "Host") do
                destructure [host, port], String.split(authority, ":", global: false)

                port = binary_to_integer(port || "80")
              else
                authority = "localhost:#{port}"
                host      = "localhost"
              end

              URI.Info[ scheme:    if(connection.secure?, do: "https", else: "http"),
                        authority: authority,
                        host:      host,
                        port:      port,
                        path:      path,
                        query:     query,
                        fragment:  fragment ]

            { :absoluteURI, scheme, host, port, path } ->
              { path, query, fragment } = split(path)

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

            { :scheme, host, port } ->
              URI.Info[ host: host,
                        port: binary_to_integer(port) ]

            path when is_binary(path) ->
              path
          end

          request = Req[ connection: connection,
                         handler:    handler,
                         id:         id,
                         method:     method,
                         uri:        uri,
                         version:    version,
                         headers:    headers ]

          handler <- request

          socket.packet!(:raw)

          cond do
            length = H.get(headers, "Content-Length") ->
              read_body(handler, id, socket, chunk_size, length)

            H.get(headers, "Transfer-Encoding") == "chunked" ->
              read_body(handler, id, socket, chunk_size)

            true ->
              no_body(handler, id)
          end

          reader(handler, connection, id + 1)
        end

      _ ->
        nil
    end
  end

  defp request(Connection[socket: socket]) do
    case socket.recv do
      { :ok, { :http_request, method, uri, version } } ->
        if is_atom(method) do
          method = atom_to_binary(method)
        else
          method = Utils.upcase(method)
        end

        { method, uri, version }

      { :ok, { :http_error, _ } } ->
        nil

      { :ok, nil } ->
        nil

      { :error, :einval } ->
        nil
    end
  end

  defp split(path) do
    destructure [path, fragment], String.split(path, "#", global: false)
    destructure [path, query], String.split(path, "?", global: false)

    { path, query, fragment }
  end

  defp headers(connection) do
    case headers([], connection) do
      nil ->
        nil

      list ->
        H.from_list(list)
    end
  end

  defp headers(acc, Connection[socket: socket] = connection) do
    case socket.recv do
      { :ok, { :http_header, _, name, _, value } } ->
        [{ name, value } | acc] |> headers(connection)

      { :ok, :http_eoh } ->
        acc

      { :ok, nil } ->
        nil

      { :error, :einval } ->
        nil
    end
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

  defp writer(handler, Connection[socket: socket] = connection, id, headers) do
    receive do
      { ^id, :status, { major, minor }, code, text } ->
        socket.send! ["HTTP/", "#{major}.#{minor}", " ", integer_to_binary(code), " ", text, "\r\n"]

        writer(handler, connection, id, headers)

      { ^id, :headers, headers } ->
        writer(handler, connection, id, headers)

      { ^id, :body, body } ->
        if headers do
          if Req[headers: headers].last? do
            headers = H.put(headers, "Connection", "close")
          end

          headers = H.put(headers, "Content-Length", iolist_size(body))

          write_headers(socket, headers)
        end

        socket.send!(iolist_to_binary(body))

        handler <- { id, :done }

        writer(handler, connection, id + 1, nil)

      { ^id, :chunk, nil } ->
        if headers do
          if Req[headers: headers].last? do
            headers = H.put(headers, "Connection", "close")
          end

          headers = H.put(headers, "Transfer-Encoding", "chunked")

          write_headers(socket, headers)
        end

        socket.send!("0\r\n\r\n")

        handler <- { id, :done }

        writer(handler, connection, id + 1, nil)

      { ^id, :chunk, chunk } ->
        if headers do
          if Req[headers: headers].last? do
            headers = H.put(headers, "Connection", "close")
          end

          headers = H.put(headers, "Transfer-Encoding", "chunked")

          write_headers(socket, headers)
        end

        write_chunk(socket, chunk)

        writer(handler, connection, id, nil)

      { ^id, :stream, path } ->
        if headers do
          if Req[headers: headers].last? do
            headers = H.put(headers, "Connection", "close")
          end

          headers = H.put(headers, "Content-Length", File.stat!(path).size)

          write_headers(socket, headers)
        end

        { :ok, _ } = :file.sendfile(path, socket.to_port)
        socket.process!(handler)

        handler <- { id, :done }

        writer(handler, connection, id, nil)
    end
  end

  defp write_headers(socket, headers) do
    Seq.each headers, fn { name, value } ->
      socket.send! [name, ": ", to_binary(value), "\r\n"]
    end

    socket.send! "\r\n"
  end

  defp write_chunk(socket, chunk) do
    socket.send!([:io_lib.format("~.16b", [iolist_size(chunk)]), "\r\n",
                  chunk, "\r\n"])
  end
end
