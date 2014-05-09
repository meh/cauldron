#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron.Headers do
  alias Cauldron.Utils, as: U
  alias __MODULE__, as: H

  defstruct list: []

  use Dict.Behaviour

  def new do
    %H{}
  end

  def fetch(self, name) do
    key = U.downcase(name |> to_string)

    case self.list |> List.keyfind(key, 0) do
      { _, _, value } ->
        { :ok, out!(key, value) }

      nil ->
        :error
    end
  end

  defp out!("content-length", value) do
    binary_to_integer(value)
  end

  defp out!("accept", value) do
    for part <- value |> String.split(~r/\s*,\s*/) do
      case part |> String.split(~r/\s*;\s*/) do
        [type] ->
          { type, 1.0 }

        [type, "q=" <> quality] ->
          { type, Float.parse(quality) |> elem(0) }
      end
    end
  end

  defp out!(_, value) do
    value
  end

  def put(self, name, value) do
    key = U.downcase(name |> to_string)

    %H{self | list: self.list |> List.keystore(key, 0, { key, name, in!(key, value) })}
  end

  defp in!("content-length", value) do
    value |> to_string
  end

  defp in!("accept", value) when value |> is_list do
    for { name, quality } <- value do
      if quality == 1.0 do
        name
      else
        "#{name};q=#{quality}"
      end
    end |> Enum.join ","
  end

  defp in!(_, value) do
    value
  end

  def delete(self, name) do
    key = U.downcase(name |> to_string)

    %H{self | list: self.list |> List.keydelete(key, 0)}
  end

  def size(self) do
    self.list |> length
  end

  @doc false
  def reduce(%H{list: list}, acc, fun) do
    reduce(list, acc, fun)
  end

  def reduce(_list, { :halt, acc }, _fun) do
    { :halted, acc }
  end

  def reduce(list, { :suspend, acc }, fun) do
    { :suspended, acc, &reduce(list, &1, fun) }
  end

  def reduce([], { :cont, acc }, _fun) do
    { :done, acc }
  end

  def reduce([{ key, name, value } | rest], { :cont, acc }, fun) do
    reduce(rest, fun.({ name, out!(key, value) }, acc), fun)
  end

  defimpl Access do
    def access(headers, key) do
      Cauldron.Headers.get(headers, key)
    end
  end

  defimpl Enumerable do
    def reduce(headers, acc, fun) do
      Cauldron.Headers.reduce(headers, acc, fun)
    end

    def member?(headers, { key, value }) do
      { :ok, match?({ :ok, ^value }, Cauldron.Headers.fetch(headers, key)) }
    end

    def member?(_, _) do
      { :ok, false }
    end

    def count(headers) do
      { :ok, Cauldron.Headers.size(headers) }
    end
  end

  defimpl Collectable do
    def empty(_) do
      Cauldron.Headers.new
    end

    def into(original) do
      { original, fn
          headers, { :cont, { k, v } } ->
            headers |> Dict.put(k, v)

          headers, :done ->
            headers

          _, :halt ->
            :ok
      end }
    end
  end
end
