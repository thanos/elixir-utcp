defmodule ExUtcp.Transports.Grpc.GnmiMockServer do
  @moduledoc false
  use GenServer

  def start_link(handler) do
    GenServer.start_link(__MODULE__, handler)
  end

  @impl true
  def init(handler) do
    {:ok, handler}
  end

  @impl true
  def handle_call({:call_tool, tool_name, request, _timeout}, _from, handler) do
    result = handler.({:call_tool, tool_name, request})
    {:reply, result, handler}
  end

  @impl true
  def handle_call({:call_tool_stream, tool_name, request, _timeout}, _from, handler) do
    result = handler.({:call_tool_stream, tool_name, request})
    {:reply, result, handler}
  end
end

defmodule ExUtcp.Transports.Grpc.GnmiUnitTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Transports.Grpc.Gnmi
  alias ExUtcp.Transports.Grpc.GnmiMockServer

  describe "validate_paths/1" do
    test "validates and normalizes valid paths" do
      paths = ["/interfaces/interface[name=eth0]/state", "  /system/state  "]
      assert {:ok, result} = Gnmi.validate_paths(paths)
      assert length(result) == 2
      assert "interfaces/interface[name=eth0]/state" in result
      assert "system/state" in result
    end

    test "rejects empty list" do
      assert {:error, "No valid paths provided"} = Gnmi.validate_paths([])
    end

    test "rejects list with only empty strings" do
      assert {:error, "No valid paths provided"} = Gnmi.validate_paths([""])
    end

    test "rejects list with only whitespace strings" do
      assert {:error, "No valid paths provided"} = Gnmi.validate_paths(["", "   ", "\t"])
    end

    test "filters out empty strings and keeps valid ones" do
      assert {:ok, result} = Gnmi.validate_paths(["/valid/path", "", "  ", "/another/path"])
      assert length(result) == 2
    end

    test "normalizes multiple slashes" do
      assert {:ok, result} = Gnmi.validate_paths(["/a///b//c"])
      assert result == ["a/b/c"]
    end

    test "removes leading slashes" do
      assert {:ok, result} = Gnmi.validate_paths(["/system/state"])
      assert result == ["system/state"]
    end

    test "single path segment" do
      assert {:ok, result} = Gnmi.validate_paths(["system"])
      assert result == ["system"]
    end
  end

  describe "build_path/3" do
    test "builds path with origin, elements, and target" do
      path = Gnmi.build_path("openconfig-interfaces", ["interfaces", "interface"], "name=eth0")
      assert path == "openconfig-interfaces/interfaces/interface[name=eth0]"
    end

    test "builds path without target" do
      path = Gnmi.build_path("openconfig-system", ["system", "state"])
      assert path == "openconfig-system/system/state"
    end

    test "builds path with origin only" do
      path = Gnmi.build_path("origin", [], "")
      assert path == "origin"
    end

    test "builds path with single element" do
      path = Gnmi.build_path("mymodule", ["config"], "")
      assert path == "mymodule/config"
    end

    test "builds path with target having key=value" do
      path = Gnmi.build_path("oc", ["interfaces", "interface"], "name=eth0")
      assert path == "oc/interfaces/interface[name=eth0]"
    end

    test "builds path with empty target string" do
      path = Gnmi.build_path("origin", ["elem1"], "")
      assert path == "origin/elem1"
    end
  end

  describe "parse_path/1" do
    test "parses a multi-segment path" do
      path = "openconfig-interfaces/interfaces/interface[name=eth0]/state"
      assert {:ok, parsed} = Gnmi.parse_path(path)
      assert parsed.origin == "openconfig-interfaces"
      assert parsed.elements == ["interfaces", "interface[name=eth0]", "state"]
      assert parsed.full_path == path
    end

    test "parses a simple two-segment path" do
      assert {:ok, parsed} = Gnmi.parse_path("system/state")
      assert parsed.origin == "system"
      assert parsed.elements == ["state"]
    end

    test "parses a single-segment path" do
      assert {:ok, parsed} = Gnmi.parse_path("system")
      assert parsed.origin == "system"
      assert parsed.elements == []
    end

    test "returns error for empty path" do
      assert {:error, "Empty path"} = Gnmi.parse_path("")
    end

    test "handles path with leading slash" do
      assert {:ok, parsed} = Gnmi.parse_path("/system/state")
      assert parsed.origin == "system"
      assert parsed.elements == ["state"]
    end

    test "handles path with trailing slash" do
      assert {:ok, parsed} = Gnmi.parse_path("system/state/")
      assert parsed.elements == ["state"]
    end

    test "handles path with multiple slashes" do
      assert {:ok, parsed} = Gnmi.parse_path("system//state")
      assert parsed.origin == "system"
      assert parsed.elements == ["state"]
    end

    test "returns map with full_path" do
      assert {:ok, parsed} = Gnmi.parse_path("a/b/c")
      assert parsed.full_path == "a/b/c"
    end
  end

  describe "get/3 - request building" do
    test "builds get request with paths and defaults" do
      handler = fn
        {:call_tool, "gnmi.get", request} ->
          assert request["type"] == "GetRequest"
          assert request["encoding"] == "JSON"
          assert request["use_models"] == []
          assert request["extension"] == []
          assert [%{"elem" => ["interfaces", "state"]}] = request["path"]
          {:ok, %{"notification" => [%{"path" => "test"}]}}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      result = Gnmi.get(pid, ["interfaces/state"])
      assert {:ok, _} = result
      GenServer.stop(pid)
    end

    test "passes custom encoding option" do
      handler = fn
        {:call_tool, "gnmi.get", request} ->
          assert request["encoding"] == "PROTO"
          {:ok, %{}}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      result = Gnmi.get(pid, ["/interfaces/state"], encoding: "PROTO")
      assert {:ok, _} = result
      GenServer.stop(pid)
    end

    test "returns error when connection fails" do
      handler = fn
        {:call_tool, "gnmi.get", _request} ->
          {:error, "Connection refused"}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      result = Gnmi.get(pid, ["/interfaces/state"])
      assert {:error, _} = result
      GenServer.stop(pid)
    end

    test "splits paths into elements" do
      handler = fn
        {:call_tool, "gnmi.get", request} ->
          assert [%{"elem" => ["interfaces", "state"]}, %{"elem" => ["system"]}] = request["path"]
          {:ok, %{}}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      Gnmi.get(pid, ["interfaces/state", "system"])
      GenServer.stop(pid)
    end
  end

  describe "set/3 - request building" do
    test "builds set request with updates" do
      updates = [%{"path" => "/config", "value" => "new_value"}]

      handler = fn
        {:call_tool, "gnmi.set", request} ->
          assert request["type"] == "SetRequest"
          assert request["update"] == updates
          {:ok, %{"response" => "ok"}}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      result = Gnmi.set(pid, updates)
      assert {:ok, _} = result
      GenServer.stop(pid)
    end

    test "defaults replace and delete to empty lists" do
      handler = fn
        {:call_tool, "gnmi.set", request} ->
          assert request["replace"] == []
          assert request["delete"] == []
          {:ok, %{}}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      Gnmi.set(pid, [])
      GenServer.stop(pid)
    end

    test "passes replace and delete options" do
      updates = [%{"path" => "/config", "value" => "val"}]

      handler = fn
        {:call_tool, "gnmi.set", request} ->
          assert request["replace"] == [%{"path" => "/old"}]
          assert request["delete"] == [%{"path" => "/stale"}]
          {:ok, %{}}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      result = Gnmi.set(pid, updates, replace: [%{"path" => "/old"}], delete: [%{"path" => "/stale"}])
      assert {:ok, _} = result
      GenServer.stop(pid)
    end

    test "returns error when connection fails" do
      handler = fn
        {:call_tool, "gnmi.set", _request} ->
          {:error, "Failed"}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      assert {:error, _} = Gnmi.set(pid, [])
      GenServer.stop(pid)
    end
  end

  describe "subscribe/3 - request building" do
    test "builds subscribe request with paths and defaults" do
      handler = fn
        {:call_tool_stream, "gnmi.subscribe", request} ->
          assert request["type"] == "SubscribeRequest"
          assert request["subscribe"]["mode"] == "STREAM"
          assert request["subscribe"]["encoding"] == "JSON"
          assert request["subscribe"]["updates_only"] == false
          {:ok, [%{"notification" => %{"path" => "test"}}]}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      result = Gnmi.subscribe(pid, ["/interfaces/state"])
      assert {:ok, _} = result
      GenServer.stop(pid)
    end

    test "subscription entries have correct defaults" do
      handler = fn
        {:call_tool_stream, "gnmi.subscribe", request} ->
          [sub] = request["subscribe"]["subscription"]
          assert sub["mode"] == "ON_CHANGE"
          assert sub["sample_interval"] == 0
          assert sub["suppress_redundant"] == false
          assert sub["heartbeat_interval"] == 0
          {:ok, []}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      Gnmi.subscribe(pid, ["/interfaces/state"])
      GenServer.stop(pid)
    end

    test "passes custom subscription options" do
      handler = fn
        {:call_tool_stream, "gnmi.subscribe", request} ->
          [sub] = request["subscribe"]["subscription"]
          assert sub["mode"] == "SAMPLE"
          assert sub["sample_interval"] == 5000
          assert request["subscribe"]["encoding"] == "PROTO"
          assert request["subscribe"]["updates_only"] == true
          {:ok, []}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      Gnmi.subscribe(pid, ["/path"], mode: "SAMPLE", sample_interval: 5000, encoding: "PROTO", updates_only: true)
      GenServer.stop(pid)
    end

    test "returns error when stream fails" do
      handler = fn
        {:call_tool_stream, "gnmi.subscribe", _request} ->
          {:error, "Stream rejected"}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      assert {:error, _} = Gnmi.subscribe(pid, ["/path"])
      GenServer.stop(pid)
    end
  end

  describe "capabilities/2" do
    test "sends capability request" do
      handler = fn
        {:call_tool, "gnmi.capabilities", request} ->
          assert request["type"] == "CapabilityRequest"
          {:ok, %{"models" => [%{"name" => "openconfig"}]}}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      result = Gnmi.capabilities(pid)
      assert {:ok, %{"models" => [_]}} = result
      GenServer.stop(pid)
    end

    test "returns error when connection fails" do
      handler = fn
        {:call_tool, "gnmi.capabilities", _request} ->
          {:error, "Not connected"}
      end

      {:ok, pid} = GnmiMockServer.start_link(handler)

      assert {:error, _} = Gnmi.capabilities(pid)
      GenServer.stop(pid)
    end
  end
end
