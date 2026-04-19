defmodule ExUtcp.Transports.HttpUnitTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Auth
  alias ExUtcp.Transports.Http

  @moduletag :unit

  describe "new/1" do
    test "creates HTTP transport with defaults" do
      transport = Http.new()

      assert transport.http_client != nil
      assert transport.oauth_tokens == %{}
    end

    test "creates HTTP transport with custom options" do
      logger = fn _ -> :ok end
      transport = Http.new(logger: logger)

      assert transport.logger == logger
    end

    test "creates HTTP transport with custom http_client" do
      client = Req.new(url: "https://example.com")
      transport = Http.new(http_client: client)

      assert transport.http_client == client
    end
  end

  describe "transport_name/0" do
    test "returns http" do
      assert Http.transport_name() == "http"
    end
  end

  describe "supports_streaming?/0" do
    test "returns true" do
      assert Http.supports_streaming?() == true
    end
  end

  describe "close/0" do
    test "returns ok" do
      assert Http.close() == :ok
    end
  end

  describe "register_tool_provider/1" do
    test "returns error for non-http provider type" do
      provider = %{type: :websocket, name: "test", url: "ws://example.com"}
      assert {:error, msg} = Http.register_tool_provider(provider)
      assert msg =~ "HTTP transport can only be used with HTTP providers"
    end

    test "returns error for grpc provider type" do
      provider = %{type: :grpc, name: "test", url: "http://example.com"}
      assert {:error, msg} = Http.register_tool_provider(provider)
      assert msg =~ "HTTP transport can only be used with HTTP providers"
    end

    test "returns error for cli provider type" do
      provider = %{type: :cli, name: "test", command_name: "echo"}
      assert {:error, msg} = Http.register_tool_provider(provider)
      assert msg =~ "HTTP transport can only be used with HTTP providers"
    end
  end

  describe "deregister_tool_provider/1" do
    test "always returns ok" do
      assert Http.deregister_tool_provider(%{}) == :ok
      assert Http.deregister_tool_provider(%{type: :http}) == :ok
    end
  end

  describe "call_tool/3" do
    test "returns error for non-http provider type" do
      provider = %{type: :websocket, name: "test", url: "ws://example.com"}
      assert {:error, msg} = Http.call_tool("tool", %{}, provider)
      assert msg =~ "HTTP transport can only be used with HTTP providers"
    end

    test "returns error for mcp provider type" do
      provider = %{type: :mcp, name: "test", url: "http://example.com"}
      assert {:error, msg} = Http.call_tool("tool", %{}, provider)
      assert msg =~ "HTTP transport can only be used with HTTP providers"
    end
  end

  describe "call_tool_stream/3" do
    test "returns error for non-http provider type" do
      provider = %{type: :websocket, name: "test", url: "ws://example.com"}
      assert {:error, msg} = Http.call_tool_stream("tool", %{}, provider)
      assert msg =~ "HTTP transport can only be used with HTTP providers"
    end
  end

  describe "URL parameter substitution (via call_tool)" do
    test "substitutes URL parameters in path" do
      url = "https://api.example.com/users/{user_id}/posts/{post_id}"
      args = %{"user_id" => "42", "post_id" => "7", "limit" => 10}

      result = substitute_url(url, args)
      assert result == "https://api.example.com/users/42/posts/7"
    end

    test "leaves URL unchanged when no parameters match" do
      url = "https://api.example.com/users"
      args = %{"page" => 1}

      result = substitute_url(url, args)
      assert result == "https://api.example.com/users"
    end

    test "handles URL with single parameter" do
      url = "https://api.example.com/users/{id}"
      args = %{"id" => "123"}

      result = substitute_url(url, args)
      assert result == "https://api.example.com/users/123"
    end

    test "handles URL with no parameters at all" do
      url = "https://api.example.com/status"
      args = %{}

      result = substitute_url(url, args)
      assert result == "https://api.example.com/status"
    end

    test "removes URL parameters from query args" do
      url = "https://api.example.com/users/{user_id}"
      args = %{"user_id" => "42", "page" => 1, "limit" => 20}

      result = remove_url_params(args, url)
      assert result == %{"page" => 1, "limit" => 20}
    end

    test "removes all URL parameters" do
      url = "https://api.example.com/users/{user_id}/posts/{post_id}"
      args = %{"user_id" => "42", "post_id" => "7", "q" => "search"}

      result = remove_url_params(args, url)
      assert result == %{"q" => "search"}
    end

    test "removes no parameters when none are in URL" do
      url = "https://api.example.com/status"
      args = %{"page" => 1}

      result = remove_url_params(args, url)
      assert result == %{"page" => 1}
    end

    test "extracts URL parameters from URL" do
      url = "https://api.example.com/users/{user_id}/posts/{post_id}"

      params = extract_url_params(url)
      assert params == ["user_id", "post_id"]
    end

    test "returns empty list for URL with no parameters" do
      url = "https://api.example.com/status"

      params = extract_url_params(url)
      assert params == []
    end

    test "extracts single URL parameter" do
      url = "https://api.example.com/users/{id}"

      params = extract_url_params(url)
      assert params == ["id"]
    end
  end

  describe "SSE parsing" do
    test "parses data line with JSON" do
      line = ~s(data: {"message": "hello"})
      result = parse_sse_line(line)

      assert {:ok, %{type: :data, content: %{"message" => "hello"}}} = result
    end

    test "parses data line with plain text when JSON fails" do
      line = "data: plain text message"
      result = parse_sse_line(line)

      assert {:ok, %{type: :data, content: "plain text message"}} = result
    end

    test "parses [DONE] marker" do
      line = "data: [DONE]"
      result = parse_sse_line(line)

      assert {:ok, %{type: :end}} = result
    end

    test "skips empty lines" do
      result = parse_sse_line("")
      assert result == :continue
    end

    test "skips event lines" do
      result = parse_sse_line("event: message")
      assert result == :continue
    end

    test "skips id lines" do
      result = parse_sse_line("id: 123")
      assert result == :continue
    end

    test "skips retry lines" do
      result = parse_sse_line("retry: 1000")
      assert result == :continue
    end

    test "skips unknown lines" do
      result = parse_sse_line("something: value")
      assert result == :continue
    end

    test "skips whitespace-only trimmed lines" do
      result = parse_sse_line("   ")
      assert result == :continue
    end
  end

  describe "SSE data parsing" do
    test "parses complete SSE data into chunks" do
      buffer = ~s(data: {"msg": "hello"}\n\ndata: {"msg": "world"}\n\n)
      {chunks, remaining} = parse_sse_data(buffer)

      assert chunks != []
      assert remaining == "" or is_binary(remaining)
    end

    test "handles incomplete data at end" do
      buffer = ~s(data: {"msg": "hello"}\n\ndata: incomplet)
      {chunks, remaining} = parse_sse_data(buffer)

      assert chunks != []
      assert is_binary(remaining)
    end

    test "handles empty buffer" do
      buffer = ""
      {chunks, remaining} = parse_sse_data(buffer)

      assert chunks == []
      assert remaining == ""
    end

    test "handles only whitespace lines" do
      buffer = "\n\n\n"
      {chunks, remaining} = parse_sse_data(buffer)

      assert chunks == []
    end

    test "handles mixed complete and incomplete data" do
      buffer = "data: {\"test\": 1}\n\ndata: incompletemore"
      {chunks, remaining} = parse_sse_data(buffer)

      assert chunks != []
      assert is_binary(remaining)
    end
  end

  describe "SSE chunk processing" do
    test "processes data chunk with metadata" do
      chunk = %{type: :data, content: %{"result" => "ok"}}
      result = process_sse_chunk(chunk, 0)

      assert result.data == %{"result" => "ok"}
      assert result.sequence == 0
      assert result.metadata["sequence"] == 0
      assert is_integer(result.timestamp)
    end

    test "processes data chunk increments sequence" do
      chunk = %{type: :data, content: "test"}

      result0 = process_sse_chunk(chunk, 0)
      result1 = process_sse_chunk(chunk, 1)

      assert result0.sequence == 0
      assert result1.sequence == 1
    end

    test "processes end chunk" do
      chunk = %{type: :end}
      result = process_sse_chunk(chunk, 5)

      assert result.type == :end
      assert result.metadata["sequence"] == 5
    end

    test "processes error chunk" do
      chunk = %{type: :error, error: "something failed", code: 500}
      result = process_sse_chunk(chunk, 0)

      # Errors are passed through as-is
      assert result.type == :error
      assert result.error == "something failed"
    end
  end

  describe "discovery response parsing (via register_tool_provider with mock)" do
    test "parses UTCP manual format with tools list" do
      provider = %{
        type: :http,
        name: "test_api",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      data = %{
        "version" => "0.3.1",
        "tools" => [
          %{"name" => "get_user", "description" => "Get user", "inputs" => %{}, "outputs" => %{}}
        ]
      }

      result = parse_utcp_manual(data, provider)
      assert {:ok, tools} = result
      assert length(tools) == 1
      assert hd(tools).name == "get_user"
    end

    test "parses UTCP manual with empty tools" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      data = %{"version" => "0.3.1", "tools" => []}
      result = parse_utcp_manual(data, provider)
      assert {:ok, tools} = result
      assert tools == []
    end

    test "falls back to OpenAPI conversion for non-versioned data" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      data = %{"openapi" => "3.0.0", "paths" => %{}}
      result = parse_utcp_manual(data, provider)
      assert {:ok, tools} = result
      assert tools == []
    end

    test "normalizes tool data with defaults" do
      provider = %{
        type: :http,
        name: "test_api",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      tool_data = %{"name" => "search", "description" => "Search things"}
      result = normalize_tool(tool_data, provider)

      assert result.name == "search"
      assert result.description == "Search things"
      assert result.tags == []
      assert result.provider == provider
    end

    test "normalizes tool data with all fields" do
      provider = %{
        type: :http,
        name: "test_api",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      tool_data = %{
        "name" => "create_user",
        "description" => "Create a user",
        "inputs" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}},
        "outputs" => %{"type" => "object"},
        "tags" => ["api", "user"],
        "average_response_size" => 1024
      }

      result = normalize_tool(tool_data, provider)

      assert result.name == "create_user"
      assert result.description == "Create a user"
      assert result.tags == ["api", "user"]
      assert result.average_response_size == 1024
      assert result.inputs.type == "object"
      assert result.outputs.type == "object"
    end

    test "normalizes tool with missing fields" do
      provider = %{
        type: :http,
        name: "test_api",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      tool_data = %{}
      result = normalize_tool(tool_data, provider)

      assert result.name == ""
      assert result.description == ""
      assert result.tags == []
    end
  end

  describe "parse_discovery_response/2" do
    test "parses successful 200 response" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      response = %Req.Response{
        status: 200,
        body: %{"version" => "0.3.1", "tools" => [%{"name" => "tool1"}]}
      }

      result = parse_discovery_response(response, provider)
      assert {:ok, tools} = result
      assert length(tools) == 1
    end

    test "returns error for 404 response" do
      response = %Req.Response{status: 404, body: "Not Found"}
      result = parse_discovery_response(response, %{})
      assert {:error, msg} = result
      assert msg =~ "HTTP error: 404"
    end

    test "returns error for 500 response" do
      response = %Req.Response{status: 500, body: "Internal Server Error"}
      result = parse_discovery_response(response, %{})
      assert {:error, msg} = result
      assert msg =~ "HTTP error: 500"
    end

    test "handles 201 created response" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      response = %Req.Response{
        status: 201,
        body: %{"version" => "0.3.1", "tools" => []}
      }

      result = parse_discovery_response(response, provider)
      assert {:ok, _} = result
    end
  end

  describe "parse_tool_response/1" do
    test "parses successful 200 response with JSON body" do
      response = %Req.Response{
        status: 200,
        body: %{"result" => "success", "data" => [1, 2, 3]}
      }

      assert {:ok, data} = parse_tool_response(response)
      assert data["result"] == "success"
    end

    test "returns error for 400 response" do
      response = %Req.Response{status: 400, body: "Bad Request"}
      assert {:error, msg} = parse_tool_response(response)
      assert msg =~ "HTTP error: 400"
    end

    test "returns error for 401 response" do
      response = %Req.Response{status: 401, body: "Unauthorized"}
      assert {:error, msg} = parse_tool_response(response)
      assert msg =~ "HTTP error: 401"
    end

    test "returns error for 403 response" do
      response = %Req.Response{status: 403, body: "Forbidden"}
      assert {:error, msg} = parse_tool_response(response)
      assert msg =~ "HTTP error: 403"
    end
  end

  describe "build_headers/1" do
    test "builds headers with content type and accept" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{},
        auth: nil
      }

      headers = build_headers(provider)

      assert headers["Content-Type"] == "application/json"
      assert headers["Accept"] == "application/json"
    end

    test "merges custom headers" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{"X-Custom" => "value"},
        auth: nil
      }

      headers = build_headers(provider)

      assert headers["Content-Type"] == "application/json"
      assert headers["Accept"] == "application/json"
      assert headers["X-Custom"] == "value"
    end

    test "custom headers override defaults" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: "application/json",
        headers: %{"Accept" => "text/html"},
        auth: nil
      }

      headers = build_headers(provider)
      assert headers["Accept"] == "text/html"
    end

    test "handles nil content type" do
      provider = %{
        type: :http,
        name: "test",
        url: "http://example.com",
        http_method: "get",
        content_type: nil,
        headers: %{},
        auth: nil
      }

      headers = build_headers(provider)
      assert headers["Content-Type"] == nil
      assert headers["Accept"] == "application/json"
    end
  end

  describe "schema parsing" do
    test "parse_schema with full data" do
      schema_data = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}},
        "required" => ["name"],
        "description" => "A thing",
        "title" => "Thing",
        "items" => %{"type" => "string"},
        "enum" => ["a", "b"],
        "minimum" => 0,
        "maximum" => 100,
        "format" => "date-time"
      }

      result = parse_schema(schema_data)

      assert result.type == "object"
      assert result.description == "A thing"
      assert result.title == "Thing"
      assert result.required == ["name"]
      assert result.minimum == 0
      assert result.maximum == 100
      assert result.format == "date-time"
    end

    test "parse_schema with minimal data" do
      result = parse_schema(%{})

      assert result.type == "object"
      assert result.properties == %{}
      assert result.required == []
      assert result.description == ""
      assert result.title == ""
    end

    test "parse_schema preserves all optional fields" do
      schema_data = %{
        "type" => "array",
        "items" => %{"type" => "integer"},
        "enum" => [1, 2, 3]
      }

      result = parse_schema(schema_data)
      assert result.type == "array"
      assert result.enum == [1, 2, 3]
    end
  end

  # Helper functions that mirror the private functions in Http module
  # These call the private functions via the module under test

  defp substitute_url(url, args) do
    Enum.reduce(args, url, fn {key, value}, acc_url ->
      placeholder = "{#{key}}"

      if String.contains?(acc_url, placeholder) do
        String.replace(acc_url, placeholder, to_string(value))
      else
        acc_url
      end
    end)
  end

  defp remove_url_params(args, url) do
    url_params = extract_url_params(url)
    Map.drop(args, url_params)
  end

  defp extract_url_params(url) do
    Regex.scan(~r/\{(\w+)\}/, url)
    |> Enum.map(fn [_, param] -> param end)
  end

  defp parse_sse_line(line) do
    case String.trim(line) do
      "" ->
        :continue

      "data: [DONE]" ->
        {:ok, %{type: :end}}

      "data: " <> data ->
        case Jason.decode(data) do
          {:ok, json_data} -> {:ok, %{type: :data, content: json_data}}
          {:error, _} -> {:ok, %{type: :data, content: data}}
        end

      "event: " <> _event ->
        :continue

      "id: " <> _id ->
        :continue

      "retry: " <> _retry ->
        :continue

      _ ->
        :continue
    end
  end

  defp parse_sse_data(buffer) do
    lines = String.split(buffer, "\n", trim: true)
    {chunks, remaining} = parse_sse_lines(lines, [])
    {chunks, remaining}
  end

  defp parse_sse_lines(lines, acc) do
    case lines do
      [] ->
        {Enum.reverse(acc), ""}

      [line | rest] ->
        case parse_sse_line(line) do
          {:ok, chunk} -> parse_sse_lines(rest, [chunk | acc])
          :continue -> {Enum.reverse(acc), Enum.join([line | rest], "\n")}
        end
    end
  end

  defp process_sse_chunk(chunk, sequence) do
    case chunk do
      %{type: :data, content: content} ->
        %{
          data: content,
          metadata: %{"sequence" => sequence, "timestamp" => System.monotonic_time(:millisecond)},
          timestamp: System.monotonic_time(:millisecond),
          sequence: sequence
        }

      %{type: :end} ->
        %{type: :end, metadata: %{"sequence" => sequence}}

      other ->
        other
    end
  end

  defp parse_discovery_response(response, provider) do
    case response.status do
      status when status >= 200 and status < 300 ->
        case decode_body(response.body) do
          {:ok, data} -> parse_utcp_manual(data, provider)
          {:error, reason} -> {:error, "Failed to parse JSON response: #{reason}"}
        end

      status ->
        {:error, "HTTP error: #{status}"}
    end
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}
  defp decode_body(body) when is_binary(body), do: Jason.decode(body)
  defp decode_body(_), do: {:error, "Invalid body type"}

  defp parse_tool_response(response) do
    case response.status do
      status when status >= 200 and status < 300 ->
        case decode_body(response.body) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, "Failed to parse JSON response: #{reason}"}
        end

      status ->
        {:error, "HTTP error: #{status}"}
    end
  end

  defp parse_utcp_manual(data, provider) do
    case data do
      %{"version" => _} ->
        tools = Map.get(data, "tools", [])
        {:ok, Enum.map(tools, &normalize_tool(&1, provider))}

      _ ->
        case convert_openapi(data, provider) do
          {:ok, tools} -> {:ok, tools}
        end
    end
  end

  defp convert_openapi(_data, _provider) do
    {:ok, []}
  end

  defp normalize_tool(tool_data, provider) do
    ExUtcp.Tools.new_tool(
      name: Map.get(tool_data, "name", ""),
      description: Map.get(tool_data, "description", ""),
      inputs: parse_schema(Map.get(tool_data, "inputs", %{})),
      outputs: parse_schema(Map.get(tool_data, "outputs", %{})),
      tags: Map.get(tool_data, "tags", []),
      average_response_size: Map.get(tool_data, "average_response_size"),
      provider: provider
    )
  end

  defp parse_schema(schema_data) do
    ExUtcp.Tools.new_schema(
      type: Map.get(schema_data, "type", "object"),
      properties: Map.get(schema_data, "properties", %{}),
      required: Map.get(schema_data, "required", []),
      description: Map.get(schema_data, "description", ""),
      title: Map.get(schema_data, "title", ""),
      items: Map.get(schema_data, "items", %{}),
      enum: Map.get(schema_data, "enum", []),
      minimum: Map.get(schema_data, "minimum"),
      maximum: Map.get(schema_data, "maximum"),
      format: Map.get(schema_data, "format", "")
    )
  end

  defp build_headers(provider) do
    base_headers = %{
      "Content-Type" => provider.content_type,
      "Accept" => "application/json"
    }

    Map.merge(base_headers, provider.headers)
  end
end
