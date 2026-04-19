defmodule ExUtcp.Search.EngineTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Search.Engine

  @moduletag :unit

  describe "new/1" do
    test "creates engine with defaults" do
      engine = Engine.new()

      assert engine.tools_index == %{}
      assert engine.providers_index == %{}
      assert engine.config.fuzzy_threshold == 0.6
      assert engine.config.semantic_threshold == 0.3
      assert engine.config.max_results == 100
      assert engine.config.enable_caching == true
    end

    test "creates engine with custom config" do
      engine = Engine.new(fuzzy_threshold: 0.8, max_results: 50)

      assert engine.config.fuzzy_threshold == 0.8
      assert engine.config.max_results == 50
    end
  end

  describe "add_tool/2 (struct-based)" do
    test "adds a tool to the index" do
      engine = Engine.new()
      tool = %{name: "get_user", provider_name: "api", definition: %{}}

      updated = Engine.add_tool(engine, tool)

      assert updated.tools_index["get_user"] == tool
    end

    test "overwrites existing tool with same name" do
      engine = Engine.new()
      tool_v1 = %{name: "get_user", provider_name: "api", definition: %{version: 1}}
      tool_v2 = %{name: "get_user", provider_name: "api", definition: %{version: 2}}

      updated = engine |> Engine.add_tool(tool_v1) |> Engine.add_tool(tool_v2)

      assert updated.tools_index["get_user"].definition.version == 2
    end
  end

  describe "add_provider/2 (struct-based)" do
    test "adds a provider to the index" do
      engine = Engine.new()
      provider = %{name: "my_api", type: :http, url: "http://example.com"}

      updated = Engine.add_provider(engine, provider)

      assert updated.providers_index["my_api"] == provider
    end
  end

  describe "remove_tool/2 (struct-based)" do
    test "removes a tool from the index" do
      engine = Engine.new()
      tool = %{name: "get_user", provider_name: "api", definition: %{}}

      updated = engine |> Engine.add_tool(tool) |> Engine.remove_tool("get_user")

      assert updated.tools_index == %{}
    end

    test "returns engine unchanged when removing nonexistent tool" do
      engine = Engine.new()
      result = Engine.remove_tool(engine, "nonexistent")
      assert result.tools_index == %{}
    end
  end

  describe "remove_provider/2 (struct-based)" do
    test "removes a provider from the index" do
      engine = Engine.new()
      provider = %{name: "my_api", type: :http, url: "http://example.com"}

      updated = engine |> Engine.add_provider(provider) |> Engine.remove_provider("my_api")

      assert updated.providers_index == %{}
    end
  end

  describe "get_all_tools/1 (struct-based)" do
    test "returns all tools" do
      engine =
        Engine.new()
        |> Engine.add_tool(%{name: "tool1", provider_name: "api", definition: %{}})
        |> Engine.add_tool(%{name: "tool2", provider_name: "api", definition: %{}})

      tools = Engine.get_all_tools(engine)
      assert length(tools) == 2
    end

    test "returns empty list when no tools" do
      engine = Engine.new()
      assert Engine.get_all_tools(engine) == []
    end
  end

  describe "get_all_providers/1 (struct-based)" do
    test "returns all providers" do
      engine =
        Engine.new()
        |> Engine.add_provider(%{name: "api1", type: :http})
        |> Engine.add_provider(%{name: "api2", type: :grpc})

      providers = Engine.get_all_providers(engine)
      assert length(providers) == 2
    end
  end

  describe "get_tool/2 (struct-based)" do
    test "returns tool by name" do
      tool = %{name: "get_user", provider_name: "api", definition: %{}}

      engine =
        Engine.new()
        |> Engine.add_tool(tool)

      assert Engine.get_tool(engine, "get_user") == tool
    end

    test "returns nil for nonexistent tool" do
      engine = Engine.new()
      assert Engine.get_tool(engine, "nonexistent") == nil
    end
  end

  describe "get_provider/2 (struct-based)" do
    test "returns provider by name" do
      provider = %{name: "my_api", type: :http}

      engine =
        Engine.new()
        |> Engine.add_provider(provider)

      assert Engine.get_provider(engine, "my_api") == provider
    end

    test "returns nil for nonexistent provider" do
      engine = Engine.new()
      assert Engine.get_provider(engine, "nonexistent") == nil
    end
  end

  describe "clear/1 (struct-based)" do
    test "clears all tools and providers" do
      engine =
        Engine.new()
        |> Engine.add_tool(%{name: "tool1", provider_name: "api", definition: %{}})
        |> Engine.add_provider(%{name: "api1", type: :http})

      cleared = Engine.clear(engine)

      assert cleared.tools_index == %{}
      assert cleared.providers_index == %{}
    end
  end

  describe "stats/1 (struct-based)" do
    test "returns engine statistics" do
      engine =
        Engine.new()
        |> Engine.add_tool(%{name: "tool1", provider_name: "api", definition: %{}})
        |> Engine.add_tool(%{name: "tool2", provider_name: "api", definition: %{}})
        |> Engine.add_provider(%{name: "api1", type: :http})

      stats = Engine.stats(engine)

      assert stats.tools_count == 2
      assert stats.providers_count == 1
      assert stats.config.fuzzy_threshold == 0.6
    end
  end
end
