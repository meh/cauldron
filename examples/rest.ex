defmodule REST do
  def handle(method, uri, request) do
    try do
      case String.upcase(method) do
        "GET" ->
          __MODULE__.get(uri, request)

        "POST" ->
          __MODULE__.post(uri, request)
      end
    rescue
      _ in [UndefinedFunctionError, FunctionClauseError] ->
        missing(String.upcase(method), uri, request)
    end
  end

  def get(URI.Info[path: "/yawnt"], request) do
    request.response(200, "yawnt e' scemo\n")
  end

  def get(URI.Info[path: "/yawnt/" <> what], request) do
    request.response(200, "yawnt e' #{what}\n")
  end

  def get(URI.Info[path: "/chuzz"], request) do
    request.response(200, "chuzz idla\n")
  end

  def missing(_, _, request) do
    request.response(404)
  end
end
