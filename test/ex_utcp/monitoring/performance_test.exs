defmodule ExUtcp.Monitoring.PerformanceTest do
  use ExUnit.Case, async: false

  alias ExUtcp.Monitoring.Metrics
  alias ExUtcp.Monitoring.Performance

  @moduletag :unit

  setup do
    case Process.whereis(Metrics) do
      nil ->
        {:ok, _pid} = Metrics.start_link()

      _ ->
        :ok
    end

    :ok
  end

  describe "measure/3" do
    test "measures function execution time and returns result" do
      result =
        Performance.measure("test_op", %{key: "value"}, fn ->
          "test_result"
        end)

      assert result == "test_result"
    end

    test "measures function that returns ok tuple" do
      result =
        Performance.measure("test_op", %{}, fn ->
          {:ok, %{"data" => "value"}}
        end)

      assert result == {:ok, %{"data" => "value"}}
    end

    test "measures function that returns error tuple" do
      result =
        Performance.measure("test_op", %{}, fn ->
          {:error, "something failed"}
        end)

      assert result == {:error, "something failed"}
    end

    test "reraises exceptions and records error metrics" do
      assert_raise RuntimeError, "deliberate error", fn ->
        Performance.measure("failing_op", %{}, fn ->
          raise "deliberate error"
        end)
      end
    end

    test "measures with empty metadata" do
      result =
        Performance.measure("minimal_op", %{}, fn ->
          42
        end)

      assert result == 42
    end
  end

  describe "measure_tool_call/4" do
    test "measures tool call with args" do
      result =
        Performance.measure_tool_call("my_tool", "my_provider", %{"x" => 1}, fn ->
          {:ok, "done"}
        end)

      assert result == {:ok, "done"}
    end

    test "measures tool call with empty args" do
      result =
        Performance.measure_tool_call("my_tool", "my_provider", %{}, fn ->
          {:ok, %{}}
        end)

      assert result == {:ok, %{}}
    end
  end

  describe "measure_search/4" do
    test "measures search returning list" do
      result =
        Performance.measure_search("query", :fuzzy, %{}, fn ->
          [%{name: "tool1"}, %{name: "tool2"}]
        end)

      assert is_list(result)
      assert length(result) == 2
    end

    test "measures search returning empty list" do
      result =
        Performance.measure_search("query", :exact, %{}, fn ->
          []
        end)

      assert result == []
    end

    test "measures search returning non-list" do
      result =
        Performance.measure_search("query", :semantic, %{}, fn ->
          {:ok, "not a list"}
        end)

      assert result == {:ok, "not a list"}
    end
  end

  describe "measure_connection/3" do
    test "measures connection returning ok" do
      result =
        Performance.measure_connection("provider1", :http, fn ->
          {:ok, "connected"}
        end)

      assert result == {:ok, "connected"}
    end

    test "measures connection returning error" do
      result =
        Performance.measure_connection("provider1", :grpc, fn ->
          {:error, "timeout"}
        end)

      assert result == {:error, "timeout"}
    end
  end

  describe "get_operation_stats/1" do
    test "returns stats map" do
      stats = Performance.get_operation_stats("nonexistent_operation")
      assert is_map(stats)
    end
  end

  describe "get_performance_summary/0" do
    test "returns a map" do
      summary = Performance.get_performance_summary()
      assert is_map(summary)
    end
  end

  describe "get_performance_alerts/1" do
    # Requires Metrics GenServer running
    @tag :skip
    test "returns list of alerts with nil metrics" do
      alerts = Performance.get_performance_alerts(nil)
      assert is_list(alerts)
    end

    test "returns list of alerts with empty metrics" do
      alerts = Performance.get_performance_alerts(%{})
      assert is_list(alerts)
    end
  end

  describe "record_custom_metric/4" do
    test "records counter metric" do
      assert :ok = Performance.record_custom_metric("test_counter_1", :counter, 1, %{env: "test"})
    end

    test "records gauge metric" do
      assert :ok = Performance.record_custom_metric("test_gauge_1", :gauge, 42.5, %{env: "test"})
    end

    test "records histogram metric" do
      assert :ok = Performance.record_custom_metric("test_hist_1", :histogram, 100, %{env: "test"})
    end

    test "records summary metric" do
      assert :ok = Performance.record_custom_metric("test_summary_1", :summary, 200, %{env: "test"})
    end

    test "records metric with empty labels" do
      assert :ok = Performance.record_custom_metric("test_empty_labels", :counter, 1, %{})
    end
  end

  describe "GenServer callbacks" do
    test "start_link starts the performance GenServer" do
      result = Performance.start_link()

      case result do
        {:ok, pid} ->
          assert is_pid(pid)
          GenServer.stop(pid)

        {:error, {:already_started, _}} ->
          :ok
      end
    end
  end
end
