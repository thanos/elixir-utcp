defmodule ExUtcp.Transports.Mcp.MessageTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Transports.Mcp.Message

  describe "MCP Message" do
    test "builds request message" do
      request = Message.build_request("tools/list", %{})

      assert request["jsonrpc"] == "2.0"
      assert request["method"] == "tools/list"
      assert request["params"] == %{}
      assert is_integer(request["id"])
    end

    test "builds request message with custom id" do
      request = Message.build_request("tools/list", %{}, 123)

      assert request["jsonrpc"] == "2.0"
      assert request["method"] == "tools/list"
      assert request["params"] == %{}
      assert request["id"] == 123
    end

    test "builds notification message" do
      notification = Message.build_notification("tools/update", %{name: "test"})

      assert notification["jsonrpc"] == "2.0"
      assert notification["method"] == "tools/update"
      assert notification["params"] == %{name: "test"}
      refute Map.has_key?(notification, "id")
    end

    test "builds response message" do
      response = Message.build_response(%{tools: []}, 123)

      assert response["jsonrpc"] == "2.0"
      assert response["result"] == %{tools: []}
      assert response["id"] == 123
    end

    test "builds error response message" do
      error = Message.build_error_response(-32_601, "Method not found", %{method: "invalid"}, 123)

      assert error["jsonrpc"] == "2.0"
      assert error["error"]["code"] == -32_601
      assert error["error"]["message"] == "Method not found"
      assert error["error"]["data"] == %{method: "invalid"}
      assert error["id"] == 123
    end

    test "parses valid JSON-RPC response" do
      json = ~s({"jsonrpc":"2.0","result":{"tools":[]},"id":123})

      assert {:ok, %{"tools" => []}} = Message.parse_response(json)
    end

    test "parses JSON-RPC error response" do
      json = ~s({"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found"},"id":123})

      assert {:error, "JSON-RPC Error -32601: Method not found"} = Message.parse_response(json)
    end

    test "parses JSON-RPC request" do
      json = ~s({"jsonrpc":"2.0","method":"tools/list","params":{},"id":123})

      assert {:ok, %{"jsonrpc" => "2.0", "method" => "tools/list"}} = Message.parse_response(json)
    end

    test "validates valid message" do
      message = %{"jsonrpc" => "2.0", "method" => "test"}
      assert :ok = Message.validate_message(message)
    end

    test "validates message with missing jsonrpc" do
      message = %{"method" => "test"}
      assert {:error, "Missing jsonrpc field"} = Message.validate_message(message)
    end

    test "validates message with invalid jsonrpc version" do
      message = %{"jsonrpc" => "1.0", "method" => "test"}
      assert {:error, "Invalid jsonrpc version: 1.0"} = Message.validate_message(message)
    end

    test "extracts method from request" do
      message = %{"method" => "tools/list"}
      assert "tools/list" = Message.extract_method(message)
    end

    test "extracts id from message" do
      message = %{"id" => 123}
      assert 123 = Message.extract_id(message)
    end

    test "identifies notification" do
      notification = %{"method" => "test", "id" => nil}
      assert Message.notification?(notification)
    end

    test "identifies request" do
      request = %{"method" => "test", "id" => 123}
      assert Message.request?(request)
    end

    test "identifies response" do
      response = %{"result" => %{}}
      assert Message.response?(response)
    end

    test "identifies error response" do
      error = %{"error" => %{"code" => -1}}
      assert Message.error?(error)
    end

    test "extracts error information" do
      error = %{"error" => %{"code" => -32_601, "message" => "Method not found", "data" => %{}}}
      assert {-32_601, "Method not found", %{}} = Message.extract_error(error)
    end

    test "extracts result from response" do
      response = %{"result" => %{"tools" => []}}
      assert %{"tools" => []} = Message.extract_result(response)
    end

    test "builds error response without data" do
      error = Message.build_error_response(-32_600, "Invalid Request", nil, 1)

      assert error["jsonrpc"] == "2.0"
      assert error["error"]["code"] == -32_600
      assert error["error"]["message"] == "Invalid Request"
      refute Map.has_key?(error["error"], "data")
      assert error["id"] == 1
    end

    test "builds error response with nil id" do
      error = Message.build_error_response(-32_700, "Internal error", nil)

      assert error["jsonrpc"] == "2.0"
      assert error["error"]["code"] == -32_700
      assert error["id"] == nil
    end

    test "parses non-JSON-RPC message" do
      json = ~s({"type":"custom","data":"test"})

      assert {:ok, %{"type" => "custom", "data" => "test"}} = Message.parse_response(json)
    end

    test "parses invalid JSON" do
      assert {:error, _} = Message.parse_response("not json at all")
    end

    test "parses JSON-RPC error response with data" do
      json = ~s({"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found","data":"extra"},"id":123})

      assert {:error, msg} = Message.parse_response(json)
      assert msg =~ "JSON-RPC Error -32601"
      assert msg =~ "Method not found"
      assert msg =~ "extra"
    end

    test "parses JSON-RPC message that fails validation" do
      json = ~s({"jsonrpc":"2.0","id":1})
      assert {:error, "Message must have method, result, or error field"} = Message.parse_response(json)
    end

    test "parses non-2.0 JSON-RPC message passes through" do
      json = ~s({"jsonrpc":"1.0","method":"test","id":1})

      assert {:ok, %{"jsonrpc" => "1.0", "method" => "test"}} = Message.parse_response(json)
    end

    test "parses JSON-RPC message with only result field" do
      json = ~s({"jsonrpc":"2.0","result":{"data":"ok"},"id":1})
      assert {:ok, %{"data" => "ok"}} = Message.parse_response(json)
    end

    test "parses JSON-RPC message with only error field" do
      json = ~s({"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid Request"},"id":1})
      assert {:error, "JSON-RPC Error -32600: Invalid Request"} = Message.parse_response(json)
    end

    test "validates message with result field" do
      message = %{"jsonrpc" => "2.0", "result" => %{}}
      assert :ok = Message.validate_message(message)
    end

    test "validates message with error field" do
      message = %{"jsonrpc" => "2.0", "error" => %{"code" => -1}}
      assert :ok = Message.validate_message(message)
    end

    test "validates message without method, result, or error" do
      message = %{"jsonrpc" => "2.0", "id" => 1}
      assert {:error, "Message must have method, result, or error field"} = Message.validate_message(message)
    end

    test "extract_method returns nil for message without method" do
      assert nil == Message.extract_method(%{"id" => 123})
    end

    test "extract_id returns nil for message without id" do
      assert nil == Message.extract_id(%{"method" => "test"})
    end

    test "notification? returns false for message without method" do
      refute Message.notification?(%{"result" => %{}})
    end

    test "notification? returns false for message with method and id" do
      refute Message.notification?(%{"method" => "test", "id" => 123})
    end

    test "request? returns false for message without method" do
      refute Message.request?(%{"result" => %{}})
    end

    test "request? returns false for message with method but nil id" do
      refute Message.request?(%{"method" => "test", "id" => nil})
    end

    test "response? returns true for error message" do
      assert Message.response?(%{"error" => %{"code" => -1}})
    end

    test "response? returns false for plain message" do
      refute Message.response?(%{"method" => "test"})
    end

    test "error? returns false for non-error message" do
      refute Message.error?(%{"result" => %{}})
    end

    test "extract_result returns nil for message without result" do
      assert nil == Message.extract_result(%{"error" => %{"code" => -1}})
    end

    test "extract_error with missing fields defaults" do
      error = %{"error" => %{}}
      assert {-1, "Unknown error", nil} = Message.extract_error(error)
    end
  end
end
