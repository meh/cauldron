#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron do
  @options backlog: 1024,
           buffer: 16 * 1024,
           advertisted_protocols: ["spdy/2", "spdy/3", "http/1.0", "http/1.1"]

  def start(callback, listener) do
    Reagent.start __MODULE__, Keyword.merge(listener, env: callback, options: @options)
  end

  def start_link(callback, listener) do
    Reagent.start_link __MODULE__, Keyword.merge(listener, env: callback, options: @options)
  end

  use Reagent.Behaviour

  def start(connection) do
    callback = connection.listener.env

    case connection |> Reagent.Connection.negotiated_protocol || "http/?" do
      "http/" <> version ->
        Cauldron.HTTP.start(version, connection, callback)

      "spdy/" <> version ->
        Cauldron.SPDY.start(version, connection, callback)
    end
  end
end
