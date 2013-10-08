#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron.HTTP do
  @doc false
  def start(version, connection, callback) do
    if callback |> is_atom do
      callback = &callback.handle/3
    end

    { :ok, Process.spawn(__MODULE__, :init, [version, connection, callback]) }
  end

  alias Cauldron.Utils

  alias Data.Dict
  alias Data.Seq

  alias Cauldron.HTTP.Headers
  alias Cauldron.HTTP.Request
  alias Cauldron.HTTP.Response

  def init(version, connection, callback) do
    Process.flag :trap_exit, true
    Reagent.wait

    :fprof.trace(:start)

    run(version, connection, callback)
  end

  def run(version, connection, callback) do
    { method, path, version } = request(connection)
    headers                   = headers(connection)
    uri                       = create_uri(path, connection, headers)

    request = Request[
      connection: connection,
      handler:    Process.self,
      id:         0,
      method:     method,
      uri:        uri,
      version:    version,
      headers:    headers ]

    Process.spawn_link fn ->
      callback.(method, uri, request)
    end

    handler(request)

    unless request.last? do
      run(version, connection, callback)
    end
  end

  defp request(connection) do
    connection |> Socket.packet! :http_bin

    case connection |> Socket.Stream.recv! do
      { :http_request, method, path, version } ->
        { method |> to_string |> Utils.upcase, path, version }

      nil ->
        exit :closed
    end
  end

  defp headers(connection) do
    headers([], connection) |> Enum.reverse |> Headers.from_list
  end

  defp headers(acc, connection) do
    case connection |> Socket.Stream.recv! do
      :http_eoh ->
        acc

      { :http_header, _, name, _, value } ->
        [{ name, value } | acc] |> headers(connection)

      nil ->
        exit :closed
    end
  end

  defp create_uri({ :abs_path, path }, connection, headers) do
    destructure [path, fragment], String.split(path, "#", global: false)
    destructure [path, query], String.split(path, "?", global: false)

    if authority = Dict.get(headers, "Host") do
      destructure [host, port], String.split(authority, ":", global: false)

      port = binary_to_integer(port || "80")
    else
      authority = "localhost:#{connection.port}"
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

  defp handler(request) do
    handler(request, nil, nil)
  end

  defp handler(Request[connection: connection] = request, headers, body) do
    receive do
      { :EXIT, _pid, :normal } ->
        handler(request, headers, body)

      { :EXIT, _pid, reason } ->
        :error_logger.error_report(reason)
        request.reply(500)

        handler(request, headers, body)

      { :"$gen_call", { pid, ref }, { Request[headers: headers], :read, :all } } ->
        unless body do
          body = read_body(connection, headers)
        end

        pid <- { ref, body }

        handler(request, headers, body)

      { :"$gen_cast", { Response[request: Request[version: version]], :status, code, text } } ->
        write_status(connection, version, code, text)

        handler(request, nil, body)

      { :"$gen_cast", { Response[], :headers, headers } } ->
        handler(request, headers, body)

      { :"$gen_cast", { Response[], :body, body } } ->
        headers = keep_alive(request, headers)
        headers = headers |> Dict.put("Content-Length", iolist_size(body))

        write_headers(connection, headers)
        write_body(connection, body)

      { :"$gen_cast", { Response[], :stream, path } } ->
        headers = keep_alive(request, headers)
        headers = headers |> Dict.put("Content-Length", File.stat!(path).size)

        write_headers(connection, headers)
        write_file(connection, path)

      { :"$gen_cast", { Response[], :chunk, chunk } } ->
        if headers do
          headers = keep_alive(request, headers)
          headers = headers |> Dict.put("Transfer-Encoding", "chunked")

          write_headers(connection, headers)
        end

        write_chunk(connection, chunk)

        unless chunk == nil do
          handler(request, nil, body)
        end

      v ->
        IO.inspect v

        handler(request, headers, body)
    end
  end

  defp keep_alive(request, headers) do
    if request.last? do
      headers |> Dict.put("Connection", "close")
    else
      headers |> Dict.put("Connection", "keep-alive")
    end
  end

  defp read_body(connection, headers) do
    cond do
      length = headers |> Dict.get("Content-Length") ->
        connection |> Socket.packet! :raw
        connection |> Socket.Stream.recv!(length)

      headers |> Dict.get("Transfer-Encoding") == "chunked" ->
        read_chunks(connection)

      true ->
        nil
    end
  end

  defp read_chunks(connection) do
    read_chunks([], connection) |> Seq.reverse |> iolist_to_binary
  end

  defp read_chunks(acc, connection) do
    case read_chunk(connection) do
      nil ->
        acc

      chunk ->
        [chunk | acc] |> read_chunks(connection)
    end
  end

  defp read_chunk(connection) do
    connection |> Socket.packet! :line

    case connection |> Socket.Stream.recv! |> String.rstrip |> binary_to_integer(16) do
      0 ->
        connection |> Socket.Stream.recv!
        nil

      size ->
        connection |> Socket.packet! :raw
        res = connection |> Socket.Stream.recv!(size)
        connection |> Socket.packet! :line
        connection |> Socket.Stream.recv!
        res
    end
  end

  defp write_status(connection, { major, minor }, code, text) do
    connection |> Socket.Stream.send! [
      "HTTP/", "#{major}.#{minor}", " ",
      integer_to_binary(code), " ",
      text, "\r\n"
    ]
  end

  defp write_headers(connection, headers) do
    Seq.each headers, fn { name, value } ->
      connection |> Socket.Stream.send! [name, ": ", to_string(value), "\r\n"]
    end

    connection |> Socket.Stream.send! "\r\n"
  end

  defp write_body(connection, body) do
    connection |> Socket.Stream.send! body
  end

  defp write_file(connection, path) do
    connection |> Socket.Stream.file!(path)
  end

  defp write_chunk(connection, nil) do
    connection |> Socket.Stream.send! "0\r\n\r\n"
  end

  defp write_chunk(connection, chunk) do
    connection |> Socket.Stream.send! [
      :io_lib.format("~.16b", [iolist_size(chunk)]), "\r\n",
      chunk, "\r\n"
    ]
  end
end
