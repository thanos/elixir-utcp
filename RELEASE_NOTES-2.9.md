# Release Notes - ExUtcp v0.2.9

## Overview
ExUtcp v0.2.9 introduces Advanced Search capabilities, completing Phase 2 of the enhanced features roadmap. This release provides comprehensive search functionality with multiple algorithms, security scanning, and intelligent ranking.

## Changes from v0.2.8

### Added
- Advanced Search system with multiple search algorithms (exact, fuzzy, semantic, combined).
- FuzzyCompare library integration for sophisticated fuzzy string matching with multiple similarity metrics.
- Haystack library integration for full-text search capabilities and document indexing.
- TruffleHog library integration for sensitive data detection and security scanning in search results.
- Search filters by provider name, transport type, tags, and capabilities.
- Search result ranking system with relevance scoring based on popularity, quality, recency, and context.
- Security scanning for tools and providers with automatic sensitive data detection.
- Search suggestions system for auto-complete functionality.
- Similar tool discovery based on semantic similarity analysis.
- 40+ comprehensive search tests covering all algorithms, filters, and security features.
- Advanced search examples demonstrating all search capabilities.

### Changed
- Enhanced Client module with complete search functionality integration.
- Improved search result structure including security warnings and detailed match metadata.
- Updated search options to support security scanning and sensitive data filtering.
- Enhanced tool and provider discovery with intelligent ranking and scoring.

### Fixed
- Search result ranking algorithm for accurate relevance scoring across different match types.
- Fuzzy search integration with proper similarity calculations using FuzzyCompare library.
- Semantic search keyword extraction and matching with stop word filtering.
- Security scanning fallback mechanisms for robust operation when external libraries fail.

## Future Roadmap
- **Phase 3: Extended Protocol Support**: Focus on WebRTC transport implementation.
- **Phase 4: Enterprise Features**: Monitoring and Metrics, Batch Operations, Custom Variable Loaders.

## Links
- GitHub Repository
- Hex Package
- HexDocs

---

# Release Notes - ExUtcp v0.2.8

## Overview
ExUtcp v0.2.8 introduces TCP/UDP transport support and comprehensive test configuration improvements. This release completes the low-level network protocol implementation and establishes a robust testing framework with proper integration test isolation.

## Changes from v0.2.7

### Added
- TCP/UDP Transport: Complete implementation of low-level network protocols with connection management, pooling, and streaming support.
- TCP/UDP connection behaviors and testable modules for proper mocking and testing.
- Test configuration system with integration test exclusion by default.
- Proper test tagging system with @tag :integration and @tag :unit for test categorization.
- TCP/UDP transport retry logic with exponential backoff for connection resilience.
- TCP/UDP transport integration tests for real network connection validation.
- TCP/UDP transport mock tests with Mox integration for isolated unit testing.
- TCP/UDP transport examples demonstrating usage patterns.

### Changed
- Test helper configuration now excludes integration tests by default (mix test).
- Integration tests require explicit inclusion (mix test --include integration).
- TCP connection tests properly categorized as integration tests instead of unit tests.
- Improved test isolation and reliability by separating network-dependent tests.
- Enhanced test documentation and organization for better developer experience.

### Fixed
- Test suite reliability by implementing proper separation between unit and integration tests.
- TCP/UDP mock test isolation issues with unique GenServer process names.
- Test timeout issues in TCP/UDP mock tests through proper Mox configuration.
- Proper categorization of network-dependent tests to prevent CI/CD flakiness.
- Test configuration to ensure consistent behavior across development and production environments.

## Future Roadmap
- **Phase 3: Extended Protocol Support**: Focus on WebRTC transport implementation.
- **Phase 4: Enterprise Features**: Advanced Search Algorithms, Monitoring and Metrics, Batch Operations.

## Links
- GitHub Repository
- Hex Package
- HexDocs

---

# Release Notes - ExUtcp v0.2.7

## Overview
ExUtcp v0.2.7 introduces the OpenAPI Converter, enabling automatic discovery and conversion of OpenAPI specifications into UTCP tools. This release completes the gap analysis for OpenAPI support and provides comprehensive tool generation capabilities.

## Changes from v0.2.6

### Added
- OpenAPI Converter module with automatic API discovery and tool generation
- Support for OpenAPI 2.0 (Swagger) and OpenAPI 3.0 specifications
- JSON and YAML specification parsing capabilities
- URL and file-based specification loading
- Authentication scheme mapping for API Key, Basic, Bearer, OAuth2, and OpenID Connect
- Tool generation from OpenAPI operations with proper parameter mapping
- Client integration methods: convert_openapi, convert_multiple_openapi, validate_openapi
- 12 comprehensive OpenAPI Converter unit tests
- OpenAPI Converter examples and documentation

### Changed
- Updated gap analysis table to reflect 100% OpenAPI Converter coverage
- Enhanced README with OpenAPI Converter usage examples and documentation
- Updated test count from 260+ to 272+ tests
- Updated priority recommendations to mark OpenAPI Converter as completed

### Fixed
- Corrected Elixir type usage patterns in OpenAPI Converter implementation
- Fixed infinite recursion in schema parsing functions
- Improved content type handling for URL-based specification loading
- Resolved prefix duplication in tool name generation
- Fixed argument error in security scheme parsing with proper tuple handling
- Corrected authentication parameter mapping between OpenAPI and UTCP formats

## Technical Details

### OpenAPI Converter Features
- Parses OpenAPI 2.0 and 3.0 specifications from JSON and YAML formats
- Converts OpenAPI operations into UTCP tools with proper input/output schemas
- Maps OpenAPI security schemes to UTCP authentication configurations
- Supports variable substitution in authentication parameters
- Handles both URL and file-based specification loading
- Provides validation capabilities for OpenAPI specifications

### Integration
- Seamlessly integrated with existing Client interface
- Maintains consistency with existing UTCP patterns
- Supports all existing authentication methods
- Compatible with all transport layers

## Future Roadmap
- **Phase 2: Enhanced Features**: Focus on Advanced Search Algorithms, Monitoring and Metrics, and Batch Operations
- **Phase 3: Extended Protocol Support**: Implement TCP/UDP, WebRTC, Server-Sent Events, and Streamable HTTP transports
- **Phase 4: Enterprise Features**: Advanced Configuration Management, Custom Variable Loaders, API Documentation Generation, and Performance Profiling

## Links
- [GitHub Repository](https://github.com/universal-tool-calling-protocol/elixir-utcp)
- [Hex Package](https://hex.pm/packages/ex_utcp)
- [HexDocs](https://hexdocs.pm/ex_utcp)