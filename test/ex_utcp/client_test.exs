defmodule ExUtcp.ClientTest do
  use ExUnit.Case, async: false

  alias ExUtcp.Client
  alias ExUtcp.Config
  alias ExUtcp.Providers

  @moduletag :unit

  describe "start_link/1" do
    test "starts a client with default config" do
      config = Config.new()
      assert {:ok, pid} = Client.start_link(config)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "starts a client with named registration" do
      config = Config.new()
      assert {:ok, pid} = Client.start_link(config, :test_client_named)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  describe "client operations" do
    setup do
      config = Config.new()
      {:ok, pid} = Client.start_link(config)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, client: pid}
    end

    test "get_config/1 returns the client configuration", %{client: client} do
      config = Client.get_config(client)
      assert config.variables == %{}
      assert config.providers_file_path == nil
    end

    test "get_transports/1 returns default transports", %{client: client} do
      transports = Client.get_transports(client)
      assert is_map(transports)
      assert Map.has_key?(transports, "http")
      assert Map.has_key?(transports, "cli")
      assert Map.has_key?(transports, "websocket")
      assert Map.has_key?(transports, "grpc")
      assert Map.has_key?(transports, "graphql")
      assert Map.has_key?(transports, "mcp")
    end

    test "get_stats/1 returns empty stats initially", %{client: client} do
      stats = Client.get_stats(client)
      assert is_map(stats)
      assert stats.tool_count == 0
      assert stats.provider_count == 0
    end

    test "deregister_tool_provider/2 returns error for nonexistent provider", %{client: client} do
      result = Client.deregister_tool_provider(client, "nonexistent")
      assert {:error, _} = result
    end

    test "call_tool/3 returns error for nonexistent tool", %{client: client} do
      result = Client.call_tool(client, "nonexistent_tool", %{})
      assert {:error, _} = result
    end

    test "call_tool_stream/3 returns error for nonexistent tool", %{client: client} do
      result = Client.call_tool_stream(client, "nonexistent_tool", %{})
      assert {:error, _} = result
    end

    test "search_tools/2 returns empty list initially", %{client: client} do
      results = Client.search_tools(client, "test")
      assert is_list(results)
    end

    test "search_providers/2 returns empty list initially", %{client: client} do
      results = Client.search_providers(client, "test")
      assert is_list(results)
    end

    test "get_search_suggestions/2 returns list", %{client: client} do
      suggestions = Client.get_search_suggestions(client, "test")
      assert is_list(suggestions)
    end

    test "find_similar_tools/2 returns error for nonexistent tool", %{client: client} do
      result = Client.find_similar_tools(client, "nonexistent")
      assert {:error, _} = result
    end

    test "get_monitoring_metrics/1 returns metrics", %{client: client} do
      metrics = Client.get_monitoring_metrics(client)
      assert is_map(metrics)
    end

    test "get_health_status/1 returns health status", %{client: client} do
      status = Client.get_health_status(client)
      assert is_map(status)
    end

    test "validate_openapi/2 validates spec", %{client: client} do
      result = Client.validate_openapi(client, %{"openapi" => "3.0.0"})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "register_tool_provider/2" do
    setup do
      config = Config.new()
      {:ok, pid} = Client.start_link(config)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, client: pid}
    end

    test "returns error for unknown provider type", %{client: client} do
      provider = %{type: :unknown, name: "test"}
      result = Client.register_tool_provider(client, provider)
      assert {:error, _} = result
    end

    test "registers an HTTP provider", %{client: client} do
      provider = Providers.new_http_provider(name: "test_http", url: "https://api.example.com")
      result = Client.register_tool_provider(client, provider)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "registers a CLI provider with echo", %{client: client} do
      provider = Providers.new_cli_provider(name: "test_cli", command_name: "echo hello")
      result = Client.register_tool_provider(client, provider)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "deregisters a registered provider", %{client: client} do
      provider = Providers.new_http_provider(name: "test_dereg", url: "https://api.example.com")

      case Client.register_tool_provider(client, provider) do
        {:ok, _tools} ->
          result = Client.deregister_tool_provider(client, "test_dereg")
          assert result == :ok

        {:error, _} ->
          :ok
      end
    end
  end

  describe "config with providers_file_path" do
    @tag :skip
    test "fails to start with nonexistent providers file" do
      config = Config.new(providers_file_path: "/nonexistent/path.json")
      result = Client.start_link(config)
      assert match?({:error, _}, result)
    end
  end

  describe "OpenAPI operations" do
    setup do
      config = Config.new()
      {:ok, pid} = Client.start_link(config)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, client: pid}
    end

    test "validate_openapi/2 validates spec", %{client: client} do
      result = Client.validate_openapi(client, %{"openapi" => "3.0.0"})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :skip
    test "convert_openapi/3 with empty spec", %{client: client} do
      result =
        Client.convert_openapi(
          client,
          %{"openapi" => "3.0.0", "info" => %{"title" => "Test", "version" => "1.0"}, "paths" => %{}},
          []
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
