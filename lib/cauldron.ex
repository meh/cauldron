#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron do
  defmacro __using__(_opts) do
    quote do
      alias HTTProt.Headers
      alias HTTProt.Status
      alias Cauldron.Request
      alias Cauldron.Response
    end
  end

  use Data

  @options backlog: 1024,
           recv:    [buffer: 16 * 1024]

  def start(name, listener) do
    Reagent.start __MODULE__, Keyword.merge(listener, env: [callback: name], options: @options)
  end

  def start_link(name, listener) do
    Reagent.start_link __MODULE__, Keyword.merge(listener, env: [callback: name], options: @options)
  end

  use Reagent.Behaviour

  def start(connection) do
    case connection |> Reagent.Connection.negotiated_protocol || "http/1.1" do
      "http/" <> version ->
        Cauldron.HTTP.start(version, connection, Dict.get(connection.listener.env, :callback))

      _ ->
        connection |> Socket.close
    end
  end
end
