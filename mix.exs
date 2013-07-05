defmodule Cauldron.Mixfile do
  use Mix.Project

  def project do
    [ app: :cauldron,
      version: "0.0.1",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:socket] ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [ { :datastructures, github: "meh/elixir-datastructures" },
      { :socket, github: "meh/elixir-socket" } ]
  end
end
