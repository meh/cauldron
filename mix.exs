defmodule Cauldron.Mixfile do
  use Mix.Project

  def project do
    [ app: :cauldron,
      version: "0.1.7",
      deps: deps(),
      package: package(),
      description: "Web server library written in Elixir" ]
  end

  defp package do
    [ maintainers: ["meh"],
      licenses: ["WTFPL"],
      links: %{"GitHub" => "https://github.com/meh/cauldron"} ]
  end

  def application do
    [ applications: [:reagent, :httprot] ]
  end

  defp deps do
    [ { :reagent,        "~> 0.1" },
      { :httprot,        "~> 0.1" },
      { :datastructures, "~> 0.2" } ]
  end
end
