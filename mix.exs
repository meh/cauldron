defmodule Cauldron.Mixfile do
  use Mix.Project

  def project do
    [ app: :cauldron,
      version: "0.1.3",
      elixir: "~> 0.14.3",
      deps: deps,
      package: package,
      description: "Web server library written in Elixir" ]
  end

  defp package do
    [ contributors: ["meh"],
      licenses: ["WTFPL"],
      links: [ { "GitHub", "https://github.com/meh/cauldron" } ] ]
  end

  def application do
    [ applications: [:reagent, :httprot] ]
  end

  defp deps do
    [ { :reagent, "~> 0.1.3" },
      { :httprot, "~> 0.1.3" } ]
  end
end
