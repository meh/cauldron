defmodule Cauldron.Mixfile do
  use Mix.Project

  def project do
    [ app: :cauldron,
      version: "0.1.0",
      elixir: "~> 0.13.2",
      deps: deps,
      package: package,
      description: "Web server library written in Elixir" ]
  end

  defp package do
    [ contributors: ["meh"],
      license: "WTFPL",
      links: [ { "GitHub", "https://github.com/meh/cauldron" } ] ]
  end

  def application do
    [ applications: [:reagent] ]
  end

  defp deps do
    [ { :reagent, "~> 0.1.1" } ]
  end
end
