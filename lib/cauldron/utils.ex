#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Cauldron.Utils do
  @spec downcase(String.t) :: String.t
  def downcase(string) do
    do_downcase(string) |> iolist_to_binary
  end

  defp do_downcase(<< char :: size(8), rest :: binary >>) when char in ?A .. ?Z do
    [char + 32] ++ do_downcase(rest)
  end

  defp do_downcase(<< char :: size(8), rest :: binary >>) do
    [char] ++ do_downcase(rest)
  end

  defp do_downcase("") do
    []
  end

  @spec upcase(String.t) :: String.t
  def upcase(string) do
    do_upcase(string) |> iolist_to_binary
  end

  defp do_upcase(<< char :: size(8), rest :: binary >>) when char in ?a .. ?z do
    [char - 32] ++ do_upcase(rest)
  end

  defp do_upcase(<< char :: size(8), rest :: binary >>) do
    [char] ++ do_upcase(rest)
  end

  defp do_upcase("") do
    []
  end
end
