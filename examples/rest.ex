defmodule REST do
  def handle(method, uri, request) do
    try do
      case method do
        "GET" ->
          __MODULE__.get(uri, request)

        "POST" ->
          __MODULE__.post(uri, request)
      end
    rescue
      _ in [UndefinedFunctionError, FunctionClauseError] ->
        missing(method, uri, request)
    end
  end

  def get(URI.Info[path: "/file"], request) do
    request.response("mix.exs")
  end

  def get(URI.Info[path: "/io"], request) do
    request.response(200, File.open!("mix.exs"))
  end

  def get(URI.Info[path: "/generator"], request) do
    request.response 200, true, fn
      true  -> { "lol", false }
      false -> :eof
    end
  end

  def get(URI.Info[path: "/yawnt"], request) do
    request.response(200, "yawnt e' scemo\n")
  end

  def get(URI.Info[path: "/yawnt/" <> what], request) do
    request.response(200, "yawnt e' #{what}\n")
  end

  def post(URI.Info[path: "/yawnt"], request) do
    case request.body do
      "piace" ->
        request.response(200, "dire cose sceme")

      _ ->
        request.response(200, "a me lo chiedi?")
    end
  end

  def get(URI.Info[path: "/chuzz"], request) do
    request.response(200, "chuzz idla\n")
  end

  def missing(_, _, request) do
    request.response(404)
  end
end
