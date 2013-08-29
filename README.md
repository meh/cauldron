Cauldron - an HTTP/SPDY server as a library
===========================================
Cauldron is a web server implemented as a library, it's easy to embed into
other applications and fairly easy to implement DSLs on it, an example
of a DSL using cauldron is [urna](https://github.com/meh/urna).

Examples
--------

```elixir
defmodule Foo do
  # respond to a GET / request with "Hello, World!"
  def handle("GET", URI.Info[path: "/"], req) do
    req.reply(200, "Hello, World!")
  end
end

# open the cauldron on port 8080, you can have multiple listeners using the
# same module
Cauldron.open Foo, listen: [[port: 8080]]
```

Why?
----
Because I don't like how cowboy handles things and there are no other pure
Elixir webservers around that I know of.

Speed
-----
Right now cauldron is faster than node.js and slower than cowboy, there' still
space for speed improvements but it's not a high priority right now.

The slowness in comparison to cowboy comes from cauldron design, at least in
the HTTP part.

Right now when a connection comes in, you have 3 processes spawn to handle it
plus a process per HTTP request, the design is made to keep it simple and to
scale well with pipelined request, this means that it's slower when you have
a single request per connection.

I still have to figure out a decent way to reduce the number of processes when
there's just a single request coming in while maintining the simplicity and the
API semantics.
