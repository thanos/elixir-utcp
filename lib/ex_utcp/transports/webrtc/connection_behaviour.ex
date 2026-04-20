defmodule ExUtcp.Transports.WebRTC.ConnectionBehaviour do
  @moduledoc """
  Behaviour for WebRTC Connection modules.

  This allows for mocking in tests.
  """

  @doc """
  Starts a new WebRTC connection.
  """
  @callback start_link(provider :: map(), signaling_server :: String.t(), ice_servers :: [map()]) ::
              {:ok, pid()} | {:error, term()}

  @doc """
  Calls a tool over the WebRTC data channel.
  """
  @callback call_tool(
              pid :: pid(),
              tool_name :: String.t(),
              args :: map(),
              timeout :: integer()
            ) :: {:ok, map()} | {:error, term()}

  @doc """
  Calls a tool stream over the WebRTC data channel.
  """
  @callback call_tool_stream(
              pid :: pid(),
              tool_name :: String.t(),
              args :: map(),
              timeout :: integer()
            ) :: {:ok, Enumerable.t()} | {:error, term()}

  @doc """
  Closes the WebRTC connection.
  """
  @callback close(pid :: pid()) :: :ok

  @doc """
  Gets the connection state.
  """
  @callback get_connection_state(pid :: pid()) :: atom()

  @doc """
  Gets the ICE connection state.
  """
  @callback get_ice_connection_state(pid :: pid()) :: atom()
end
