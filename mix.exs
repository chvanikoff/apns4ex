defmodule APNS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :apns,
      version: "0.0.12",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      package: package,
      name: "apns4ex",
      source_url: "https://github.com/chvanikoff/apns4ex",
      description: """
      APNS (Apple Push Notification Service) library for Elixir
      """
    ]
  end

  def application do
    [applications: [
      :logger,
      :public_key,
      :ssl,
      :poison,
      :poolboy
    ],
    mod: {APNS, []}]
  end

  defp deps do
    [
      {:poison, "~> 1.5"},
      {:poolboy, "~> 1.5"}
    ]
  end

  defp package do
    [
      maintainers: ["Roman Chvanikov", "Vladimir Reshetnikov"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/chvanikoff/apns4ex"}
    ]
  end
end
