defmodule Example do
  def handle("GET", URI.Info[path: "/yawnt"], request) do
    request.response(200, "scemo\n")
  end

  def handle("GET", URI.Info[path: "/chuzz"], request) do
    request.response(200, "idla\n")
  end
end
