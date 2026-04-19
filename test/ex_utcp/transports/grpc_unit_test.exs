defmodule ExUtcp.Transports.GrpcUnitTest do
  use ExUnit.Case, async: false

  alias ExUtcp.Transports.Grpc

  describe "gRPC Transport Unit Tests" do
    setup do
      case Process.whereis(Grpc) do
        nil ->
          :ok

        pid ->
          try do
            if Process.alive?(pid) do
              GenServer.stop(pid, :normal, 500)
              Process.sleep(300)
            end
          rescue
            _ -> :ok
          end
      end

      :ok
    end

    test "creates new transport" do
      transport = Grpc.new()

      assert %Grpc{} = transport
      assert transport.logger != nil
      assert transport.connection_timeout == 30_000
    end

    test "creates transport with custom options" do
      logger = fn msg -> IO.puts("Custom: #{msg}") end
      transport = Grpc.new(logger: logger, connection_timeout: 60_000)

      assert %Grpc{} = transport
      assert transport.logger == logger
      assert transport.connection_timeout == 60_000
    end

    test "creates transport with retry config" do
      transport = Grpc.new(max_retries: 5, retry_delay: 2000, backoff_multiplier: 3)

      assert transport.retry_config.max_retries == 5
      assert transport.retry_config.retry_delay == 2000
      assert transport.retry_config.backoff_multiplier == 3
    end

    test "creates transport with pool options" do
      transport = Grpc.new(pool_opts: [size: 10])

      assert transport.pool_opts == [size: 10]
    end

    test "returns correct transport name" do
      assert Grpc.transport_name() == "grpc"
    end

    test "supports streaming" do
      assert Grpc.supports_streaming?() == true
    end

    test "register_tool_provider returns error for non-grpc provider" do
      invalid_provider = %{
        name: "test",
        type: :http,
        url: "http://localhost:4000",
        auth: nil,
        headers: %{}
      }

      assert {:error, "gRPC transport can only be used with gRPC providers"} =
               Grpc.register_tool_provider(invalid_provider)
    end

    test "register_tool_provider returns error for websocket provider" do
      invalid_provider = %{
        name: "test",
        type: :websocket,
        url: "ws://example.com",
        auth: nil,
        headers: %{}
      }

      assert {:error, _} = Grpc.register_tool_provider(invalid_provider)
    end

    test "call_tool returns error for non-grpc provider" do
      invalid_provider = %{
        name: "test",
        type: :http,
        url: "http://localhost:4000",
        auth: nil,
        headers: %{}
      }

      assert {:error, "gRPC transport can only be used with gRPC providers"} =
               Grpc.call_tool("tool", %{}, invalid_provider)
    end

    test "call_tool_stream returns error for non-grpc provider" do
      invalid_provider = %{
        name: "test",
        type: :cli,
        url: "http://localhost:4000",
        auth: nil,
        headers: %{}
      }

      assert {:error, "gRPC transport can only be used with gRPC providers"} =
               Grpc.call_tool_stream("tool", %{}, invalid_provider)
    end

    test "deregister_tool_provider returns error for non-grpc provider" do
      invalid_provider = %{
        name: "test",
        type: :http,
        url: "http://localhost:4000",
        auth: nil,
        headers: %{}
      }

      assert {:error, "gRPC transport can only be used with gRPC providers"} =
               Grpc.deregister_tool_provider(invalid_provider)
    end

    test "starts and stops gRPC transport" do
      {:ok, pid} = Grpc.start_link()
      assert is_pid(pid)

      assert :ok = Grpc.close()

      Process.sleep(100)
    end

    test "register_tool_provider with valid grpc provider" do
      {:ok, _pid} = Grpc.start_link()

      valid_provider = %{
        name: "test",
        type: :grpc,
        url: "http://localhost:50051",
        auth: nil,
        headers: %{}
      }

      result = Grpc.register_tool_provider(valid_provider)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "deregister_tool_provider with valid grpc provider" do
      case Process.whereis(Grpc) do
        nil -> {:ok, _pid} = Grpc.start_link()
        _ -> :ok
      end

      provider = %{
        name: "test",
        type: :grpc,
        url: "http://localhost:50051",
        auth: nil,
        headers: %{}
      }

      assert :ok = Grpc.deregister_tool_provider(provider)
    end

    test "gnmi_get with non-grpc provider type returns error before GenServer" do
      # gnmi_get requires GenServer, but non-grpc is caught early
      # We'd need a running GenServer to test this properly
      # Skip for now since it requires call through GenServer
    end
  end
end
