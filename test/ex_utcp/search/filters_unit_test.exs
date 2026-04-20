defmodule ExUtcp.Search.FiltersTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Search.Filters

  @moduletag :unit

  setup do
    tools = [
      %{
        name: "get_user",
        provider_name: "user_http_api",
        definition: %{description: "Get user data", tags: ["api", "data"]}
      },
      %{
        name: "create_user",
        provider_name: "user_http_api",
        definition: %{description: "Create a user", tags: ["api"]}
      },
      %{
        name: "delete_file",
        provider_name: "file_cli_handler",
        definition: %{description: "Delete a file", tags: ["file-processing"]}
      },
      %{
        name: "search_data",
        provider_name: "data_grpc_service",
        definition: %{description: "Search data", tags: ["data", "search"]}
      }
    ]

    providers = [
      %{name: "user_http_api", type: :http},
      %{name: "file_cli_handler", type: :cli},
      %{name: "data_grpc_service", type: :grpc}
    ]

    %{tools: tools, providers: providers}
  end

  describe "apply_filters/2" do
    test "returns all tools with empty filters", %{tools: tools} do
      assert Filters.apply_filters(tools, %{}) == tools
    end

    test "filters by providers", %{tools: tools} do
      result = Filters.apply_filters(tools, %{providers: ["user_http_api"]})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.provider_name == "user_http_api"))
    end

    test "filters by transports", %{tools: tools} do
      result = Filters.apply_filters(tools, %{transports: [:http]})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.provider_name == "user_http_api"))
    end
  end

  describe "apply_provider_filters/2" do
    test "returns all providers with empty filters", %{providers: providers} do
      assert Filters.apply_provider_filters(providers, %{}) == providers
    end

    test "filters providers by name", %{providers: providers} do
      result = Filters.apply_provider_filters(providers, %{providers: ["user_http_api"]})
      assert length(result) == 1
      assert hd(result).name == "user_http_api"
    end

    test "filters providers by transport", %{providers: providers} do
      result = Filters.apply_provider_filters(providers, %{transports: [:http]})
      assert length(result) == 1
      assert hd(result).type == :http
    end
  end

  describe "filter_by_providers/2" do
    test "returns all tools with empty provider list", %{tools: tools} do
      assert Filters.filter_by_providers(tools, []) == tools
    end

    test "filters tools by single provider", %{tools: tools} do
      result = Filters.filter_by_providers(tools, ["user_http_api"])
      assert length(result) == 2
      assert Enum.all?(result, &(&1.provider_name == "user_http_api"))
    end

    test "filters tools by multiple providers", %{tools: tools} do
      result = Filters.filter_by_providers(tools, ["user_http_api", "file_cli_handler"])
      assert length(result) == 3
    end

    test "returns empty list when no providers match", %{tools: tools} do
      result = Filters.filter_by_providers(tools, ["nonexistent"])
      assert result == []
    end
  end

  describe "filter_by_transports/2" do
    test "returns all tools with empty transport list", %{tools: tools} do
      assert Filters.filter_by_transports(tools, []) == tools
    end

    test "filters tools by http transport" do
      tools = [
        %{name: "get_user", provider_name: "user_http_api", definition: %{}},
        %{name: "delete_file", provider_name: "file_cli_handler", definition: %{}}
      ]

      result = Filters.filter_by_transports(tools, [:http])
      assert length(result) == 1
      assert hd(result).provider_name == "user_http_api"
    end

    test "filters tools by cli transport" do
      tools = [
        %{name: "get_user", provider_name: "user_http_api", definition: %{}},
        %{name: "delete_file", provider_name: "file_cli_handler", definition: %{}}
      ]

      result = Filters.filter_by_transports(tools, [:cli])
      assert length(result) == 1
    end

    test "filters tools by grpc transport" do
      tools = [
        %{name: "search_data", provider_name: "data_grpc_service", definition: %{}}
      ]

      result = Filters.filter_by_transports(tools, [:grpc])
      assert length(result) == 1
    end
  end

  describe "filter_by_tags/2" do
    test "returns all tools with empty tag list", %{tools: tools} do
      assert Filters.filter_by_tags(tools, []) == tools
    end

    test "filters tools by single tag" do
      tools_with_tags = [
        %{name: "tool1", provider_name: "api", definition: %{tags: ["api", "data"], description: "test"}}
      ]

      result = Filters.filter_by_tags(tools_with_tags, ["api"])
      assert length(result) == 1
    end

    test "returns empty list when no tags match" do
      tools_no_match = [
        %{name: "tool1", provider_name: "api", definition: %{tags: ["api"], description: "test"}}
      ]

      result = Filters.filter_by_tags(tools_no_match, ["nonexistent"])
      assert result == []
    end
  end

  describe "filter_providers_by_names/2" do
    test "returns all providers with empty name list", %{providers: providers} do
      assert Filters.filter_providers_by_names(providers, []) == providers
    end

    test "filters providers by name", %{providers: providers} do
      result = Filters.filter_providers_by_names(providers, ["user_http_api"])
      assert length(result) == 1
    end
  end

  describe "filter_providers_by_transports/2" do
    test "returns all providers with empty transport list", %{providers: providers} do
      assert Filters.filter_providers_by_transports(providers, []) == providers
    end

    test "filters providers by transport type", %{providers: providers} do
      result = Filters.filter_providers_by_transports(providers, [:http])
      assert length(result) == 1
    end
  end

  describe "capability_filter/1" do
    test "filters tools that match capabilities" do
      tools = [
        %{
          name: "tool1",
          provider_name: "prov",
          definition: %{description: "test", parameters: %{"properties" => %{"file" => %{"type" => "string"}}}}
        }
      ]

      filter = Filters.capability_filter(["file-handling"])
      result = Enum.filter(tools, filter)
      assert length(result) == 1
    end

    test "returns empty when no capabilities match" do
      tools = [
        %{name: "tool1", provider_name: "prov", definition: %{description: "test"}}
      ]

      filter = Filters.capability_filter(["nonexistent"])
      result = Enum.filter(tools, filter)
      assert result == []
    end
  end

  describe "parameter_type_filter/1" do
    test "filters tools by parameter types" do
      tools = [
        %{
          name: "tool1",
          provider_name: "prov",
          definition: %{description: "test", parameters: %{"properties" => %{"arg1" => %{"type" => "string"}}}}
        },
        %{
          name: "tool2",
          provider_name: "prov",
          definition: %{description: "test", parameters: %{"properties" => %{"arg1" => %{"type" => "integer"}}}}
        }
      ]

      filter = Filters.parameter_type_filter(["string"])
      result = Enum.filter(tools, filter)
      assert length(result) == 1
    end
  end
end
