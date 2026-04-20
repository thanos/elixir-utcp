defmodule ExUtcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_utcp,
      version: "0.3.2",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      source_url: "https://github.com/universal-tool-calling-protocol/elixir-utcp",
      docs: [
        main: "ExUtcp",
        extras: ["README.md", "LICENSE"]
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        verify: :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},

      # WebSocket support
      {:websockex, "~> 0.4"},

      # gRPC support
      {:grpc, "~> 0.11"},
      {:protobuf, "~> 0.15"},

      # GraphQL support
      {:absinthe, "~> 1.8"},
      {:absinthe_plug, "~> 1.5"},

      # Environment variables
      {:dotenvy, "~> 1.1"},

      # YAML support for OpenAPI
      {:yaml_elixir, "~> 2.12"},

      # Search libraries
      {:fuzzy_compare, "~> 1.1"},
      {:truffle_hog, "~> 0.1"},
      {:haystack, "~> 0.1"},

      # Monitoring and metrics
      {:telemetry, "~> 1.3"},
      {:prom_ex, "~> 1.11"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},

      # WebRTC support
      {:ex_webrtc, "~> 0.15"},

      # Dev & test tooling
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.11", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.2", only: :test}
    ]
  end

  defp description do
    "Elixir implementation of the Universal Tool Calling Protocol (UTCP)"
  end

  defp package do
    [
      maintainers: ["Thanos Vassilakis"],
      licenses: ["MPL-2.0"],
      links: %{
        "GitHub" => "https://github.com/universal-tool-calling-protocol/elixir-utcp",
        "Documentation" => "https://hexdocs.pm/ex_utcp"
      }
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      lint: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format github"
      ],
      "lint.fix": ["format", "credo --strict"],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --check-unused",
        "format"
      ],
      verify: &verify/1
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit],
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [:error_handling, :underspecs]
    ]
  end

  defp verify(_) do
    steps = [
      # ["precommit", :dev],
      {"compile --warnings-as-errors", :dev},
      {"format --check-formatted", :dev},
      {"credo --strict", :dev},
      # {"sobelow --config", :dev},
      {"dialyzer", :dev},
      {"test --cover", :test},
      {"docs --warnings-as-errors", :dev}
    ]

    Enum.each(steps, fn {task, env} ->
      Mix.shell().info(IO.ANSI.format([:bright, "==> mix #{task}", :reset]))

      mix_executable =
        System.find_executable("mix") ||
          Mix.raise("Could not find `mix` executable on PATH")

      {_, exit_code} =
        System.cmd(mix_executable, String.split(task),
          env: [{"MIX_ENV", to_string(env)}],
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true
        )

      if exit_code != 0 do
        Mix.raise("mix #{task} failed (exit code #{exit_code})")
      end
    end)

    Mix.shell().info(IO.ANSI.format([:green, :bright, "\nAll verification checks passed!", :reset]))
  end
end
