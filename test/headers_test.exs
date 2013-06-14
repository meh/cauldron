Code.require_file "test_helper.exs", __DIR__

defmodule Test.HTTP.Headers do
  use ExUnit.Case

  alias Cauldron.HTTP.Headers, as: H

  test :from_list do
    h = H.from_list [{ "Content-Length", "234" }, { "hOsT", "google.com" }]

    assert H.values(h) == ["234", "google.com"]
    assert H.keys(h)   == ["Content-Length", "hOsT"]

    assert H.get(h, "content-length") == "234"
    assert H.get(h, "host") == "google.com"
  end
end
