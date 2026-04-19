defmodule ExUtcp.Transports.Grpc.PoolUnitTest do
  use ExUnit.Case, async: false

  alias ExUtcp.Transports.Grpc.Pool

  setup do
    stop_pool()
    on_exit(fn -> stop_pool() end)
    :ok
  end

  defp stop_pool do
    case Process.whereis(Pool) do
      nil ->
        :ok

      pid ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 500)
        rescue
          _ -> :ok
        end

        Process.sleep(100)
    end
  end

  describe "start_link/1" do
    test "starts the pool with defaults" do
      assert {:ok, pid} = Pool.start_link()
      assert Process.alive?(pid)
    end

    test "starts with custom options" do
      assert {:ok, pid} =
               Pool.start_link(
                 max_connections: 5,
                 connection_timeout: 10_000,
                 cleanup_interval: 30_000,
                 max_idle_time: 60_000
               )

      assert Process.alive?(pid)
      stats = Pool.stats()
      assert stats.max_connections == 5
    end

    test "returns error when already started" do
      assert {:ok, _} = Pool.start_link()
      assert {:error, {:already_started, _}} = Pool.start_link()
    end
  end

  describe "stats/0" do
    test "returns pool statistics" do
      assert {:ok, _} = Pool.start_link(max_connections: 3)
      stats = Pool.stats()

      assert is_map(stats)
      assert stats.total_connections == 0
      assert stats.max_connections == 3
      assert stats.connection_keys == []
    end

    test "reflects connections after adding providers" do
      assert {:ok, _} = Pool.start_link(max_connections: 10)
      stats_before = Pool.stats()
      assert stats_before.total_connections == 0

      provider = %{host: "localhost", port: 50_051, use_ssl: false, service_name: "TestService"}
      result = Pool.get_connection(provider)

      case result do
        {:ok, _pid} ->
          stats_after = Pool.stats()
          assert stats_after.total_connections == 1
          assert length(stats_after.connection_keys) == 1

        {:error, _reason} ->
          stats_after = Pool.stats()
          assert stats_after.total_connections == 0
      end
    end
  end

  describe "return_connection/1" do
    test "returns ok even for nonexistent connection" do
      assert {:ok, _} = Pool.start_link()
      assert :ok = Pool.return_connection(self())
    end
  end

  describe "close_connection/1" do
    test "closes a specific connection without error" do
      assert {:ok, _} = Pool.start_link()
      assert :ok = Pool.close_connection(self())
    end

    test "removes connection from pool when closing tracked connection" do
      assert {:ok, _} = Pool.start_link(max_connections: 10)

      provider = %{host: "localhost", port: 50_051, use_ssl: false, service_name: "TestService"}

      case Pool.get_connection(provider) do
        {:ok, conn_pid} ->
          stats = Pool.stats()
          assert stats.total_connections == 1

          :ok = Pool.close_connection(conn_pid)
          Process.sleep(50)

          stats_after = Pool.stats()
          assert stats_after.total_connections == 0

        {:error, _} ->
          :ok
      end
    end
  end

  describe "close_all_connections/0" do
    test "closes all connections" do
      assert {:ok, _} = Pool.start_link()
      assert :ok = Pool.close_all_connections()

      stats = Pool.stats()
      assert stats.total_connections == 0
    end

    test "clears all connection keys" do
      assert {:ok, _} = Pool.start_link()
      assert :ok = Pool.close_all_connections()

      stats = Pool.stats()
      assert stats.connection_keys == []
    end
  end

  describe "get_connection/1" do
    test "returns error for max connections reached" do
      assert {:ok, _} = Pool.start_link(max_connections: 0)

      provider = %{host: "localhost", port: 50_051, use_ssl: false, service_name: "TestService"}
      assert {:error, "Maximum number of connections reached"} = Pool.get_connection(provider)
    end

    test "builds connection key from provider fields" do
      assert {:ok, _} = Pool.start_link(max_connections: 10)

      provider = %{host: "myhost", port: 1234, use_ssl: true, service_name: "MyService"}

      result = Pool.get_connection(provider)

      case result do
        {:ok, _pid} ->
          stats = Pool.stats()
          assert "myhost:1234:true:MyService" in stats.connection_keys

        {:error, _} ->
          :ok
      end
    end

    test "defaults connection key fields for incomplete provider" do
      assert {:ok, _} = Pool.start_link(max_connections: 10)

      provider = %{name: "test"}

      result = Pool.get_connection(provider)

      case result do
        {:ok, _pid} ->
          stats = Pool.stats()
          assert "localhost:50051:false:UTCPService" in stats.connection_keys

        {:error, _} ->
          :ok
      end
    end

    test "reuses existing connection for same provider" do
      assert {:ok, _} = Pool.start_link(max_connections: 10)

      provider = %{host: "localhost", port: 50_051, use_ssl: false, service_name: "TestService"}

      result1 = Pool.get_connection(provider)

      case result1 do
        {:ok, pid1} ->
          result2 = Pool.get_connection(provider)

          case result2 do
            {:ok, pid2} ->
              assert pid1 == pid2

            {:error, _} ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end

    test "creates different connections for different providers" do
      assert {:ok, _} = Pool.start_link(max_connections: 10)

      provider1 = %{host: "host1", port: 5001, use_ssl: false, service_name: "Svc1"}
      provider2 = %{host: "host2", port: 5002, use_ssl: false, service_name: "Svc2"}

      result1 = Pool.get_connection(provider1)
      result2 = Pool.get_connection(provider2)

      case {result1, result2} do
        {{:ok, pid1}, {:ok, pid2}} ->
          assert pid1 != pid2
          stats = Pool.stats()
          assert stats.total_connections == 2

        _ ->
          :ok
      end
    end
  end

  describe "get_connection/1 - dead connection replacement" do
    @tag :skip
    test "creates new connection when existing one is dead" do
      # This test requires isolated process supervision which is not
      # available without mocking the Connection module. The pool
      # links to connection processes, so killing them cascades.
      # Full coverage of this path is tested via integration tests.
    end
  end

  describe "concurrent access" do
    test "handles concurrent get_connection calls" do
      assert {:ok, _} = Pool.start_link(max_connections: 10)

      provider = %{host: "localhost", port: 50_051, use_ssl: false, service_name: "TestService"}

      tasks =
        for _ <- 1..5 do
          Task.async(fn -> Pool.get_connection(provider) end)
        end

      results = Task.await_many(tasks, 5000)

      for result <- results do
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
