defmodule Cauldron.HTTP.Headers do
  alias Cauldron.Utils

  defrecordp :headers, list: []

  def new do
    headers(list: [])
  end

  # TODO: coalesce multiple instances of same header
  def from_list(list) do
    headers(list: lc { name, value } inlist list do
      if is_atom(name) do
        value = case name do
          _ ->
            value
        end

        name = atom_to_binary(name)

        { Utils.downcase(name), name, value }
      else
        { Utils.downcase(name), name, iolist_to_binary(value) }
      end
    end)
  end

  def contains?(headers(list: list), key) do
    List.keymember?(list, Utils.downcase(key), 0)
  end

  def get(headers(list: list), key, default // nil) do
    case List.keyfind(list, Utils.downcase(key), 0, default) do
      { _, _, value } ->
        value

      default ->
        default
    end
  end

  def put(headers(list: list), key, value) do
    headers(list: List.keystore(list, Utils.downcase(key), 0,
      { Utils.downcase(key), key, value }))
  end

  def delete(headers(list: list), key) do
    headers(list: List.keydelete(list, Utils.downcase(key), 0))
  end

  def keys(headers(list: list)) do
    lc { _, key, _ } inlist list, do: key
  end

  def values(headers(list: list)) do
    lc { _, _, value } inlist list, do: value
  end

  def size(headers(list: list)) do
    length list
  end

  def to_list(headers(list: list)) do
    lc { _, key, value } inlist list, do: { key, value }
  end

  def reduce(headers(list: list), acc, fun) do
    List.foldl list, acc, fn { _, key, value }, acc ->
      fun.({ key, value }, acc)
    end
  end

  def first(headers(list: [])) do
    nil
  end

  def first(headers(list: [{ _, name, value } | _])) do
    { name, value }
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

defimpl Access, for: Cauldron.HTTP.Headers do
  defdelegate access(self, key), to: Cauldron.HTTP.Headers, as: :get
end

defimpl Binary.Chars, for: Cauldron.HTTP.Headers do
  def to_binary(headers) do
    Enum.join(lc { key, value } inlist Dict.to_list(headers) do
      "#{key}: #{value}"
    end, "\r\n")
  end
end

defimpl Binary.Inspect, for: Cauldron.HTTP.Headers do
  def inspect(headers, opts) do
    "#Cauldron.HTTP.Headers<" <> Kernel.inspect(Data.to_list(headers), opts) <> ">"
  end
end
