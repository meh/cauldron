#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron.HTTP.Headers do
  alias Cauldron.Utils

  @type t :: Keyword.t | record

  defrecordp :headers, __MODULE__, list: []

  def new do
    headers(list: [])
  end

  # TODO: coalesce multiple instances of same header
  def from_list(list) do
    Enum.reduce list, new, fn { name, value }, headers ->
      put(headers, name, value)
    end
  end

  def contains?(headers(list: list), key) do
    List.keymember?(list, Utils.downcase(key), 0)
  end

  def get(self, key, default // nil)

  def get(self, key, default) when key |> is_atom do
    get(self, key |> to_string, default)
  end

  def get(headers(list: list), key, default) do
    key = Utils.downcase(key)

    case List.keyfind(list, key, 0, default) do
      { _, _, value } ->
        case key do
          "content-length" ->
            binary_to_integer(value)

          "accept" ->
            String.split(value, %r/\s*,\s*/) |> Enum.map fn part ->
              case part |> String.split(%r/\s*;\s*/) do
                [type] ->
                  { type, 1.0 }

                [type, "q=" <> quality] ->
                  { type, binary_to_float(quality) }
              end
            end

          _ ->
            value
        end

      default ->
        default
    end
  end

  def put(self, name, value) when name |> is_atom do
    put(self, name |> to_string, value)
  end

  def put(headers(list: list), name, value) when value |> is_binary do
    key = Utils.downcase(name)

    headers(list: List.keystore(list, key, 0, { key, name, value }))
  end

  def put(headers(list: list), name, value) do
    key   = Utils.downcase(name)
    value = case key do
      "content-length" ->
        value |> to_string

      "accept" ->
        value |> Enum.map(fn
          { name, 1.0 }     -> name
          { name, quality } -> "#{name};q=#{quality}"
        end) |> Enum.join(",")
    end

    headers(list: List.keystore(list, key, 0, { key, name, value }))
  end

  def delete(headers(list: list), key) do
    headers(list: List.keydelete(list, Utils.downcase(key), 0))
  end

  def keys(headers(list: list)) do
    lc { _, key, _ } inlist list, do: key
  end

  def values(headers(list: list) = self) do
    lc { key, _, _ } inlist list, do: get(self, key)
  end

  def size(headers(list: list)) do
    length list
  end

  def to_list(headers(list: list)) do
    lc { _, key, value } inlist list, do: { key, value }
  end

  def reduce(headers(list: list), acc, fun) do
    List.foldl list, acc, fn { key, name, value }, acc ->
      fun.({ name, get(key) }, acc)
    end
  end

  def first(headers(list: [])) do
    nil
  end

  def first(headers(list: [{ _, name, value } | _]) = self) do
    { name, get(self, name) }
  end

  def next(headers(list: [])) do
    nil
  end

  def next(headers(list: [_])) do
    nil
  end

  def next(headers(list: [_ | tail])) do
    headers(list: tail)
  end
end

defimpl Data.Dictionary, for: Cauldron.HTTP.Headers do
  defdelegate get(self, key), to: Cauldron.HTTP.Headers
  defdelegate get(self, key, default), to: Cauldron.HTTP.Headers
  defdelegate get!(self, key), to: Cauldron.HTTP.Headers
  defdelegate put(self, key, value), to: Cauldron.HTTP.Headers
  defdelegate delete(self, key), to: Cauldron.HTTP.Headers
  defdelegate keys(self), to: Cauldron.HTTP.Headers
  defdelegate values(self), to: Cauldron.HTTP.Headers
end

defimpl Data.Contains, for: Cauldron.HTTP.Headers do
  defdelegate contains?(self, value), to: Cauldron.HTTP.Headers
end

defimpl Data.Emptyable, for: Cauldron.HTTP.Headers do
  def empty?(self) do
    Cauldron.HTTP.Headers.size(self) == 0
  end

  def clear(_) do
    Cauldron.HTTP.Headers.new
  end
end

defimpl Data.Sequence, for: Cauldron.HTTP.Headers do
  defdelegate first(self), to: Cauldron.HTTP.Headers
  defdelegate next(self), to: Cauldron.HTTP.Headers
end

defimpl Data.Reducible, for: Cauldron.HTTP.Headers do
  defdelegate reduce(self, acc, fun), to: Cauldron.HTTP.Headers
end

defimpl Data.Counted, for: Cauldron.HTTP.Headers do
  defdelegate count(self), to: Cauldron.HTTP.Headers, as: :size
end

defimpl Data.Listable, for: Cauldron.HTTP.Headers do
  defdelegate to_list(self), to: Cauldron.HTTP.Headers
end

defimpl Enumerable, for: Cauldron.HTTP.Headers do
  use Data.Enumerable
end

defimpl Access, for: Cauldron.HTTP.Headers do
  defdelegate access(self, key), to: Cauldron.HTTP.Headers, as: :get
end

defimpl String.Chars, for: Cauldron.HTTP.Headers do
  def to_string(headers) do
    Enum.join(lc { key, value } inlist Dict.to_list(headers) do
      "#{key}: #{value}"
    end, "\r\n")
  end
end

defimpl Inspect, for: Cauldron.HTTP.Headers do
  import Inspect.Algebra

  def inspect(headers, opts) do
    concat ["#Cauldron.HTTP.Headers<", Kernel.inspect(Data.to_list(headers), opts), ">"]
  end
end
