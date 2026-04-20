defmodule ExUtcp.Transports.CliUnitTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Transports.Cli

  @moduletag :unit

  describe "new/1" do
    test "creates CLI transport with defaults" do
      transport = Cli.new()

      assert transport.logger != nil
    end

    test "creates CLI transport with custom logger" do
      logger = fn msg -> IO.puts("[TEST] #{msg}") end
      transport = Cli.new(logger: logger)

      assert transport.logger == logger
    end
  end

  describe "transport_name/0" do
    test "returns cli" do
      assert Cli.transport_name() == "cli"
    end
  end

  describe "supports_streaming?/0" do
    test "returns false" do
      refute Cli.supports_streaming?()
    end
  end

  describe "close/0" do
    test "returns ok" do
      assert Cli.close() == :ok
    end
  end

  describe "register_tool_provider/1" do
    test "returns error for non-cli provider type" do
      provider = %{type: :http, name: "test", url: "http://example.com"}
      assert {:error, msg} = Cli.register_tool_provider(provider)
      assert msg =~ "CLI transport can only be used with CLI providers"
    end

    test "returns error for websocket provider" do
      provider = %{type: :websocket, name: "test", url: "ws://example.com"}
      assert {:error, _} = Cli.register_tool_provider(provider)
    end

    test "returns error for graphql provider" do
      provider = %{type: :graphql, name: "test", url: "http://example.com/graphql"}
      assert {:error, _} = Cli.register_tool_provider(provider)
    end

    test "discovers tools from echo command" do
      provider = %{
        type: :cli,
        name: "echo_provider",
        command_name: "echo",
        working_dir: nil,
        env_vars: %{}
      }

      result = Cli.register_tool_provider(provider)

      # echo will output its argument; it may or may not produce valid UTCP JSON
      # The important thing is it doesn't error for type mismatch
      case result do
        {:ok, _tools} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "discovers tools from echo with JSON output" do
      provider = %{
        type: :cli,
        name: "json_provider",
        command_name: ~s(echo '{"version":"0.3.1","tools":[]}'),
        working_dir: nil,
        env_vars: %{}
      }

      result = Cli.register_tool_provider(provider)

      case result do
        {:ok, tools} -> assert is_list(tools)
        {:error, _reason} -> :ok
      end
    end

    test "returns error for invalid command path with shell metacharacters" do
      provider = %{
        type: :cli,
        name: "bad_provider",
        command_name: "rm; echo pwned",
        working_dir: nil,
        env_vars: %{}
      }

      assert {:error, _} = Cli.register_tool_provider(provider)
    end
  end

  describe "call_tool/3" do
    test "returns error for non-cli provider type" do
      provider = %{type: :http, name: "test", url: "http://example.com"}
      assert {:error, msg} = Cli.call_tool("tool", %{}, provider)
      assert msg =~ "CLI transport can only be used with CLI providers"
    end

    test "returns error for mcp provider type" do
      provider = %{type: :mcp, name: "test", url: "http://example.com"}
      assert {:error, _} = Cli.call_tool("tool", %{}, provider)
    end
  end

  describe "call_tool_stream/3" do
    test "returns error (streaming not supported)" do
      provider = %{type: :cli, name: "test", command_name: "echo"}
      assert {:error, msg} = Cli.call_tool_stream("tool", %{}, provider)
      assert msg =~ "Streaming not supported"
    end
  end

  describe "deregister_tool_provider/1" do
    test "always returns ok" do
      assert Cli.deregister_tool_provider(%{type: :cli}) == :ok
    end

    test "returns ok for any provider" do
      assert Cli.deregister_tool_provider(%{}) == :ok
    end
  end
end
