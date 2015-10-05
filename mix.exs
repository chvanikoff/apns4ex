defmodule APNS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :apns,
      version: "0.0.5",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      package: package,
      name: "apns4ex",
      source_url: "https://github.com/chvanikoff/apns4ex",
      description: """
      APNS library for Elixir
      """
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [
      :logger,
      :public_key,
      :ssl,
      :poison,
      :hexate
    ],
    mod: {APNS, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:hexate, "~> 0.5"},
      {:poison, "~> 1.5"}
    ]
  end

  defp package do
    [
      contributors: ["Roman Chvanikov"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/chvanikoff/apns4ex"}
    ]
  end
end
