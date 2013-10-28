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

# open the cauldron on port 8080
Cauldron.start Foo, port: 8080
```

Why?
----
Because I don't like how cowboy handles things and there are no other pure
Elixir webservers around that I know of.

Speed
-----
Right now cauldron is faster than node.js and slower than cowboy, there' still
space for speed improvements but it's not a high priority right now.

The slowness comes from protocol dispatching in Elixir, protocol consolidation
will fix that.

Also we don't use an hand-crafted decoder like cowboy does but use
`:erlang.decode_packet`.
