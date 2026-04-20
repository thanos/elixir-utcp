defmodule ExUtcp.Transports.WebRTC.MoxTest do
  use ExUnit.Case, async: false

  import Mox

  alias ExUtcp.Providers
  alias ExUtcp.Transports.WebRTC.ConnectionMock
  alias ExUtcp.Transports.WebRTC.Testable

  @moduletag :unit

  setup do
    # Set up mocks
    Testable.set_mocks(ConnectionMock)

    # Allow mocks to be used by the GenServer
    :ok
  end

  setup :verify_on_exit!

  describe "start_link with mock" do
    test "creates connection with mock module" do
      provider =
        Providers.new_webrtc_provider(
          name: "test_provider",
          peer_id: "peer_123"
        )

      signaling_server = "wss://signaling.example.com"
      ice_servers = [%{urls: ["stun:stun.example.com:19302"]}]

      expect(ConnectionMock, :start_link, fn ^provider, ^signaling_server, ^ice_servers ->
        {:ok, self()}
      end)

      assert {:ok, _pid} = ConnectionMock.start_link(provider, signaling_server, ice_servers)
    end

    test "handles connection error with mock" do
      provider = Providers.new_webrtc_provider(name: "test_provider")
      signaling_server = "wss://invalid.server"
      ice_servers = []

      expect(ConnectionMock, :start_link, fn _provider, _server, _ice ->
        {:error, "Connection failed"}
      end)

      assert {:error, "Connection failed"} = ConnectionMock.start_link(provider, signaling_server, ice_servers)
    end
  end

  describe "call_tool with mock" do
    test "calls tool successfully" do
      conn_pid = self()
      tool_name = "test_tool"
      args = %{"input" => "value"}
      timeout = 30_000

      expect(ConnectionMock, :call_tool, fn ^conn_pid, ^tool_name, ^args, ^timeout ->
        {:ok, %{"result" => "success"}}
      end)

      assert {:ok, %{"result" => "success"}} = ConnectionMock.call_tool(conn_pid, tool_name, args, timeout)
    end

    test "handles tool call error" do
      conn_pid = self()
      tool_name = "error_tool"
      args = %{}
      timeout = 30_000

      expect(ConnectionMock, :call_tool, fn _pid, _tool, _args, _timeout ->
        {:error, "Tool execution failed"}
      end)

      assert {:error, "Tool execution failed"} = ConnectionMock.call_tool(conn_pid, tool_name, args, timeout)
    end

    test "handles timeout" do
      conn_pid = self()
      tool_name = "slow_tool"
      args = %{}
      timeout = 5_000

      expect(ConnectionMock, :call_tool, fn _pid, _tool, _args, ^timeout ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = ConnectionMock.call_tool(conn_pid, tool_name, args, timeout)
    end
  end

  describe "call_tool_stream with mock" do
    test "creates stream successfully" do
      conn_pid = self()
      tool_name = "stream_tool"
      args = %{"query" => "test"}
      timeout = 30_000

      stream = [%{chunk: 1}, %{chunk: 2}]

      expect(ConnectionMock, :call_tool_stream, fn ^conn_pid, ^tool_name, ^args, ^timeout ->
        {:ok, stream}
      end)

      assert {:ok, ^stream} = ConnectionMock.call_tool_stream(conn_pid, tool_name, args, timeout)
    end

    test "handles stream error" do
      conn_pid = self()
      tool_name = "error_stream_tool"
      args = %{}
      timeout = 30_000

      expect(ConnectionMock, :call_tool_stream, fn _pid, _tool, _args, _timeout ->
        {:error, "Stream failed"}
      end)

      assert {:error, "Stream failed"} = ConnectionMock.call_tool_stream(conn_pid, tool_name, args, timeout)
    end
  end

  describe "close with mock" do
    test "closes connection" do
      conn_pid = self()

      expect(ConnectionMock, :close, fn ^conn_pid ->
        :ok
      end)

      assert :ok = ConnectionMock.close(conn_pid)
    end
  end

  describe "get_connection_state with mock" do
    test "returns connected state" do
      conn_pid = self()

      expect(ConnectionMock, :get_connection_state, fn ^conn_pid ->
        :connected
      end)

      assert :connected = ConnectionMock.get_connection_state(conn_pid)
    end

    test "returns connecting state" do
      conn_pid = self()

      expect(ConnectionMock, :get_connection_state, fn _pid ->
        :connecting
      end)

      assert :connecting = ConnectionMock.get_connection_state(conn_pid)
    end

    test "returns failed state" do
      conn_pid = self()

      expect(ConnectionMock, :get_connection_state, fn _pid ->
        :failed
      end)

      assert :failed = ConnectionMock.get_connection_state(conn_pid)
    end
  end

  describe "get_ice_connection_state with mock" do
    test "returns connected state" do
      conn_pid = self()

      expect(ConnectionMock, :get_ice_connection_state, fn ^conn_pid ->
        :connected
      end)

      assert :connected = ConnectionMock.get_ice_connection_state(conn_pid)
    end

    test "returns checking state" do
      conn_pid = self()

      expect(ConnectionMock, :get_ice_connection_state, fn _pid ->
        :checking
      end)

      assert :checking = ConnectionMock.get_ice_connection_state(conn_pid)
    end
  end

  describe "Testable transport with mocks" do
    test "register_tool_provider with mock connection" do
      provider =
        Providers.new_webrtc_provider(
          name: "test_provider",
          peer_id: "peer_123"
        )

      conn_pid = self()

      # Expect start_link to be called during registration
      expect(ConnectionMock, :start_link, fn _prov, _server, _ice ->
        {:ok, conn_pid}
      end)

      # Start testable transport
      transport = Testable.new(connection_module: ConnectionMock)
      {:ok, transport_pid} = Testable.start_link()

      # Allow mock to be called from GenServer
      Mox.allow(ConnectionMock, self(), transport_pid)

      # Register provider
      assert {:ok, []} = Testable.register_tool_provider(transport, provider)

      GenServer.stop(transport_pid)
    end

    test "call_tool with registered provider" do
      provider =
        Providers.new_webrtc_provider(
          name: "test_provider",
          peer_id: "peer_123"
        )

      conn_pid = self()

      # Set up expectations
      expect(ConnectionMock, :start_link, fn _prov, _server, _ice ->
        {:ok, conn_pid}
      end)

      expect(ConnectionMock, :call_tool, fn ^conn_pid, "test_tool", %{"input" => "value"}, _timeout ->
        {:ok, %{"result" => "mocked"}}
      end)

      # Start testable transport
      transport = Testable.new(connection_module: ConnectionMock)
      {:ok, transport_pid} = Testable.start_link()

      # Allow mock to be called from GenServer
      Mox.allow(ConnectionMock, self(), transport_pid)

      # Register and call tool
      assert {:ok, []} = Testable.register_tool_provider(transport, provider)

      assert {:ok, %{"result" => "mocked"}} =
               Testable.call_tool(transport, "test_tool", %{"input" => "value"}, provider)

      GenServer.stop(transport_pid)
    end

    test "deregister_tool_provider closes connection" do
      provider = Providers.new_webrtc_provider(name: "test_provider")
      conn_pid = self()

      expect(ConnectionMock, :start_link, fn _prov, _server, _ice ->
        {:ok, conn_pid}
      end)

      expect(ConnectionMock, :close, fn ^conn_pid ->
        :ok
      end)

      transport = Testable.new(connection_module: ConnectionMock)
      {:ok, transport_pid} = Testable.start_link()

      Mox.allow(ConnectionMock, self(), transport_pid)

      assert {:ok, []} = Testable.register_tool_provider(transport, provider)
      assert :ok = Testable.deregister_tool_provider(transport, provider)

      GenServer.stop(transport_pid)
    end

    test "close closes all connections" do
      provider1 = Providers.new_webrtc_provider(name: "provider1")
      provider2 = Providers.new_webrtc_provider(name: "provider2")
      conn1 = self()
      conn2 = spawn(fn -> :ok end)

      expect(ConnectionMock, :start_link, 2, fn prov, _server, _ice ->
        case prov.name do
          "provider1" -> {:ok, conn1}
          "provider2" -> {:ok, conn2}
        end
      end)

      expect(ConnectionMock, :close, 2, fn _pid ->
        :ok
      end)

      transport = Testable.new(connection_module: ConnectionMock)
      {:ok, transport_pid} = Testable.start_link()

      Mox.allow(ConnectionMock, self(), transport_pid)

      assert {:ok, []} = Testable.register_tool_provider(transport, provider1)
      assert {:ok, []} = Testable.register_tool_provider(transport, provider2)
      assert :ok = Testable.close(transport)

      GenServer.stop(transport_pid)
    end
  end

  describe "error scenarios with mocks" do
    test "handles provider not registered error" do
      provider = Providers.new_webrtc_provider(name: "unregistered_provider")

      transport = Testable.new(connection_module: ConnectionMock)
      {:ok, transport_pid} = Testable.start_link()

      # Try to call tool without registering provider
      result = Testable.call_tool(transport, "test_tool", %{}, provider)
      assert {:error, msg} = result
      assert msg =~ "Provider not registered"

      GenServer.stop(transport_pid)
    end

    test "handles connection failure during registration" do
      provider = Providers.new_webrtc_provider(name: "failing_provider")

      expect(ConnectionMock, :start_link, fn _prov, _server, _ice ->
        {:error, "Network unreachable"}
      end)

      transport = Testable.new(connection_module: ConnectionMock)
      {:ok, transport_pid} = Testable.start_link()

      Mox.allow(ConnectionMock, self(), transport_pid)

      result = Testable.register_tool_provider(transport, provider)
      assert {:error, msg} = result
      assert msg =~ "Failed to create connection"

      GenServer.stop(transport_pid)
    end
  end

  describe "streaming with mocks" do
    test "call_tool_stream creates enumerable" do
      provider =
        Providers.new_webrtc_provider(
          name: "stream_provider",
          peer_id: "peer_123"
        )

      conn_pid = self()

      stream_data = [
        %{"chunk" => 1, "data" => "part1"},
        %{"chunk" => 2, "data" => "part2"},
        %{"chunk" => 3, "data" => "part3"}
      ]

      expect(ConnectionMock, :start_link, fn _prov, _server, _ice ->
        {:ok, conn_pid}
      end)

      expect(ConnectionMock, :call_tool_stream, fn ^conn_pid, "stream_tool", %{"query" => "test"}, _timeout ->
        {:ok, stream_data}
      end)

      transport = Testable.new(connection_module: ConnectionMock)
      {:ok, transport_pid} = Testable.start_link()

      Mox.allow(ConnectionMock, self(), transport_pid)

      assert {:ok, []} = Testable.register_tool_provider(transport, provider)
      assert {:ok, ^stream_data} = Testable.call_tool_stream(transport, "stream_tool", %{"query" => "test"}, provider)

      GenServer.stop(transport_pid)
    end
  end

  describe "non-webrtc provider rejection" do
    test "rejects http provider" do
      http_provider = %{type: :http, name: "http_provider", url: "http://example.com"}

      result = Testable.register_tool_provider(%Testable{}, http_provider)
      assert {:error, msg} = result
      assert msg =~ "WebRTC transport can only be used with WebRTC providers"
    end

    test "rejects cli provider" do
      cli_provider = %{type: :cli, name: "cli_provider", command_name: "echo"}

      result = Testable.call_tool(%Testable{}, "tool", %{}, cli_provider)
      assert {:error, msg} = result
      assert msg =~ "WebRTC transport can only be used with WebRTC providers"
    end

    test "rejects grpc provider" do
      grpc_provider = %{type: :grpc, name: "grpc_provider", url: "http://example.com"}

      result = Testable.call_tool_stream(%Testable{}, "tool", %{}, grpc_provider)
      assert {:error, msg} = result
      assert msg =~ "WebRTC transport can only be used with WebRTC providers"
    end
  end
end
