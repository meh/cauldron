#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defprotocol Cauldron.Response do
  @doc """
  Send the HTTP status.
  """
  @spec status(t, integer | { integer, String.t }) :: t
  def status(self, code)

  @doc """
  Send the HTTP headers.
  """
  @spec headers(t, Headers.t) :: t
  def headers(self, headers)

  @doc """
  Stream a file or an IO device.
  """
  @spec stream(t, String.t | :io.device) :: t
  def stream(self, string_or_io)

  @doc """
  Stream a response body with a generator function.
  """
  @spec stream(t, term, (term -> { iolist, term })) :: t
  def stream(self, acc, fun)

  @doc """
  Send the passed binary as body.
  """
  @spec body(t, iolist) :: t
  def body(self, body)

  @doc """
  Send a chunk.
  """
  def send(self, chunk)
end
