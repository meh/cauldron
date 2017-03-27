defmodule REST do
  use Cauldron

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

  def get(%URI{path: "/file"}, request) do
    request |> Request.reply("mix.exs")
  end

  def get(%URI{path: "/io"}, request) do
    request |> Request.reply(200, File.open!("mix.exs"))
  end

  def get(%URI{path: "/generator"}, request) do
    request |> Request.reply(200, true, fn
      true  -> { "lol", false }
      false -> :eof
    end)
  end

  def get(%URI{path: "/yawnt"}, request) do
    request |> Request.reply(200, "yawnt e' scemo\n")
  end

  def get(%URI{path: "/yawnt/" <> what}, request) do
    request |> Request.reply(200, "yawnt e' #{what}\n")
  end

  def get(%URI{path: "/chuzz"}, request) do
    request |> Request.reply(200, "chuzz idla\n")
  end

  def post(%URI{path: "/yawnt"}, request) do
    case request |> Request.body do
      "piace" ->
        request |> Request.reply(200, "dire cose sceme")

      _ ->
        request |> Request.reply(200, "a me lo chiedi?")
    end
  end

  def missing(_, _, request) do
    request |> Request.reply(404)
  end
end
