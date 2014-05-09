defmodule Cauldron.Mixfile do
  use Mix.Project

  def project do
    [ app: :cauldron,
      version: "0.1.0",
      elixir: "~> 0.13.2-dev",
      deps: deps ]
  end

  def application do
    [ applications: [:reagent] ]
  end

  defp deps do
    [ { :reagent, github: "meh/reagent" } ]
  end
end
