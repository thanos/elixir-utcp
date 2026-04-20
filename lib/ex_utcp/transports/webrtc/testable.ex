defmodule ExUtcp.Transports.WebRTC.Testable do
  @moduledoc """
  Testable version of WebRTC transport that can use mocks.
  """

  use GenServer
  use ExUtcp.Transports.Behaviour

  alias ExUtcp.Transports.WebRTC.Connection

  require Logger

  @dialyzer {:nowarn_function, new: 1, start_link: 1}

  defstruct [
    :signaling_server,
    :ice_servers,
    :connection_timeout,
    :connections,
    :providers,
    :genserver_module,
    :connection_module
  ]

  @type t :: %__MODULE__{
          signaling_server: String.t(),
          ice_servers: [map()],
          connection_timeout: non_neg_integer(),
          connections: %{String.t() => pid()},
          providers: %{String.t() => map()},
          genserver_module: module(),
          connection_module: module()
        }

  @doc """
  Creates a new testable WebRTC transport.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      signaling_server: Keyword.get(opts, :signaling_server, "wss://signaling.example.com"),
      ice_servers: Keyword.get(opts, :ice_servers, default_ice_servers()),
      connection_timeout: Keyword.get(opts, :connection_timeout, 30_000),
      connections: %{},
      providers: %{},
      genserver_module: Keyword.get(opts, :genserver_module, __MODULE__),
      connection_module: Keyword.get(opts, :connection_module, Connection)
    }
  end

  @doc """
  Set mocks for testing.
  """
  def set_mocks(connection_module) do
    Application.put_env(:ex_utcp, :webrtc_connection_module, connection_module)
  end

  @doc """
  Get the connection module (real or mock).
  """
  def get_connection_module do
    Application.get_env(:ex_utcp, :webrtc_connection_module, Connection)
  end

  @doc """
  Clear mocks after testing.
  """
  def clear_mocks do
    Application.delete_env(:ex_utcp, :webrtc_connection_module)
  end

  @impl ExUtcp.Transports.Behaviour
  def transport_name, do: "webrtc"

  @impl ExUtcp.Transports.Behaviour
  def supports_streaming?, do: true

  @impl ExUtcp.Transports.Behaviour
  def register_tool_provider(provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(__MODULE__, {:register_tool_provider, provider})

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  def register_tool_provider(transport, provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(
          transport.genserver_module,
          {:register_tool_provider, provider, transport.connection_module}
        )

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  @impl ExUtcp.Transports.Behaviour
  def deregister_tool_provider(provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(__MODULE__, {:deregister_tool_provider, provider})

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  def deregister_tool_provider(transport, provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(
          transport.genserver_module,
          {:deregister_tool_provider, provider}
        )

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  @impl ExUtcp.Transports.Behaviour
  def call_tool(tool_name, args, provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(
          __MODULE__,
          {:call_tool, tool_name, args, provider},
          provider.timeout || 30_000
        )

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  def call_tool(transport, tool_name, args, provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(
          transport.genserver_module,
          {:call_tool, tool_name, args, provider, transport.connection_module},
          provider.timeout || 30_000
        )

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  @impl ExUtcp.Transports.Behaviour
  def call_tool_stream(tool_name, args, provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(
          __MODULE__,
          {:call_tool_stream, tool_name, args, provider},
          provider.timeout || 30_000
        )

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  def call_tool_stream(transport, tool_name, args, provider) do
    case provider.type do
      :webrtc ->
        GenServer.call(
          transport.genserver_module,
          {:call_tool_stream, tool_name, args, provider, transport.connection_module},
          provider.timeout || 30_000
        )

      _ ->
        {:error, "WebRTC transport can only be used with WebRTC providers"}
    end
  end

  @impl ExUtcp.Transports.Behaviour
  def close do
    GenServer.call(__MODULE__, :close)
  end

  def close(transport) do
    GenServer.call(transport.genserver_module, :close)
  end

  @doc """
  Starts the testable WebRTC transport GenServer.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    state = new(opts)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register_tool_provider, provider}, _from, state) do
    # Get connection module (real or mock)
    connection_module = get_connection_module()

    # Create connection for this provider
    case connection_module.start_link(
           provider,
           state.signaling_server,
           state.ice_servers
         ) do
      {:ok, conn_pid} ->
        new_connections = Map.put(state.connections, provider.name, conn_pid)
        new_providers = Map.put(state.providers, provider.name, provider)

        new_state = %{
          state
          | connections: new_connections,
            providers: new_providers
        }

        {:reply, {:ok, provider.tools || []}, new_state}

      {:error, reason} ->
        {:reply, {:error, "Failed to create connection: #{inspect(reason)}"}, state}
    end
  end

  @impl GenServer
  def handle_call({:register_tool_provider, provider, connection_module}, _from, state) do
    # Use provided connection module (for testing with mocks)
    case connection_module.start_link(
           provider,
           state.signaling_server,
           state.ice_servers
         ) do
      {:ok, conn_pid} ->
        new_connections = Map.put(state.connections, provider.name, conn_pid)
        new_providers = Map.put(state.providers, provider.name, provider)

        new_state = %{
          state
          | connections: new_connections,
            providers: new_providers
        }

        {:reply, {:ok, provider.tools || []}, new_state}

      {:error, reason} ->
        {:reply, {:error, "Failed to create connection: #{inspect(reason)}"}, state}
    end
  end

  @impl GenServer
  def handle_call({:deregister_tool_provider, provider}, _from, state) do
    # Close connection if exists
    case Map.get(state.connections, provider.name) do
      nil ->
        {:reply, :ok, state}

      conn_pid ->
        connection_module = get_connection_module()
        connection_module.close(conn_pid)

        new_connections = Map.delete(state.connections, provider.name)
        new_providers = Map.delete(state.providers, provider.name)

        new_state = %{state | connections: new_connections, providers: new_providers}
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:call_tool, tool_name, args, provider}, _from, state) do
    case Map.get(state.connections, provider.name) do
      nil ->
        {:reply, {:error, "Provider not registered: #{provider.name}"}, state}

      conn_pid ->
        connection_module = get_connection_module()

        case connection_module.call_tool(
               conn_pid,
               tool_name,
               args,
               state.connection_timeout
             ) do
          {:ok, result} -> {:reply, {:ok, result}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:call_tool, tool_name, args, provider, connection_module}, _from, state) do
    case Map.get(state.connections, provider.name) do
      nil ->
        {:reply, {:error, "Provider not registered: #{provider.name}"}, state}

      conn_pid ->
        case connection_module.call_tool(
               conn_pid,
               tool_name,
               args,
               state.connection_timeout
             ) do
          {:ok, result} -> {:reply, {:ok, result}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:call_tool_stream, tool_name, args, provider}, _from, state) do
    case Map.get(state.connections, provider.name) do
      nil ->
        {:reply, {:error, "Provider not registered: #{provider.name}"}, state}

      conn_pid ->
        connection_module = get_connection_module()

        case connection_module.call_tool_stream(
               conn_pid,
               tool_name,
               args,
               state.connection_timeout
             ) do
          {:ok, stream} -> {:reply, {:ok, stream}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:call_tool_stream, tool_name, args, provider, connection_module}, _from, state) do
    case Map.get(state.connections, provider.name) do
      nil ->
        {:reply, {:error, "Provider not registered: #{provider.name}"}, state}

      conn_pid ->
        case connection_module.call_tool_stream(
               conn_pid,
               tool_name,
               args,
               state.connection_timeout
             ) do
          {:ok, stream} -> {:reply, {:ok, stream}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:close, _from, state) do
    # Close all connections
    connection_module = get_connection_module()

    Enum.each(state.connections, fn {_name, conn_pid} ->
      connection_module.close(conn_pid)
    end)

    new_state = %{state | connections: %{}, providers: %{}}
    {:reply, :ok, new_state}
  end

  # Private functions

  defp default_ice_servers do
    [
      %{urls: ["stun:stun.l.google.com:19302"]},
      %{urls: ["stun:stun1.l.google.com:19302"]}
    ]
  end
end
