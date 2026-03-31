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
      make_error_message: """
      C port compilation failed.
      lgpio (liblgpio-dev) is required on Linux/Raspberry Pi.
      Install it with: sudo apt install liblgpio-dev
      On macOS, compilation is skipped — display hardware requires Raspberry Pi.
      """,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description:
        "Elixir/Nerves library for driving Waveshare ePaper displays via a supervised OS port process",
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
      {:elixir_make, "~> 0.9", runtime: false},
      {:stb_image, "~> 0.6"},
      {:resvg, "~> 0.5"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "c_src",
        "priv/.gitkeep",
        "guides",
        "examples",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        ".formatter.exs"
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
      main: "getting-started",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/getting-started.md",
        "guides/loading-images.md",
        "guides/hardware-testing.md",
        "guides/html-rendering.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\//
      ],
      groups_for_modules: [
        "Public API": [Papyrus, Papyrus.Bitmap, Papyrus.Renderer.Headless, Papyrus.TestPattern],
        "Display Specs": [Papyrus.DisplaySpec, Papyrus.Displays.Waveshare12in48],
        Internals: [Papyrus.Display, Papyrus.Protocol, Papyrus.Application]
      ]
    ]
  end
end
