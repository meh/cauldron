defmodule Cauldron.HTTP.Headers do
  @behaviour Dict

  defrecordp :headers, list: []

  def new do
    headers(list: [])
  end

  # TODO: coalesce multiple instances of same header
  def from_list(list) do
    headers(list: lc { name, value } inlist list do
      { String.downcase(name), name, value }
    end)
  end

  def has_key?(headers(list: list), key) do
    List.keymember?(list, String.downcase(key), 0)
  end

  def get(headers(list: list), key, default // nil) do
    case List.keyfind(list, String.downcase(key), 0, default) do
      { _, _, value } ->
        value

      default ->
        default
    end
  end

  def put(headers(list: list), key, value) do
    headers(list: List.keystore(list, String.downcase(key), 0,
      { String.downcase(key), key, value }))
  end

  def put_new(self, key, value) do
    if has_key?(self, key) do
      self
    else
      put(self, key, value)
    end
  end

  def update(self, key, fun) do
    if has_key?(self, key) do
      put(self, key, fun.(get(self, key)))
    else
      raise KeyError, key: key
    end
  end

  def update(self, key, initial, fun) do
    update(put_new(self, key, initial), key, fun)
  end

  def pop(self, key, default // nil) do
    { get(self, key, default), delete(self, key) }
  end

  def split(self, keys) do
    Enum.reduce keys, { empty(self), self }, fn key, { a, b } ->
      case fetch(b, key) do
        { key, value } ->
          { put(a, key, value), delete(b, key) }

        nil ->
          { a, b }
      end
    end
  end

  def take(self, keys) do
    Enum.reduce keys, empty(self), fn key, result ->
      case fetch(self, key) do
        { key, value } ->
          put(result, key, value)

        nil ->
          result
      end
    end
  end

  def delete(headers(list: list), key) do
    headers(list: List.keydelete(list, String.downcase(key), 0))
  end

  def drop(headers(list: list), keys) do
    headers(list: Enum.reduce keys, list, fn key, acc ->
      List.keydelete(acc, String.downcase(key))
    end)
  end

  def empty(headers()) do
    headers(list: [])
  end

  def equal?(headers(list: a), headers(list: b)) do
    a = lc { name, _, value } inlist a, do: { name, value }
    b = lc { name, _, value } inlist b, do: { name, value }

    a == b
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
    Enum.reduce list, acc, fn { _, key, value }, acc ->
      fun.({ key, value }, acc)
    end
  end

  def fetch(headers(list: list), key) do
    case List.keyfind(list, String.downcase(key), 0) do
      { _, key, value } ->
        { key, value }

      nil ->
        nil
    end
  end
end

defimpl Data.Dictionary, for: Cauldron.HTTP.Headers do
  defdelegate contains?(self, key), to: Cauldron.HTTP.Headers, as: :has_key?
  defdelegate get(self, key), to: Cauldron.HTTP.Headers
  defdelegate get(self, key, default), to: Cauldron.HTTP.Headers
  defdelegate get!(self, key), to: Cauldron.HTTP.Headers
  defdelegate put(self, key, value), to: Cauldron.HTTP.Headers
  defdelegate put_new(self, key, value), to: Cauldron.HTTP.Headers
  defdelegate update(self, key, updater), to: Cauldron.HTTP.Headers
  defdelegate update(self, key, value, updater), to: Cauldron.HTTP.Headers
  defdelegate delete(self, key), to: Cauldron.HTTP.Headers
  defdelegate keys(self), to: Cauldron.HTTP.Headers
  defdelegate values(self), to: Cauldron.HTTP.Headers
end

defimpl Data.Emptyable, for: Cauldron.HTTP.Headers do
  def empty?(self) do
    Cauldron.HTTP.Headers.size(self) == 0
  end

  def clear(self) do
    Cauldron.HTTP.Headers.empty(self)
  end
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

defimpl Enumerable, for: Cauldron.HTTP.Headers do
  defdelegate reduce(self, acc, fun), to: Cauldron.HTTP.Headers
  defdelegate member?(self, what), to: Cauldron.HTTP.Headers
  defdelegate count(self), to: Cauldron.HTTP.Headers
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
    "#Cauldron.HTTP.Headers<" <> Kernel.inspect(Enum.to_list(headers), opts) <> ">"
  end
end
