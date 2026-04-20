# Exclude integration tests by default
# To run integration tests: mix test --include integration
ExUnit.start(exclude: [:integration])

# Configure Mox - use Code.ensure_compiled to avoid redefinition warnings
# when test_helper.exs is loaded multiple times
defmodule MoxSetup do
  def define_mocks do
    mocks = [
      {ExUtcp.Transports.Graphql.ConnectionMock, ExUtcp.Transports.Graphql.ConnectionBehaviour},
      {ExUtcp.Transports.Graphql.PoolMock, ExUtcp.Transports.Graphql.PoolBehaviour},
      {ExUtcp.Transports.Grpc.ConnectionMock, ExUtcp.Transports.Grpc.ConnectionBehaviour},
      {ExUtcp.Transports.Grpc.PoolMock, ExUtcp.Transports.Grpc.PoolBehaviour},
      {ExUtcp.Transports.WebSocket.ConnectionMock, ExUtcp.Transports.WebSocket.ConnectionBehaviour},
      {ExUtcp.Transports.Mcp.ConnectionMock, ExUtcp.Transports.Mcp.ConnectionBehaviour},
      {ExUtcp.Transports.Mcp.PoolMock, ExUtcp.Transports.Mcp.PoolBehaviour},
      {ExUtcp.Transports.WebRTC.ConnectionMock, ExUtcp.Transports.WebRTC.ConnectionBehaviour}
    ]

    for {mock, behaviour} <- mocks do
      case Code.ensure_compiled(mock) do
        {:module, _} -> :ok
        {:error, _} -> Mox.defmock(mock, for: behaviour)
      end
    end
  end
end

MoxSetup.define_mocks()
