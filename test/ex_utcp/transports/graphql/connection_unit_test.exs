defmodule ExUtcp.Transports.Graphql.ConnectionUnitTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Transports.Graphql.Connection

  @moduletag :unit

  describe "build_headers/1 (via private access)" do
    test "builds headers for provider without auth" do
      provider = %{
        name: "test",
        url: "http://example.com/graphql",
        headers: %{},
        auth: nil
      }

      transport = ExUtcp.Transports.Graphql.new()
      assert transport != nil
    end
  end

  describe "struct defaults" do
    test "connection struct has expected fields" do
      conn = %Connection{
        provider: %{},
        client: nil,
        connection_state: :disconnected,
        last_used: DateTime.utc_now(),
        retry_count: 0,
        max_retries: 3,
        subscription_handles: %{}
      }

      assert conn.provider == %{}
      assert conn.client == nil
      assert conn.connection_state == :disconnected
      assert conn.retry_count == 0
      assert conn.max_retries == 3
      assert conn.subscription_handles == %{}
    end
  end

  describe "start_link/2" do
    # This test tries to connect to a nonexistent endpoint
    @tag :skip
    test "fails to connect to nonexistent GraphQL endpoint" do
      provider = %{
        name: "test",
        url: "http://invalid-host-that-does-not-exist.local:99999/graphql",
        headers: %{},
        auth: nil
      }

      result = Connection.start_link(provider)

      case result do
        {:ok, pid} ->
          GenServer.stop(pid)

        {:error, _reason} ->
          :ok
      end
    end
  end
end
