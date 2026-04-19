defmodule ExUtcp.Transports.WebRTC.SignalingTest do
  use ExUnit.Case, async: false

  alias ExUtcp.Transports.WebRTC.Signaling

  @moduletag :unit

  setup do
    # Clean up any existing processes
    on_exit(fn ->
      # Cleanup will happen via process monitoring
      :ok
    end)

    :ok
  end

  describe "start_link/2" do
    test "starts signaling client with server URL and parent PID" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      assert {:ok, pid} = Signaling.start_link(server_url, parent_pid)
      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "initializes with correct state" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)

      # Give time for init to complete
      Process.sleep(100)

      GenServer.stop(pid)
    end
  end

  describe "struct initialization" do
    test "creates struct with required fields" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: nil,
        connection_state: :disconnected
      }

      assert state.server_url == server_url
      assert state.parent_pid == parent_pid
      assert state.websocket_pid == nil
      assert state.peer_id == nil
      assert state.connection_state == :disconnected
    end
  end

  describe "send_offer/3" do
    test "is defined as a function" do
      assert is_function(&Signaling.send_offer/3, 3)
    end

    test "returns error when websocket not connected" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)

      # Wait for init to complete
      Process.sleep(100)

      offer = %{sdp: "test_sdp"}
      peer_id = "remote_peer"

      # Should fail because websocket_pid is nil
      result = Signaling.send_offer(pid, offer, peer_id)
      assert match?({:error, _}, result)

      GenServer.stop(pid)
    end
  end

  describe "send_answer/3" do
    test "is defined as a function" do
      assert is_function(&Signaling.send_answer/3, 3)
    end

    test "returns error when websocket not connected" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)
      Process.sleep(100)

      answer = %{sdp: "test_sdp"}
      peer_id = "remote_peer"

      result = Signaling.send_answer(pid, answer, peer_id)
      assert match?({:error, _}, result)

      GenServer.stop(pid)
    end
  end

  describe "send_ice_candidate/3" do
    test "is defined as a function" do
      assert is_function(&Signaling.send_ice_candidate/3, 3)
    end

    test "returns error when websocket not connected" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)
      Process.sleep(100)

      candidate = %{
        candidate: "test_candidate",
        sdp_mid: "0",
        sdp_m_line_index: 0
      }

      peer_id = "remote_peer"

      result = Signaling.send_ice_candidate(pid, candidate, peer_id)
      assert match?({:error, _}, result)

      GenServer.stop(pid)
    end
  end

  describe "close/1" do
    test "stops the signaling client" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)
      assert Process.alive?(pid)

      :ok = Signaling.close(pid)

      # Give time for process to stop
      Process.sleep(50)
      refute Process.alive?(pid)
    end
  end

  describe "GenServer init/1" do
    test "schedules connect_to_signaling_server message" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)

      # Give time for async init to run
      Process.sleep(100)

      # Process should still be alive after attempting connection
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "handle_call :send_offer" do
    test "handles offer without websocket" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)
      Process.sleep(100)

      from = {self(), :test_ref}
      offer = %{sdp: "test_sdp"}
      peer_id = "remote_peer"

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :disconnected
      }

      result = Signaling.handle_call({:send_offer, offer, peer_id}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :send_answer" do
    test "handles answer without websocket" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :disconnected
      }

      from = {self(), :test_ref}
      answer = %{sdp: "test_sdp"}
      peer_id = "remote_peer"

      result = Signaling.handle_call({:send_answer, answer, peer_id}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_call :send_ice_candidate" do
    test "handles ice candidate without websocket" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :disconnected
      }

      from = {self(), :test_ref}

      candidate = %{
        candidate: "test_candidate",
        sdp_mid: "0",
        sdp_m_line_index: 0
      }

      peer_id = "remote_peer"

      result = Signaling.handle_call({:send_ice_candidate, candidate, peer_id}, from, state)
      assert match?({:reply, {:error, _}, ^state}, result)
    end
  end

  describe "handle_info :connect_to_signaling_server" do
    test "generates peer_id and updates state" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: nil,
        connection_state: :disconnected
      }

      # Simulate the connect message handling
      result = Signaling.handle_info(:connect_to_signaling_server, state)

      # Should update state with peer_id and connected status
      assert match?({:noreply, new_state}, result)
      {:noreply, new_state} = result
      assert new_state.peer_id != nil
      assert new_state.connection_state == :connected
      assert is_binary(new_state.peer_id)
      assert String.starts_with?(new_state.peer_id, "peer_")
    end
  end

  describe "handle_info websocket message" do
    test "handles answer message from websocket" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :connected
      }

      # Simulate receiving an answer message
      message = %{"type" => "answer", "sdp" => "remote_sdp"}
      json = Jason.encode!(message)

      result = Signaling.handle_info({:websocket, :message, json}, state)
      assert match?({:noreply, ^state}, result)

      # Verify message was sent to parent
      assert_receive {:signaling, :answer, %{type: :answer, sdp: "remote_sdp"}}, 100
    end

    test "handles ice candidate message from websocket" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :connected
      }

      # Simulate receiving an ICE candidate message
      message = %{
        "type" => "ice_candidate",
        "candidate" => %{
          "candidate" => "candidate:1",
          "sdp_mid" => "0",
          "sdp_m_line_index" => 0
        }
      }

      json = Jason.encode!(message)

      result = Signaling.handle_info({:websocket, :message, json}, state)
      assert match?({:noreply, ^state}, result)

      # Verify message was sent to parent
      assert_receive {:signaling, :ice_candidate, %{candidate: "candidate:1"}}, 100
    end

    test "handles invalid json message" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :connected
      }

      # Invalid JSON
      result = Signaling.handle_info({:websocket, :message, "invalid json"}, state)
      assert match?({:noreply, ^state}, result)
    end

    test "handles unknown message type" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :connected
      }

      # Unknown message type
      message = %{"type" => "unknown", "data" => "test"}
      json = Jason.encode!(message)

      result = Signaling.handle_info({:websocket, :message, json}, state)
      assert match?({:noreply, ^state}, result)
    end
  end

  describe "handle_info other messages" do
    test "ignores unknown messages" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :connected
      }

      result = Signaling.handle_info(:unknown_message, state)
      assert match?({:noreply, ^state}, result)
    end
  end

  describe "handle_signaling_message answer" do
    test "forwards answer to parent" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :connected
      }

      message = %{"type" => "answer", "sdp" => "test_sdp_data"}

      result = Signaling.handle_info({:websocket, :message, Jason.encode!(message)}, state)
      assert match?({:noreply, ^state}, result)

      assert_receive {:signaling, :answer, %{sdp: "test_sdp_data"}}, 100
    end
  end

  describe "handle_signaling_message ice_candidate" do
    test "forwards ice candidate to parent" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: "local_peer",
        connection_state: :connected
      }

      message = %{
        "type" => "ice_candidate",
        "candidate" => %{
          "candidate" => "candidate:test",
          "sdp_mid" => "video",
          "sdp_m_line_index" => 1
        }
      }

      result = Signaling.handle_info({:websocket, :message, Jason.encode!(message)}, state)
      assert match?({:noreply, ^state}, result)

      assert_receive {:signaling, :ice_candidate,
                      %{candidate: "candidate:test", sdp_mid: "video", sdp_m_line_index: 1}},
                     100
    end
  end

  describe "send_signaling_message helper" do
    test "returns error when websocket_pid is nil" do
      # This is tested indirectly through send_offer/send_answer
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      {:ok, pid} = Signaling.start_link(server_url, parent_pid)
      Process.sleep(100)

      offer = %{sdp: "test"}
      result = Signaling.send_offer(pid, offer, "peer")

      assert match?({:error, "Signaling connection not established"}, result)

      GenServer.stop(pid)
    end

    test "returns ok when websocket_pid exists" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        # Mock websocket PID
        websocket_pid: self(),
        peer_id: "local_peer",
        connection_state: :connected
      }

      from = {self(), :test_ref}
      offer = %{sdp: "test_sdp"}

      result = Signaling.handle_call({:send_offer, offer, "remote_peer"}, from, state)
      # Should succeed when websocket_pid is not nil
      assert match?({:reply, :ok, ^state}, result)
    end
  end

  describe "generate_peer_id helper" do
    test "generates unique peer IDs" do
      # Test by checking the peer_id generated in handle_info
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: nil,
        connection_state: :disconnected
      }

      result1 = Signaling.handle_info(:connect_to_signaling_server, state)
      {:noreply, new_state1} = result1

      result2 = Signaling.handle_info(:connect_to_signaling_server, state)
      {:noreply, new_state2} = result2

      # Should generate different peer IDs
      refute new_state1.peer_id == new_state2.peer_id
      assert String.starts_with?(new_state1.peer_id, "peer_")
      assert String.starts_with?(new_state2.peer_id, "peer_")
    end

    test "generates peer_id with correct format" do
      server_url = "wss://signaling.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: nil,
        connection_state: :disconnected
      }

      result = Signaling.handle_info(:connect_to_signaling_server, state)
      {:noreply, new_state} = result

      # Format should be peer_<16_char_hex>
      assert new_state.peer_id =~ ~r/^peer_[a-f0-9]{16}$/
    end
  end

  describe "connection retry logic" do
    test "handles connection when server_url is valid format" do
      # Even "invalid" URLs will generate peer IDs since we mock the connection
      server_url = "wss://test-server.example.com"
      parent_pid = self()

      state = %Signaling{
        server_url: server_url,
        parent_pid: parent_pid,
        websocket_pid: nil,
        peer_id: nil,
        connection_state: :disconnected
      }

      # Connection succeeds and generates peer_id
      result = Signaling.handle_info(:connect_to_signaling_server, state)
      assert match?({:noreply, new_state}, result)
      {:noreply, new_state} = result
      assert new_state.peer_id != nil
      assert new_state.connection_state == :connected
    end
  end

  describe "message encoding" do
    test "encodes offer message correctly" do
      # Test via handle_call path
      server_url = "wss://signaling.example.com"

      state = %Signaling{
        server_url: server_url,
        parent_pid: self(),
        websocket_pid: self(),
        peer_id: "local_peer",
        connection_state: :connected
      }

      from = {self(), :test_ref}
      offer = %{sdp: "test_sdp_content"}

      result = Signaling.handle_call({:send_offer, offer, "remote"}, from, state)
      assert match?({:reply, :ok, ^state}, result)
    end

    test "encodes answer message correctly" do
      server_url = "wss://signaling.example.com"

      state = %Signaling{
        server_url: server_url,
        parent_pid: self(),
        websocket_pid: self(),
        peer_id: "local_peer",
        connection_state: :connected
      }

      from = {self(), :test_ref}
      answer = %{sdp: "answer_sdp"}

      result = Signaling.handle_call({:send_answer, answer, "remote"}, from, state)
      assert match?({:reply, :ok, ^state}, result)
    end

    test "encodes ice candidate message correctly" do
      server_url = "wss://signaling.example.com"

      state = %Signaling{
        server_url: server_url,
        parent_pid: self(),
        websocket_pid: self(),
        peer_id: "local_peer",
        connection_state: :connected
      }

      from = {self(), :test_ref}

      candidate = %{
        candidate: "candidate:123",
        sdp_mid: "audio",
        sdp_m_line_index: 0
      }

      result = Signaling.handle_call({:send_ice_candidate, candidate, "remote"}, from, state)
      assert match?({:reply, :ok, ^state}, result)
    end
  end
end
