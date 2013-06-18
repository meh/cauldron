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
    request.reply("mix.exs")
  end

  def get(URI.Info[path: "/io"], request) do
    request.reply(200, File.open!("mix.exs"))
  end

  def get(URI.Info[path: "/generator"], request) do
    request.reply 200, true, fn
      true  -> { "lol", false }
      false -> :eof
    end
  end

  def get(URI.Info[path: "/yawnt"], request) do
    request.reply(200, "yawnt e' scemo\n")
  end

  def get(URI.Info[path: "/yawnt/" <> what], request) do
    request.reply(200, "yawnt e' #{what}\n")
  end

  def post(URI.Info[path: "/yawnt"], request) do
    case request.body do
      "piace" ->
        request.reply(200, "dire cose sceme")

      _ ->
        request.reply(200, "a me lo chiedi?")
    end
  end

  def get(URI.Info[path: "/chuzz"], request) do
    request.reply(200, "chuzz idla\n")
  end

  def missing(_, _, request) do
    request.reply(404)
  end
end
