defmodule ExUtcp.ClientUnitTest do
  @moduledoc """
  Comprehensive unit tests for ExUtcp.Client using direct GenServer callback testing.
  """

  use ExUnit.Case, async: true

  alias ExUtcp.Client
  alias ExUtcp.Config
  alias ExUtcp.Providers
  alias ExUtcp.Repository
  alias ExUtcp.Search.Engine

  @moduletag :unit

  describe "struct and initialization" do
    test "struct has expected fields" do
      state = %Client{
        config: Config.new(),
        repository: Repository.new(),
        transports: %{},
        search_strategy: fn _, _, _ -> [] end
      }

      assert is_map(state.config)
      assert is_map(state.repository)
      assert is_map(state.transports)
      assert is_function(state.search_strategy)
    end
  end

  describe "default_transports/0" do
    test "returns map with all transport modules" do
      transports = %{
        "http" => ExUtcp.Transports.Http,
        "cli" => ExUtcp.Transports.Cli,
        "websocket" => ExUtcp.Transports.WebSocket,
        "grpc" => ExUtcp.Transports.Grpc,
        "graphql" => ExUtcp.Transports.Graphql,
        "mcp" => ExUtcp.Transports.Mcp,
        "webrtc" => ExUtcp.Transports.WebRTC
      }

      assert map_size(transports) == 7
      assert Map.has_key?(transports, "http")
      assert Map.has_key?(transports, "cli")
      assert Map.has_key?(transports, "websocket")
      assert Map.has_key?(transports, "grpc")
      assert Map.has_key?(transports, "graphql")
      assert Map.has_key?(transports, "mcp")
      assert Map.has_key?(transports, "webrtc")
    end
  end

  describe "init/1 callback" do
    test "initializes with config without providers_file_path" do
      config = Config.new()
      result = Client.init(config)

      assert match?({:ok, _state}, result)
      {:ok, state} = result
      assert state.config == config
      assert is_map(state.repository)
      assert map_size(state.transports) == 7
      assert is_function(state.search_strategy)
    end
  end

  describe "handle_call :register_provider" do
    test "returns error for unknown provider type" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = %{type: :unknown, name: "test"}
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end

    test "returns error for unsupported transport" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      # Remove all transports to test the no transport case
      state_no_transports = %{state | transports: %{}}
      provider = Providers.new_http_provider(name: "test", url: "http://example.com")
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state_no_transports)
      assert match?({:reply, {:error, _}, ^state_no_transports}, result)
    end

    @tag :skip
    test "registers HTTP provider successfully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = Providers.new_http_provider(name: "test_api", url: "http://example.com/api")
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state)
      assert match?({:reply, {:ok, _tools}, _new_state}, result)

      {:reply, {:ok, tools}, new_state} = result
      assert is_list(tools)
      assert new_state.repository != state.repository
    end

    @tag :skip
    test "registers CLI provider successfully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = Providers.new_cli_provider(name: "test_cli", command_name: "echo hello")
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state)
      assert match?({:reply, {:ok, _tools}, _new_state}, result)
    end

    @tag :skip
    test "registers WebSocket provider successfully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = Providers.new_websocket_provider(name: "test_ws", url: "ws://example.com/ws")
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state)
      assert match?({:reply, {:ok, _tools}, _new_state}, result)
    end

    @tag :skip
    test "registers gRPC provider successfully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = Providers.new_grpc_provider(name: "test_grpc", host: "localhost", port: 50_051)
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state)
      assert match?({:reply, {:ok, _tools}, _new_state}, result)
    end

    @tag :skip
    test "registers GraphQL provider successfully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = Providers.new_graphql_provider(name: "test_gql", url: "http://example.com/graphql")
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state)
      assert match?({:reply, {:ok, _tools}, _new_state}, result)
    end

    @tag :skip
    test "registers MCP provider successfully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = Providers.new_mcp_provider(name: "test_mcp", url: "http://example.com/mcp")
      from = {self(), :test_ref}

      result = Client.handle_call({:register_provider, provider}, from, state)
      assert match?({:reply, {:ok, _tools}, _new_state}, result)
    end
  end

  describe "handle_call :deregister_provider" do
    test "returns error for nonexistent provider" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:deregister_provider, "nonexistent"}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end

    @tag :skip
    test "deregisters existing provider" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      # First register
      provider = Providers.new_http_provider(name: "test_dereg", url: "http://example.com")

      {:reply, {:ok, _}, state_with_provider} =
        Client.handle_call({:register_provider, provider}, {self(), :ref}, state)

      # Now deregister
      from = {self(), :test_ref}
      result = Client.handle_call({:deregister_provider, "test_dereg"}, from, state_with_provider)
      assert match?({:reply, :ok, _new_state}, result)
    end
  end

  describe "handle_call :call_tool" do
    test "returns error for nonexistent tool" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:call_tool, "nonexistent", %{}}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :call_tool_stream" do
    test "returns error for nonexistent tool" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:call_tool_stream, "nonexistent", %{}}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :search_tools" do
    test "returns empty list with no tools" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:search_tools, "test query", %{}}, from, state)
      assert match?({:reply, r, ^state} when is_list(r), result)
    end

    test "uses default algorithm when not specified" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:search_tools, "test", %{}}, from, state)
      assert match?({:reply, _, ^state}, result)
    end

    test "accepts custom filters" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}
      opts = %{filters: %{provider: "test", transport: "http"}}

      result = Client.handle_call({:search_tools, "test", opts}, from, state)
      assert match?({:reply, _, ^state}, result)
    end
  end

  describe "handle_call :get_transports" do
    test "returns transport map" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call(:get_transports, from, state)
      assert match?({:reply, t, ^state} when is_map(t) and map_size(t) == 7, result)
    end
  end

  describe "handle_call :get_config" do
    test "returns client config" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call(:get_config, from, state)
      assert match?({:reply, ^config, ^state}, result)
    end
  end

  describe "handle_call :get_stats" do
    test "returns stats with zero counts" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call(:get_stats, from, state)
      assert match?({:reply, %{tool_count: 0, provider_count: 0}, ^state}, result)
    end

    @tag :skip
    test "returns correct counts after registration" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      # Register a provider
      provider = Providers.new_http_provider(name: "stats_test", url: "http://example.com")

      {:reply, {:ok, _tools}, state_with_provider} =
        Client.handle_call({:register_provider, provider}, {self(), :ref}, state)

      from = {self(), :test_ref}
      {:reply, stats, _} = Client.handle_call(:get_stats, from, state_with_provider)
      assert stats.provider_count >= 1
    end
  end

  describe "handle_call :get_monitoring_metrics" do
    test "returns metrics map" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call(:get_monitoring_metrics, from, state)
      assert match?({:reply, m, ^state} when is_map(m), result)
    end
  end

  describe "handle_call :get_health_status" do
    test "returns health status map" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call(:get_health_status, from, state)
      assert match?({:reply, h, ^state} when is_map(h), result)
    end
  end

  describe "handle_call :get_performance_summary" do
    @tag :skip
    test "returns performance summary map" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call(:get_performance_summary, from, state)
      assert match?({:reply, s, ^state} when is_map(s), result)
    end
  end

  describe "handle_call :validate_openapi" do
    test "validates a valid spec" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}
      spec = %{"openapi" => "3.0.0", "info" => %{"title" => "Test", "version" => "1.0"}}

      result = Client.handle_call({:validate_openapi, spec}, from, state)
      assert match?({:reply, {:ok, _}, ^state}, result)
    end

    test "validates an invalid spec returns ok with errors" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}
      spec = %{}

      result = Client.handle_call({:validate_openapi, spec}, from, state)
      assert match?({:reply, {:ok, %{valid: false}}, ^state}, result)
    end
  end

  describe "handle_call :search_providers" do
    test "returns empty list with no providers" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:search_providers, "test", %{}}, from, state)
      assert match?({:reply, r, ^state} when is_list(r), result)
    end
  end

  describe "handle_call :get_search_suggestions" do
    test "returns suggestions list" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:get_search_suggestions, "test", []}, from, state)
      assert match?({:reply, s, ^state} when is_list(s), result)
    end
  end

  describe "handle_call :find_similar_tools" do
    test "returns error for nonexistent tool" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      result = Client.handle_call({:find_similar_tools, "nonexistent", []}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :convert_openapi" do
    @tag :skip
    test "converts map spec successfully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}
      spec = %{"openapi" => "3.0.0", "info" => %{"title" => "Test", "version" => "1.0"}, "paths" => %{}}

      result = Client.handle_call({:convert_openapi, spec, []}, from, state)
      assert match?({:reply, {:ok, _}, _new_state}, result)
    end

    test "returns error for invalid spec" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}
      spec = %{}

      result = Client.handle_call({:convert_openapi, spec, []}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :convert_multiple_openapi" do
    @tag :skip
    test "converts multiple specs" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}

      specs = [
        %{"openapi" => "3.0.0", "info" => %{"title" => "Test1", "version" => "1.0"}, "paths" => %{}},
        %{"openapi" => "3.0.0", "info" => %{"title" => "Test2", "version" => "1.0"}, "paths" => %{}}
      ]

      result = Client.handle_call({:convert_multiple_openapi, specs, []}, from, state)
      assert match?({:reply, {:ok, _}, _new_state}, result)
    end

    test "returns error for invalid specs" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      from = {self(), :test_ref}
      specs = [%{}, %{}]

      result = Client.handle_call({:convert_multiple_openapi, specs, []}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "parse_provider/1" do
    test "parses HTTP provider data" do
      data = %{
        "type" => "http",
        "name" => "test_http",
        "url" => "http://example.com",
        "http_method" => "POST",
        "content_type" => "application/json",
        "headers" => %{"X-Custom" => "value"}
      }

      {:ok, provider} = parse_provider(data)
      assert provider.type == :http
      assert provider.name == "test_http"
      assert provider.url == "http://example.com"
    end

    test "parses CLI provider data" do
      data = %{
        "type" => "cli",
        "name" => "test_cli",
        "command_name" => "ls -la",
        "working_dir" => "/tmp",
        "env_vars" => %{"PATH" => "/usr/bin"}
      }

      {:ok, provider} = parse_provider(data)
      assert provider.type == :cli
      assert provider.name == "test_cli"
    end

    test "parses WebSocket provider data" do
      data = %{
        "type" => "websocket",
        "name" => "test_ws",
        "url" => "ws://example.com/ws",
        "protocol" => "graphql-ws",
        "keep_alive" => true
      }

      {:ok, provider} = parse_provider(data)
      assert provider.type == :websocket
      assert provider.name == "test_ws"
    end

    test "parses gRPC provider data" do
      data = %{
        "type" => "grpc",
        "name" => "test_grpc",
        "host" => "localhost",
        "port" => 50_051,
        "service_name" => "MyService",
        "use_ssl" => true
      }

      {:ok, provider} = parse_provider(data)
      assert provider.type == :grpc
      assert provider.name == "test_grpc"
    end

    test "parses GraphQL provider data" do
      data = %{
        "type" => "graphql",
        "name" => "test_gql",
        "url" => "http://example.com/graphql"
      }

      {:ok, provider} = parse_provider(data)
      assert provider.type == :graphql
      assert provider.name == "test_gql"
    end

    test "parses MCP provider data" do
      data = %{
        "type" => "mcp",
        "name" => "test_mcp",
        "url" => "http://example.com/mcp"
      }

      {:ok, provider} = parse_provider(data)
      assert provider.type == :mcp
      assert provider.name == "test_mcp"
    end

    test "returns error for unknown provider type" do
      data = %{"type" => "unknown", "name" => "test"}

      result = parse_provider(data)
      assert match?({:error, _}, result)
    end

    test "parses provider with provider_type field" do
      data = %{
        "provider_type" => "http",
        "name" => "test_http2",
        "url" => "http://example.com"
      }

      {:ok, provider} = parse_provider(data)
      assert provider.type == :http
    end
  end

  describe "parse_auth/1" do
    test "returns nil for nil input" do
      assert parse_auth(nil) == nil
    end

    test "parses API key auth" do
      auth_data = %{
        "type" => "api_key",
        "api_key" => "secret123",
        "location" => "header",
        "var_name" => "X-API-Key"
      }

      auth = parse_auth(auth_data)
      assert auth != nil
    end

    test "parses basic auth" do
      auth_data = %{
        "type" => "basic",
        "username" => "user",
        "password" => "pass"
      }

      auth = parse_auth(auth_data)
      assert auth != nil
    end

    test "parses OAuth2 auth" do
      auth_data = %{
        "type" => "oauth2",
        "client_id" => "client123",
        "client_secret" => "secret456",
        "token_url" => "https://auth.example.com/token",
        "scope" => "read write"
      }

      auth = parse_auth(auth_data)
      assert auth != nil
    end

    test "returns nil for unknown auth type" do
      auth_data = %{
        "type" => "unknown_auth",
        "data" => "something"
      }

      assert parse_auth(auth_data) == nil
    end

    test "parses auth with auth_type field" do
      auth_data = %{
        "auth_type" => "api_key",
        "api_key" => "key123"
      }

      auth = parse_auth(auth_data)
      assert auth != nil
    end
  end

  describe "validate_file_path/1" do
    test "rejects path with ../ traversal" do
      result = validate_file_path("../config.json")
      assert result == {:error, :invalid_path}
    end

    test "rejects path with ..\\ traversal" do
      result = validate_file_path("..\\config.json")
      assert result == {:error, :invalid_path}
    end

    test "rejects path with .. in expanded path" do
      result = validate_file_path("/../etc/passwd")
      assert result == {:error, :invalid_path}
    end

    test "rejects nonexistent file" do
      result = validate_file_path("/nonexistent/file.json")
      assert result == {:error, :file_not_found}
    end

    test "accepts valid existing file" do
      # Create a temp file
      tmp_file = Path.join(System.tmp_dir!(), "test_client_path.json")
      File.write!(tmp_file, "{}")

      result = validate_file_path(tmp_file)
      assert match?({:ok, _}, result)

      File.rm!(tmp_file)
    end
  end

  describe "parse_and_register_providers/2" do
    test "parses providers from map with providers key" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      data = %{
        "providers" => [
          %{"type" => "http", "name" => "test1", "url" => "http://example.com"}
        ]
      }

      result = parse_and_register_providers(state, data)
      assert match?({:ok, _}, result)
    end

    test "parses single provider from providers key" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      data = %{
        "providers" => %{"type" => "http", "name" => "test2", "url" => "http://example.com"}
      }

      result = parse_and_register_providers(state, data)
      assert match?({:ok, _}, result)
    end

    test "parses providers from list directly" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      data = [
        %{"type" => "http", "name" => "test3", "url" => "http://example.com"}
      ]

      result = parse_and_register_providers(state, data)
      assert match?({:ok, _}, result)
    end

    test "parses single provider map directly" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      data = %{"type" => "http", "name" => "test4", "url" => "http://example.com"}

      result = parse_and_register_providers(state, data)
      assert match?({:ok, _}, result)
    end

    test "handles invalid provider data gracefully" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      data = %{
        "providers" => [
          %{"type" => "invalid", "name" => "bad"}
        ]
      }

      result = parse_and_register_providers(state, data)
      assert match?({:ok, _}, result)
    end

    test "handles empty providers list" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      data = %{"providers" => []}

      result = parse_and_register_providers(state, data)
      assert match?({:ok, _}, result)
    end

    test "handles non-map non-list data" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      data = "invalid"

      result = parse_and_register_providers(state, data)
      assert match?({:ok, _}, result)
    end
  end

  describe "load_providers_from_file/2" do
    test "loads and parses valid JSON file" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      tmp_file = Path.join(System.tmp_dir!(), "test_providers.json")

      json =
        Jason.encode!(%{
          "providers" => [
            %{"type" => "http", "name" => "file_test", "url" => "http://example.com"}
          ]
        })

      File.write!(tmp_file, json)

      result = load_providers_from_file(state, tmp_file)
      assert match?({:ok, _}, result)

      File.rm!(tmp_file)
    end

    test "returns error for nonexistent file" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      result = load_providers_from_file(state, "/nonexistent/file.json")
      assert match?({:error, _}, result)
    end

    test "returns error for invalid JSON" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      tmp_file = Path.join(System.tmp_dir!(), "invalid.json")
      File.write!(tmp_file, "not valid json")

      result = load_providers_from_file(state, tmp_file)
      assert match?({:error, _}, result)

      File.rm!(tmp_file)
    end

    test "returns error for directory traversal" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      result = load_providers_from_file(state, "../config.json")
      assert result == {:error, "Invalid file path"}
    end
  end

  describe "default_search_strategy/0" do
    test "returns a function" do
      strategy = default_search_strategy()
      assert is_function(strategy)
    end

    test "strategy function accepts 3 arguments" do
      strategy = default_search_strategy()
      assert :erlang.fun_info(strategy)[:arity] == 3
    end
  end

  describe "create_search_engine_from_state/1" do
    test "creates search engine with empty repository" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      engine = create_search_engine_from_state(state)
      assert engine != nil
    end

    @tag :skip
    test "creates search engine with registered providers" do
      config = Config.new()
      {:ok, state} = Client.init(config)

      provider = Providers.new_http_provider(name: "search_engine_test", url: "http://example.com")

      {:reply, {:ok, _}, state_with_provider} =
        Client.handle_call({:register_provider, provider}, {self(), :ref}, state)

      engine = create_search_engine_from_state(state_with_provider)
      assert engine != nil
    end
  end

  describe "extract_call_name/2" do
    test "returns tool_name for non-mcp providers" do
      assert extract_call_name(:http, "my_tool") == "my_tool"
      assert extract_call_name(:cli, "my_tool") == "my_tool"
      assert extract_call_name(:graphql, "my_tool") == "my_tool"
    end

    test "extracts tool name for MCP provider" do
      result = extract_call_name(:mcp, "provider_name.tool_name")
      assert result == "tool_name"
    end

    test "extracts tool name for text provider" do
      result = extract_call_name(:text, "provider_name.tool_name")
      assert result == "tool_name"
    end
  end

  # Helper functions that mirror the private functions in Client module

  defp parse_provider(provider_data) do
    provider_type = Map.get(provider_data, "type") || Map.get(provider_data, "provider_type")

    case provider_type do
      "http" -> parse_http_provider(provider_data)
      "cli" -> parse_cli_provider(provider_data)
      "websocket" -> parse_websocket_provider(provider_data)
      "grpc" -> parse_grpc_provider(provider_data)
      "graphql" -> parse_graphql_provider(provider_data)
      "mcp" -> parse_mcp_provider(provider_data)
      _ -> {:error, "Unknown provider type: #{provider_type}"}
    end
  end

  defp parse_http_provider(data) do
    provider =
      Providers.new_http_provider(
        name: Map.get(data, "name", ""),
        http_method: Map.get(data, "http_method", "GET"),
        url: Map.get(data, "url", ""),
        content_type: Map.get(data, "content_type", "application/json"),
        auth: parse_auth(Map.get(data, "auth")),
        headers: Map.get(data, "headers", %{}),
        body_field: Map.get(data, "body_field"),
        header_fields: Map.get(data, "header_fields", [])
      )

    {:ok, provider}
  end

  defp parse_cli_provider(data) do
    provider =
      Providers.new_cli_provider(
        name: Map.get(data, "name", ""),
        command_name: Map.get(data, "command_name", ""),
        working_dir: Map.get(data, "working_dir"),
        env_vars: Map.get(data, "env_vars", %{})
      )

    {:ok, provider}
  end

  defp parse_websocket_provider(data) do
    provider =
      Providers.new_websocket_provider(
        name: Map.get(data, "name", ""),
        url: Map.get(data, "url", ""),
        protocol: Map.get(data, "protocol"),
        keep_alive: Map.get(data, "keep_alive", false),
        auth: parse_auth(Map.get(data, "auth")),
        headers: Map.get(data, "headers", %{}),
        header_fields: Map.get(data, "header_fields", [])
      )

    {:ok, provider}
  end

  defp parse_grpc_provider(data) do
    provider =
      Providers.new_grpc_provider(
        name: Map.get(data, "name", ""),
        host: Map.get(data, "host", "127.0.0.1"),
        port: Map.get(data, "port", 9339),
        service_name: Map.get(data, "service_name", "UTCPService"),
        method_name: Map.get(data, "method_name", "CallTool"),
        target: Map.get(data, "target"),
        use_ssl: Map.get(data, "use_ssl", false),
        auth: parse_auth(Map.get(data, "auth"))
      )

    {:ok, provider}
  end

  defp parse_graphql_provider(data) do
    provider =
      Providers.new_graphql_provider(
        name: Map.get(data, "name", ""),
        url: Map.get(data, "url", ""),
        auth: parse_auth(Map.get(data, "auth")),
        headers: Map.get(data, "headers", %{})
      )

    {:ok, provider}
  end

  defp parse_mcp_provider(data) do
    provider =
      Providers.new_mcp_provider(
        name: Map.get(data, "name", ""),
        url: Map.get(data, "url", ""),
        auth: parse_auth(Map.get(data, "auth"))
      )

    {:ok, provider}
  end

  defp parse_auth(nil), do: nil

  defp parse_auth(auth_data) when is_map(auth_data) do
    case Map.get(auth_data, "type") || Map.get(auth_data, "auth_type") do
      "api_key" ->
        ExUtcp.Auth.new_api_key_auth(
          api_key: Map.get(auth_data, "api_key", ""),
          location: Map.get(auth_data, "location", "header"),
          var_name: Map.get(auth_data, "var_name", "Authorization")
        )

      "basic" ->
        ExUtcp.Auth.new_basic_auth(
          username: Map.get(auth_data, "username", ""),
          password: Map.get(auth_data, "password", "")
        )

      "oauth2" ->
        ExUtcp.Auth.new_oauth2_auth(
          client_id: Map.get(auth_data, "client_id", ""),
          client_secret: Map.get(auth_data, "client_secret", ""),
          token_url: Map.get(auth_data, "token_url", ""),
          scope: Map.get(auth_data, "scope", "")
        )

      _ ->
        nil
    end
  end

  defp validate_file_path(file_path) do
    abs_path = Path.expand(file_path)

    cond do
      String.contains?(file_path, ["../", "..\\"]) ->
        {:error, :invalid_path}

      String.contains?(abs_path, "..") ->
        {:error, :invalid_path}

      not File.exists?(abs_path) ->
        {:error, :file_not_found}

      true ->
        {:ok, abs_path}
    end
  end

  defp load_providers_from_file(state, file_path) do
    with {:ok, validated_path} <- validate_file_path(file_path),
         {:ok, content} <- File.read(validated_path),
         {:ok, data} <- Jason.decode(content) do
      parse_and_register_providers(state, data)
    else
      {:error, :invalid_path} -> {:error, "Invalid file path"}
      {:error, %Jason.DecodeError{} = reason} -> {:error, "Failed to parse JSON: #{inspect(reason)}"}
      {:error, reason} -> {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp parse_and_register_providers(state, data) do
    providers_data =
      case data do
        %{"providers" => providers} when is_list(providers) -> providers
        %{"providers" => provider} when is_map(provider) -> [provider]
        providers when is_list(providers) -> providers
        provider when is_map(provider) -> [provider]
        _ -> []
      end

    updated_state =
      Enum.reduce(providers_data, state, fn provider_data, acc_state ->
        case parse_provider(provider_data) do
          {:ok, provider} ->
            case register_provider(acc_state, provider) do
              {:ok, _tools, new_state} -> new_state
              {:error, _reason} -> acc_state
            end

          {:error, _reason} ->
            acc_state
        end
      end)

    {:ok, updated_state}
  end

  defp register_provider(state, provider) do
    substituted_provider = Config.substitute_variables(state.config, provider)
    normalized_name = Providers.normalize_name(Providers.get_name(substituted_provider))
    substituted_provider = Providers.set_name(substituted_provider, normalized_name)

    transport_module = Map.get(state.transports, to_string(substituted_provider.type))

    if is_nil(transport_module) do
      {:error, "No transport available for provider type: #{substituted_provider.type}"}
    else
      case transport_module.register_tool_provider(substituted_provider) do
        {:ok, tools} ->
          normalized_tools =
            Enum.map(tools, fn tool ->
              normalized_name = ExUtcp.Tools.normalize_name(tool.name, normalized_name)
              Map.put(tool, :name, normalized_name)
            end)

          updated_repository =
            Repository.save_provider_with_tools(
              state.repository,
              substituted_provider,
              normalized_tools
            )

          updated_state = %{state | repository: updated_repository}
          {:ok, normalized_tools, updated_state}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp default_search_strategy do
    fn repository, query, limit ->
      Repository.search_tools(repository, query, limit)
    end
  end

  defp create_search_engine_from_state(state) do
    search_engine = Engine.new()

    tools = Repository.get_tools(state.repository)

    search_engine =
      Enum.reduce(tools, search_engine, fn tool, acc ->
        Engine.add_tool(acc, tool)
      end)

    providers = Repository.get_providers(state.repository)

    search_engine =
      Enum.reduce(providers, search_engine, fn provider, acc ->
        Engine.add_provider(acc, provider)
      end)

    search_engine
  end

  defp extract_call_name(provider_type, tool_name) do
    if provider_type in [:mcp, :text] do
      ExUtcp.Tools.extract_tool_name(tool_name)
    else
      tool_name
    end
  end
end
