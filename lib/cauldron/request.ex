#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defprotocol Cauldron.Request do
  alias HTTProt.Headers

  @doc """
  Check if the request has a body.
  """
  @spec has_body?(t) :: boolean
  def has_body?(self)

  @doc """
  Get the method used by the request.
  """
  @spec method(t) :: String.t
  def method(self)

  @doc """
  Get the URI used by the request.
  """
  @spec uri(t) :: URI.t
  def uri(self)

  @doc """
  Get the headers used by the request.
  """
  @spec headers(t) :: Headers.t
  def headers(self)

  @doc """
  Read a chunk from the request body, chunks are split respecting the
  `chunk_size` option of the listener.
  """
  @spec read(t) :: binary
  def read(self)

  @doc """
  Read a chunk from the request body, chunks are split by the given size.
  """
  @spec read(t, non_neg_integer) :: binary
  def read(self, size)

  @doc """
  Fetch the whole body from the request, or the rest if you used `read` before.
  """
  @spec body(t) :: binary
  def body(self)

  @doc """
  Create a response for the request, it is not sent to allow for more
  fine-grained responses.
  """
  @spec reply(t) :: Cauldron.Response.t
  def reply(self)


  @doc """
  Respond to the request sending a file or with just the response code.
  """
  @spec reply(t, String.t | integer) :: none
  def reply(self, path_or_code)

  @doc """
  Respond to the request with the given code and body or with the given code
  and IO handle.
  """
  @spec reply(t, integer | { integer, String.t }, :io.device | iolist) :: none
  def reply(self, code, io_or_body)

  @doc """
  Respond to the request with the given code, headers and body or with the
  given code and and generator function.
  """
  @spec reply(t, integer, Headers.t | term, iolist | (term -> { iolist, term })) :: none
  def reply(self, code, acc_or_headers, fun_or_body)

  @doc """
  Respond to the request with the given code, headers and generator function.
  """
  @spec reply(t, integer, H.t, term, (term -> { iolist, term })) :: none
  def reply(self, code, headers, acc, fun)
end
