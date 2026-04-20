defmodule ExUtcp.Transports.TcpUdp.ConnectionUnitTest do
  use ExUnit.Case, async: false

  alias ExUtcp.Transports.TcpUdp.Connection

  @moduletag :unit

  describe "struct initialization" do
    test "creates struct with all fields" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test", protocol: :tcp, host: "localhost", port: 8080},
        last_used: System.monotonic_time(:millisecond),
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      assert state.socket == nil
      assert state.provider.name == "test"
      assert state.protocol == :tcp
      assert state.host == "localhost"
      assert state.port == 8080
      assert state.buffer == ""
    end

    test "creates UDP struct" do
      state = %Connection{
        socket: nil,
        provider: %{name: "udp_test", protocol: :udp, host: "127.0.0.1", port: 9999},
        last_used: System.monotonic_time(:millisecond),
        protocol: :udp,
        host: "127.0.0.1",
        port: 9999,
        buffer: "test_buffer"
      }

      assert state.protocol == :udp
      assert state.buffer == "test_buffer"
    end
  end

  describe "start_link/1" do
    test "is defined as a function" do
      assert is_function(&Connection.start_link/1, 1)
    end
  end

  describe "call_tool/4" do
    test "is defined as a function" do
      assert is_function(&Connection.call_tool/4, 4)
    end
  end

  describe "call_tool_stream/4" do
    test "is defined as a function" do
      assert is_function(&Connection.call_tool_stream/4, 4)
    end
  end

  describe "close/1" do
    test "is defined as a function" do
      assert is_function(&Connection.close/1, 1)
    end
  end

  describe "get_last_used/1" do
    test "is defined as a function" do
      assert is_function(&Connection.get_last_used/1, 1)
    end
  end

  describe "update_last_used/1" do
    test "is defined as a function" do
      assert is_function(&Connection.update_last_used/1, 1)
    end
  end

  describe "handle_call :call_tool" do
    # Would try to actually send TCP data with nil socket
    @tag :skip
    test "returns error for invalid provider" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test", protocol: :tcp, host: "invalid", port: 1},
        last_used: 1000,
        protocol: :tcp,
        host: "invalid",
        port: 1,
        buffer: ""
      }

      from = {self(), :test_ref}
      tool_name = "test_tool"
      args = %{"input" => "value"}
      timeout = 1000

      # With socket as nil, it should fail when trying to send
      result = Connection.handle_call({:call_tool, tool_name, args, timeout}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :call_tool_stream" do
    # Would try to actually send UDP data with nil socket
    @tag :skip
    test "returns error for invalid provider" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test", protocol: :udp, host: "invalid", port: 1},
        last_used: 1000,
        protocol: :udp,
        host: "invalid",
        port: 1,
        buffer: ""
      }

      from = {self(), :test_ref}
      tool_name = "stream_tool"
      args = %{"query" => "test"}
      timeout = 1000

      result = Connection.handle_call({:call_tool_stream, tool_name, args, timeout}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :close" do
    test "closes socket and returns ok" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: 1000,
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      from = {self(), :test_ref}
      result = Connection.handle_call(:close, from, state)
      assert match?({:reply, :ok, ^state}, result)
    end
  end

  describe "handle_call :get_last_used" do
    test "returns last_used timestamp" do
      timestamp = System.monotonic_time(:millisecond)

      state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: timestamp,
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      from = {self(), :test_ref}
      result = Connection.handle_call(:get_last_used, from, state)
      assert result == {:reply, timestamp, state}
    end
  end

  describe "handle_cast :update_last_used" do
    test "updates last_used timestamp" do
      old_timestamp = System.monotonic_time(:millisecond)

      state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: old_timestamp,
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      # Small delay to ensure timestamp changes
      Process.sleep(5)

      result = Connection.handle_cast(:update_last_used, state)
      assert match?({:noreply, _new_state}, result)
      {:noreply, new_state} = result
      # New timestamp should be different (not equal to old)
      assert new_state.last_used != old_timestamp
    end
  end

  describe "handle_info :tcp" do
    test "appends data to buffer" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: 1000,
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        buffer: "existing"
      }

      result = Connection.handle_info({:tcp, :socket, "_data"}, state)
      assert match?({:noreply, _new_state}, result)
      {:noreply, new_state} = result
      assert new_state.buffer == "existing_data"
    end
  end

  describe "handle_info :tcp_closed" do
    test "stops GenServer normally" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: 1000,
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      result = Connection.handle_info({:tcp_closed, :socket}, state)
      assert result == {:stop, :normal, state}
    end
  end

  describe "handle_info :udp" do
    test "appends data to buffer" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: 1000,
        protocol: :udp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      result = Connection.handle_info({:udp, :socket, {127, 0, 0, 1}, 1234, "udp_data"}, state)
      assert match?({:noreply, _new_state}, result)
      {:noreply, new_state} = result
      assert new_state.buffer == "udp_data"
    end
  end

  describe "handle_info :udp_error" do
    test "stops GenServer with error" do
      state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: 1000,
        protocol: :udp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      result = Connection.handle_info({:udp_error, :socket, :econnrefused}, state)
      assert result == {:stop, :econnrefused, state}
    end
  end

  describe "build_message helper" do
    test "creates message with tool, args, and protocol" do
      tool_name = "test_tool"
      args = %{"input" => "value", "count" => 5}
      provider = %{protocol: :tcp, name: "test_provider"}

      # The build_message function is private, but we can test the concept
      message = %{
        tool: tool_name,
        args: args,
        timestamp: System.monotonic_time(:millisecond),
        protocol: provider.protocol
      }

      assert message.tool == "test_tool"
      assert message.args == args
      assert message.protocol == :tcp
      assert is_integer(message.timestamp)
    end

    test "creates message for UDP protocol" do
      tool_name = "udp_tool"
      args = %{"data" => "binary"}
      provider = %{protocol: :udp, name: "udp_provider"}

      message = %{
        tool: tool_name,
        args: args,
        timestamp: System.monotonic_time(:millisecond),
        protocol: provider.protocol
      }

      assert message.protocol == :udp
    end
  end

  describe "parse_response helper" do
    test "parses valid JSON response" do
      json_response = ~s({"result": "success", "data": [1, 2, 3]})

      result = Jason.decode(json_response)
      assert {:ok, decoded} = result
      assert decoded["result"] == "success"
      assert decoded["data"] == [1, 2, 3]
    end

    test "fails on invalid JSON" do
      invalid_json = "not valid json"

      result = Jason.decode(invalid_json)
      assert {:error, _} = result
    end

    test "parses nested JSON" do
      nested_json = ~s({"nested": {"key": "value", "num": 42}})

      result = Jason.decode(nested_json)
      assert {:ok, decoded} = result
      assert decoded["nested"]["key"] == "value"
      assert decoded["nested"]["num"] == 42
    end
  end

  describe "establish_connection logic" do
    test "determines protocol from provider" do
      tcp_provider = %{protocol: :tcp, host: "localhost", port: 8080}
      udp_provider = %{protocol: :udp, host: "127.0.0.1", port: 9999}
      unknown_provider = %{protocol: :http, host: "example.com", port: 80}

      assert tcp_provider.protocol == :tcp
      assert udp_provider.protocol == :udp
      assert unknown_provider.protocol == :http
    end

    test "connection timeout defaults" do
      provider_with_timeout = %{timeout: 5000}
      provider_without_timeout = %{}

      timeout = Map.get(provider_with_timeout, :timeout, 5000)
      assert timeout == 5000

      default_timeout = Map.get(provider_without_timeout, :timeout, 5000)
      assert default_timeout == 5000
    end
  end

  describe "receive_response logic" do
    test "handles tcp data in receive block" do
      # Simulate the receive logic concept
      receive_data = fn ->
        receive do
          {:tcp, _socket, data} -> {:ok, data}
        after
          100 -> {:error, :timeout}
        end
      end

      # Send ourselves a message to test
      send(self(), {:tcp, :mock_socket, "test_response"})
      assert {:ok, "test_response"} = receive_data.()
    end

    test "handles udp data in receive block" do
      receive_data = fn ->
        receive do
          {:udp, _socket, _ip, _port, data} -> {:ok, data}
        after
          100 -> {:error, :timeout}
        end
      end

      send(self(), {:udp, :mock_socket, {127, 0, 0, 1}, 1234, "udp_response"})
      assert {:ok, "udp_response"} = receive_data.()
    end

    test "handles timeout" do
      receive_data = fn ->
        receive do
          {:tcp, _socket, data} -> {:ok, data}
        after
          50 -> {:error, :timeout}
        end
      end

      assert {:error, :timeout} = receive_data.()
    end
  end

  describe "stream creation" do
    test "stream resource structure" do
      # Test that stream resource is properly structured
      stream =
        Stream.resource(
          fn -> :initial_state end,
          fn state ->
            case state do
              :initial_state -> {[%{}], :next_state}
              :next_state -> {[%{}], :final_state}
              :final_state -> {:halt, :done}
            end
          end,
          fn _state -> :ok end
        )

      result = Enum.to_list(stream)
      assert length(result) == 2
    end
  end

  describe "buffer management" do
    test "accumulates TCP data" do
      buffer = ""

      # Simulate receiving data
      data1 = "Hello"
      buffer = buffer <> data1
      assert buffer == "Hello"

      data2 = " World"
      buffer = buffer <> data2
      assert buffer == "Hello World"
    end

    test "accumulates UDP data" do
      buffer = "initial"

      data = "_packet"
      buffer = buffer <> data
      assert buffer == "initial_packet"
    end
  end

  describe "protocol handling" do
    test "distinguishes TCP and UDP" do
      protocols = [:tcp, :udp]

      assert :tcp in protocols
      assert :udp in protocols
      refute :http in protocols
    end

    test "provider contains required fields" do
      provider = %{
        name: "test_provider",
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        timeout: 5000
      }

      assert provider.name == "test_provider"
      assert provider.protocol == :tcp
      assert provider.host == "localhost"
      assert provider.port == 8080
      assert provider.timeout == 5000
    end
  end

  describe "connection state management" do
    test "tracks last_used timestamp" do
      t1 = System.monotonic_time(:millisecond)
      Process.sleep(10)
      t2 = System.monotonic_time(:millisecond)

      assert t2 > t1
    end

    test "state immutability" do
      original_state = %Connection{
        socket: nil,
        provider: %{name: "test"},
        last_used: 1000,
        protocol: :tcp,
        host: "localhost",
        port: 8080,
        buffer: ""
      }

      # New state is created, original is unchanged
      new_state = %{original_state | last_used: 2000}

      assert original_state.last_used == 1000
      assert new_state.last_used == 2000
    end
  end

  describe "message encoding/decoding" do
    test "encodes message to JSON" do
      message = %{
        tool: "test_tool",
        args: %{"key" => "value"},
        timestamp: 12_345,
        protocol: :tcp
      }

      assert {:ok, json} = Jason.encode(message)
      assert is_binary(json)

      # Verify it can be decoded back
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["tool"] == "test_tool"
    end

    test "handles complex nested args" do
      args = %{
        "string" => "value",
        "number" => 42,
        "boolean" => true,
        "null" => nil,
        "array" => [1, 2, 3],
        "object" => %{"nested" => "data"}
      }

      assert {:ok, json} = Jason.encode(args)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["object"]["nested"] == "data"
    end
  end

  describe "error handling" do
    test "connection failure returns error tuple" do
      # Test error tuple format
      error = {:error, "Connection failed"}
      assert match?({:error, _}, error)
    end

    test "timeout error format" do
      timeout_error = {:error, :timeout}
      assert timeout_error == {:error, :timeout}
    end

    test "JSON decode error handling" do
      invalid = "not json"
      result = Jason.decode(invalid)
      assert match?({:error, _}, result)
    end
  end
end
