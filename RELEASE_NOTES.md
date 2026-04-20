
## Release Notes - ExUtcp v0.3.2

### Overview
ExUtcp v0.3.2 is a quality and testing release focused on improving test coverage, fixing bugs, hardening CI security, and correcting documentation. Test coverage increased from 52.0% to 55.5%, and multiple bugs were identified and fixed during testing.

### Changes from v0.3.1

#### Added
- 71 unit tests for the Client module covering GenServer callbacks, provider/auth parsing, file validation, search, OpenAPI conversion, and monitoring.
- 23 new tests for the GraphQL transport covering GenServer callbacks and state management.
- Extended HTTP transport tests with SSE streaming, discovery parsing, header building, and schema parsing.
- 34 tests for GraphQL Connection module: struct definition, public API, GenServer callbacks, and terminate handling.
- 37 tests for TCP/UDP Pool and 29 tests for MCP Pool covering connection management and cleanup.
- 25 additional MCP Connection tests covering callbacks and retry logic.
- WebRTC ConnectionBehaviour module and Testable module with Mox support.
- CI workflows with pinned GitHub Action commit SHAs for supply-chain security.

#### Changed
- Test coverage increased from 52.0% to 55.5%.
- Integration tests now excluded by default (`ExUnit.start(exclude: [:integration])`).
- All emoji removed from documentation, replaced with plain text equivalents.
- 1473 total tests (0 failures, 133 excluded, 81 skipped).

#### Fixed
- GraphQL Connection: `handle_call(:get_last_used)` and `handle_call(:update_last_used)` referenced non-existent field `last_used_at` instead of `last_used`.
- WebRTC provider type spec: removed `url` and `auth` keys that were required by the type but never created in actual provider maps.
- GitHub Actions: pinned all actions to full commit SHAs (`actions/checkout@11bd7190`, `erlef/setup-beam@a6e26b22`, `actions/cache@5a3ec84e`).
- Documentation: corrected test counts, Sobelow findings count, warnings count, and Python comment syntax.

---

## Release Notes - ExUtcp v0.3.1

### Overview
ExUtcp v0.3.1 introduces WebRTC Transport for peer-to-peer communication, completing Phase 3: Extended Protocols. This release enables direct device-to-device tool calling with WebRTC data channels, NAT traversal, and secure DTLS encryption.

### Changes from v0.3.0

#### Added
- WebRTC Transport with peer-to-peer communication capabilities using WebRTC data channels.
- ExWebRTC library integration providing W3C WebRTC API implementation in pure Elixir.
- WebRTC connection management with automatic signaling protocol handling.
- ICE candidate handling with STUN/TURN server support for NAT traversal.
- WebRTC data channels for reliable tool communication between peers.
- Peer-to-peer tool calling without requiring central server infrastructure.
- WebRTC signaling server client for SDP offer/answer and ICE candidate exchange.
- Configurable ICE servers with support for public STUN and private TURN servers.
- DTLS encryption for secure peer-to-peer communication by default.
- WebRTC streaming support with data channel multiplexing for concurrent operations.
- 18 comprehensive WebRTC tests covering transport features and configuration.
- WebRTC examples with complete setup guide and configuration instructions.
- Sobelow security analysis tool integration for enhanced code security scanning.

#### Changed
- Updated Client module to include WebRTC transport in default transports list.
- Enhanced Providers module with WebRTC provider configuration and ICE server setup.
- Updated transport count from 7 to 8 transports with WebRTC addition.
- Improved documentation with WebRTC setup guide and use cases.

#### Fixed
- WebRTC provider configuration with proper ICE server defaults (Google STUN servers).
- Connection lifecycle management for WebRTC peers with automatic reconnection.
- Data channel message handling and JSON serialization for tool calls.

### Phase 3 Completion
With v0.3.1, Phase 3: Extended Protocols is now complete with WebRTC transport implementation.

---

## Release Notes - ExUtcp v0.3.0

### Overview
ExUtcp v0.3.0 introduces comprehensive Monitoring and Metrics capabilities, completing Phase 2 of the enhanced features roadmap. This release provides production-ready monitoring with telemetry integration, Prometheus metrics, health checks, and performance analysis.

## Changes from v0.2.9

### Added
- Monitoring and Metrics system with telemetry integration for all UTCP operations.
- Telemetry events for tool calls, searches, provider registration, and connection lifecycle.
- PromEx integration for Prometheus metrics collection and visualization with custom dashboards.
- Health check system for monitoring transport and component health with automatic status reporting.
- Performance monitoring with operation timing, statistical analysis, and threshold-based alerting.
- Metrics collection system supporting counters, gauges, histograms, and summaries.
- System monitoring for memory usage, process counts, scheduler utilization, and garbage collection.
- Performance alerts and threshold-based monitoring for proactive issue detection.
- Custom metrics recording and aggregation for application-specific monitoring needs.
- Monitoring dashboard configuration with PromEx and Grafana integration support.
- 15+ comprehensive monitoring tests covering telemetry, health checks, and performance measurement.
- Monitoring examples demonstrating all monitoring capabilities and integration patterns.

### Changed
- Enhanced Client module with integrated monitoring and performance measurement for all operations.
- Added telemetry events to tool calls and search operations for comprehensive performance tracking.
- Improved error handling with performance metrics collection for failed operations and debugging.
- Updated Client API with monitoring functions (get_monitoring_metrics, get_health_status, get_performance_summary).

### Fixed
- Performance measurement error handling with proper telemetry emission for both success and failure cases.
- Health check system robustness with fallback mechanisms when components are unavailable.
- Metrics collection reliability with graceful degradation when monitoring services are not running.

