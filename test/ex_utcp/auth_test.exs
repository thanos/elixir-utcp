defmodule ExUtcp.AuthTest do
  use ExUnit.Case, async: true

  alias ExUtcp.Auth

  @moduletag :unit

  describe "new_api_key_auth/1" do
    test "creates api key auth with required fields" do
      auth = Auth.new_api_key_auth(api_key: "sk-123", location: "header", var_name: "X-API-Key")

      assert auth.type == "api_key"
      assert auth.api_key == "sk-123"
      assert auth.location == "header"
      assert auth.var_name == "X-API-Key"
    end

    test "defaults location and var_name" do
      auth = Auth.new_api_key_auth(api_key: "sk-123")

      assert auth.location == "header"
      assert auth.var_name == "Authorization"
    end

    test "raises on missing api_key" do
      assert_raise KeyError, fn ->
        Auth.new_api_key_auth(location: "header")
      end
    end
  end

  describe "new_basic_auth/1" do
    test "creates basic auth with required fields" do
      auth = Auth.new_basic_auth(username: "user", password: "pass")

      assert auth.type == "basic"
      assert auth.username == "user"
      assert auth.password == "pass"
    end

    test "raises on missing username" do
      assert_raise KeyError, fn ->
        Auth.new_basic_auth(password: "pass")
      end
    end

    test "raises on missing password" do
      assert_raise KeyError, fn ->
        Auth.new_basic_auth(username: "user")
      end
    end
  end

  describe "new_oauth2_auth/1" do
    test "creates oauth2 auth with required fields" do
      auth =
        Auth.new_oauth2_auth(
          client_id: "id",
          client_secret: "secret",
          token_url: "https://example.com/token",
          scope: "read"
        )

      assert auth.type == "oauth2"
      assert auth.client_id == "id"
      assert auth.client_secret == "secret"
      assert auth.token_url == "https://example.com/token"
      assert auth.scope == "read"
    end

    test "raises on missing required fields" do
      assert_raise KeyError, fn ->
        Auth.new_oauth2_auth(client_id: "id")
      end
    end
  end

  describe "apply_to_headers/2" do
    test "applies api key auth to header" do
      auth = Auth.new_api_key_auth(api_key: "sk-123", var_name: "X-API-Key")
      headers = Auth.apply_to_headers(auth, %{})

      assert headers["X-API-Key"] == "sk-123"
    end

    test "applies api key auth with query location (no header change)" do
      auth = Auth.new_api_key_auth(api_key: "sk-123", location: "query")
      headers = Auth.apply_to_headers(auth, %{"Content-Type" => "application/json"})

      assert headers["Content-Type"] == "application/json"
      refute Map.has_key?(headers, "Authorization")
    end

    test "applies api key auth with cookie location" do
      auth = Auth.new_api_key_auth(api_key: "sk-123", location: "cookie", var_name: "session")
      headers = Auth.apply_to_headers(auth, %{})

      assert headers["Cookie"] == "session=sk-123"
    end

    test "applies basic auth to headers" do
      auth = Auth.new_basic_auth(username: "user", password: "pass")
      headers = Auth.apply_to_headers(auth, %{})

      expected = Base.encode64("user:pass")
      assert headers["Authorization"] == "Basic #{expected}"
    end

    test "oauth2 auth passes through headers unchanged" do
      auth =
        Auth.new_oauth2_auth(
          client_id: "id",
          client_secret: "secret",
          token_url: "https://example.com/token",
          scope: "read"
        )

      headers = %{"Content-Type" => "application/json"}
      result = Auth.apply_to_headers(auth, headers)

      assert result == headers
    end

    test "returns headers unchanged for nil auth" do
      headers = %{"Content-Type" => "application/json"}
      assert Auth.apply_to_headers(nil, headers) == headers
    end

    test "returns headers unchanged for unknown auth type" do
      auth = %{type: "unknown"}
      headers = %{"Content-Type" => "application/json"}
      assert Auth.apply_to_headers(auth, headers) == headers
    end

    test "preserves existing headers when applying auth" do
      auth = Auth.new_api_key_auth(api_key: "sk-123", var_name: "X-API-Key")
      headers = Auth.apply_to_headers(auth, %{"Content-Type" => "application/json"})

      assert headers["Content-Type"] == "application/json"
      assert headers["X-API-Key"] == "sk-123"
    end
  end

  describe "validate_auth/1" do
    test "validates valid api key auth" do
      auth = Auth.new_api_key_auth(api_key: "sk-123")
      assert :ok = Auth.validate_auth(auth)
    end

    test "rejects api key auth with empty api_key" do
      auth = %{type: "api_key", api_key: "", location: "header", var_name: "Authorization"}
      assert {:error, _} = Auth.validate_auth(auth)
    end

    test "rejects api key auth with nil api_key" do
      auth = %{type: "api_key", api_key: nil, location: "header", var_name: "Authorization"}
      assert {:error, _} = Auth.validate_auth(auth)
    end

    test "validates valid basic auth" do
      auth = Auth.new_basic_auth(username: "user", password: "pass")
      assert :ok = Auth.validate_auth(auth)
    end

    test "rejects basic auth with empty username" do
      auth = %{type: "basic", username: "", password: "pass"}
      assert {:error, _} = Auth.validate_auth(auth)
    end

    test "validates valid oauth2 auth" do
      auth =
        Auth.new_oauth2_auth(
          client_id: "id",
          client_secret: "secret",
          token_url: "https://example.com/token",
          scope: "read"
        )

      assert :ok = Auth.validate_auth(auth)
    end

    test "rejects oauth2 auth with missing fields" do
      auth = %{type: "oauth2", client_id: nil, client_secret: "secret", token_url: "url", scope: "read"}
      assert {:error, _} = Auth.validate_auth(auth)
    end

    test "rejects unknown auth type" do
      auth = %{type: "unknown"}
      assert {:error, msg} = Auth.validate_auth(auth)
      assert msg =~ "Unknown authentication type"
    end
  end

  describe "apply_api_key_auth/2" do
    test "applies api key to header location" do
      auth = Auth.new_api_key_auth(api_key: "test-key", location: "header", var_name: "X-API-Key")
      headers = Auth.apply_api_key_auth(auth, %{})
      assert headers["X-API-Key"] == "test-key"
    end

    test "applies api key to cookie location" do
      auth = Auth.new_api_key_auth(api_key: "test-key", location: "cookie", var_name: "session")
      headers = Auth.apply_api_key_auth(auth, %{})
      assert headers["Cookie"] == "session=test-key"
    end

    test "skips header for query location" do
      auth = Auth.new_api_key_auth(api_key: "test-key", location: "query")
      headers = Auth.apply_api_key_auth(auth, %{"Accept" => "application/json"})
      assert headers["Accept"] == "application/json"
      refute Map.has_key?(headers, "Authorization")
    end

    test "returns headers unchanged for unknown location" do
      auth = Auth.new_api_key_auth(api_key: "test-key", location: "unknown")
      headers = Auth.apply_api_key_auth(auth, %{})
      assert headers == %{}
    end
  end

  describe "apply_basic_auth/2" do
    test "encodes credentials in base64" do
      auth = Auth.new_basic_auth(username: "admin", password: "secret")
      headers = Auth.apply_basic_auth(auth, %{})
      expected = Base.encode64("admin:secret")
      assert headers["Authorization"] == "Basic #{expected}"
    end
  end
end
