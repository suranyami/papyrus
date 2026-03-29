defmodule Papyrus.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/papyrus-epaper/papyrus"

  def project do
    [
      app: :papyrus,
      version: @version,
      elixir: "~> 1.15",
      compilers: [:elixir_make | Mix.compilers()],
      make_cwd: "c_src",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description: "Elixir/Nerves library for driving Waveshare ePaper displays via a supervised OS port process",
      name: "Papyrus",
      source_url: @source_url,
      homepage_url: "https://hexdocs.pm/papyrus"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Papyrus.Application, []}
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.7", runtime: false},
      {:stb_image, "~> 0.6"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "c_src",
        "priv/.gitkeep",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "HexDocs" => "https://hexdocs.pm/papyrus"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/getting_started.md",
        "guides/hardware_setup.md"
      ],
      groups_for_modules: [
        "Display Specs": [Papyrus.DisplaySpec, Papyrus.Displays.Waveshare12in48],
        Internals: [Papyrus.Display, Papyrus.Protocol, Papyrus.Application]
      ]
    ]
  end
end
