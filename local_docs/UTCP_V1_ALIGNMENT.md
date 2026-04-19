# UTCP v1.0 Alignment Analysis for ExUtcp

## Executive Summary

This document analyzes the [UTCP v1.0 migration guide](https://www.utcp.io/migration-v0.1-to-v1.0) and identifies changes needed in ExUtcp to align with the official UTCP v1.0 specification.

**Current ExUtcp Status**: Based on UTCP concepts but needs alignment with v1.0 spec  
**Target**: Full UTCP v1.0 compliance  
**Approach**: Use Ecto for validation (equivalent to Python's Pydantic)

---

## 1. Major Changes in UTCP v1.0

### 1.1 Plugin Architecture

**Python UTCP v1.0**:
- Core package (`utcp`)
- Protocol plugins (`utcp-http`, `utcp-cli`, `utcp-websocket`, `utcp-text`, `utcp-mcp`)
- Install only needed protocols

**Current ExUtcp**:
- ✅ Monolithic package with all transports
- ❌ No plugin architecture

**Recommendation**:
- **Keep monolithic for Elixir** - This is idiomatic for Elixir applications
- Optional: Create separate Mix applications for each transport (advanced)
- **Rationale**: Elixir applications typically include all features, OTP makes this efficient

**Action**: ✅ No change needed (architectural difference is acceptable)

---

## 2. Configuration Format Changes

### 2.1 Terminology Changes

| v0.1 Term | v1.0 Term | ExUtcp Current | Needs Change? |
|-----------|-----------|----------------|---------------|
| `providers` | `manual_call_templates` | `providers` | ✅ YES |
| `provider_type` | `call_template_type` | `type` | ✅ YES |
| `provider_info` | `info` | N/A | ⚠️ Review |
| `parameters` | `inputs` | `parameters` | ✅ YES |
| N/A | `outputs` | `response` | ⚠️ Review |

### 2.2 Configuration Structure

**UTCP v1.0 Configuration**:
```yaml
manual_call_templates:
  - name: service_name
    call_template_type: http  # Not provider_type
    url: https://...
    
load_variables_from:
  - variable_loader_type: dotenv
    env_file_path: .env
```

**Current ExUtcp Configuration**:
```elixir
config = %{
  providers_file_path: "providers.yaml",
  variables: %{},
  load_variables_from: [...]  # ✅ Already aligned
}

# Providers are called "providers", not "manual_call_templates"
```

**Required Changes**:
1. ✅ Rename `providers` to `manual_call_templates` in configuration
2. ✅ Rename `provider_type` to `call_template_type` in provider definitions
3. ✅ Update configuration parsing to use new terminology
4. ⚠️ Keep backward compatibility option

---

## 3. Manual Format Changes

### 3.1 Manual Structure

**UTCP v1.0 Manual**:
```json
{
  "manual_version": "1.0.0",
  "utcp_version": "0.2.0",
  "info": {
    "title": "API Title",
    "version": "1.0.0",
    "description": "Description"
  },
  "tools": [
    {
      "name": "tool_name",
      "description": "Tool description",
      "inputs": { /* JSON Schema */ },      // Changed from "parameters"
      "outputs": { /* JSON Schema */ },     // New field
      "tool_call_template": { /* ... */ },  // Changed from "provider"
      "auth": { /* ... */ }
    }
  ]
}
```

**Current ExUtcp Manual/Tool Format**:
```elixir
%{
  name: "tool_name",
  description: "Tool description",
  parameters: %{},      # Should be "inputs"
  response: %{},        # Should be "outputs"
  provider: %{}         # Should be "tool_call_template"
}
```

**Required Changes**:
1. ✅ Add `manual_version` field
2. ✅ Add `utcp_version` field  
3. ✅ Rename `parameters` to `inputs` in tool definitions
4. ✅ Rename `response` to `outputs` in tool definitions
5. ✅ Rename `provider` to `tool_call_template` in tool definitions
6. ✅ Add `info` section with title, version, description
7. ✅ Update Types module with new structure

---

## 4. Call Template Changes

### 4.1 HTTP Call Template

**UTCP v1.0 HTTP Template**:
```json
{
  "call_template_type": "http",  // Not "provider_type"
  "url": "https://api.example.com/endpoint",
  "http_method": "POST",  // Not "method"
  "content_type": "application/json",
  "auth": {
    "auth_type": "api_key",
    "api_key": "Bearer ${API_KEY}",
    "var_name": "Authorization",
    "location": "header"
  },
  "headers": {},
  "body_field": "body",
  "header_fields": []
}
```

**Current ExUtcp HTTP Provider**:
```elixir
%{
  type: :http,           # Should be call_template_type
  url: "...",
  http_method: "POST",   # ✅ Already correct
  headers: %{},
  auth: %{},
  body_field: nil,
  header_fields: []
}
```

**Required Changes**:
1. ✅ Use `call_template_type` key instead of `type`
2. ✅ Ensure all HTTP template fields match v1.0 spec
3. ✅ Update HTTP transport to use new field names

### 4.2 CLI Call Template

**UTCP v1.0 CLI Template**:
```json
{
  "call_template_type": "cli",
  "commands": [
    {
      "command": "cd /app",
      "append_to_final_output": false  // New feature
    },
    {
      "command": "python script.py UTCP_ARG_input_UTCP_END",
      "append_to_final_output": true
    }
  ],
  "working_dir": "/app",
  "env_vars": {}
}
```

**Current ExUtcp CLI Provider**:
```elixir
%{
  type: :cli,
  command_name: "...",
  working_dir: nil,
  env_vars: %{}
}
```

**Required Changes**:
1. ✅ Support `commands` array (multiple sequential commands)
2. ✅ Implement `append_to_final_output` flag per command
3. ✅ Support `UTCP_ARG_*_UTCP_END` argument placeholder format
4. ✅ Support `$CMD_N_OUTPUT` for referencing previous command outputs
5. ✅ Update CLI transport implementation

---

## 5. Authentication Changes

### 5.1 Auth Structure

**UTCP v1.0 Auth**:
```json
{
  "auth": {
    "auth_type": "api_key",  // or "basic", "oauth2"
    "api_key": "${TOKEN}",
    "var_name": "Authorization",
    "location": "header"  // or "query"
  }
}
```

**Current ExUtcp Auth**:
```elixir
%{
  type: "api_key",
  api_key: "...",
  location: "header",
  var_name: "X-Api-Key"
}
```

**Required Changes**:
1. ✅ Use `auth_type` instead of `type`
2. ✅ Ensure field names match v1.0 spec
3. ✅ Update authentication handling code

### 5.2 Selective Authentication

**UTCP v1.0 Feature**:
```json
{
  "auth_tools": {  // For OpenAPI-generated tools
    "auth_type": "api_key",
    "api_key": "Bearer ${TOOL_API_KEY}",
    "var_name": "Authorization",
    "location": "header"
  }
}
```

**Current ExUtcp**:
- ❌ No explicit `auth_tools` support
- ⚠️ May be handling this differently

**Required Changes**:
1. ✅ Implement `auth_tools` for OpenAPI converter
2. ✅ Apply authentication only to endpoints requiring auth (per OpenAPI spec)
3. ✅ Separate auth for call template vs generated tools

---

## 6. Error Handling Changes

### 6.1 Exception Types

**UTCP v1.0 Exceptions**:
- `UtcpError` - Base exception
- `ToolNotFoundError` - Tool not found
- `AuthenticationError` - Auth failures
- `ToolCallError` - Tool execution failures

**Current ExUtcp Error Handling**:
- Standard Elixir {:ok, result} / {:error, reason} pattern
- No specific exception types

**Required Changes**:
1. ⚠️ Consider adding custom exception modules
2. ✅ OR keep Elixir's {:ok, result} / {:error, reason} pattern (idiomatic)
3. ✅ Ensure error messages are descriptive and match v1.0 categories

**Recommendation**: Keep Elixir pattern (more idiomatic than exceptions)

---

## 7. Client API Changes

### 7.1 Client Creation

**UTCP v1.0**:
```python
client = await UtcpClient.create(config={...})
```

**Current ExUtcp**:
```elixir
{:ok, client} = Client.start_link(config)
```

**Required Changes**:
- ✅ No change needed (Elixir pattern is correct)
- Pattern difference is language-specific

### 7.2 Tool Calling

**UTCP v1.0**:
```python
result = await client.call_tool("provider:tool", args)
```

**Current ExUtcp**:
```elixir
{:ok, result} = Client.call_tool(client, "provider:tool", args)
```

**Required Changes**:
- ✅ Already supports `provider:tool` format
- ✅ No change needed

---

## 8. Ecto Integration for Validation

### 8.1 Why Ecto?

[Ecto](https://hexdocs.pm/ecto) is Elixir's equivalent to Python's Pydantic:
- ✅ Schema validation
- ✅ Embedded schemas
- ✅ Changesets for validation
- ✅ Type casting
- ✅ Custom validators
- ✅ JSON schema generation (with extensions)

### 8.2 Implementation Plan

**Add Ecto Dependency**:
```elixir
{:ecto, "~> 3.11"}
```

**Create Ecto Schemas**:

1. **Manual Schema**:
```elixir
defmodule ExUtcp.Schemas.Manual do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :manual_version, :string, default: "1.0.0"
    field :utcp_version, :string, default: "0.2.0"
    
    embeds_one :info, Info do
      field :title, :string
      field :version, :string
      field :description, :string
    end
    
    embeds_many :tools, Tool do
      field :name, :string
      field :description, :string
      field :inputs, :map
      field :outputs, :map
      field :tool_call_template, :map
      field :auth, :map
    end
  end

  def changeset(manual, attrs) do
    manual
    |> cast(attrs, [:manual_version, :utcp_version])
    |> cast_embed(:info, required: true)
    |> cast_embed(:tools, required: true)
    |> validate_required([:manual_version, :utcp_version])
  end
end
```

2. **Call Template Schema**:
```elixir
defmodule ExUtcp.Schemas.CallTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :call_template_type, :string  # Not provider_type
    field :url, :string
    field :http_method, :string
    field :auth, :map
    # ... other fields
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :call_template_type, :url, :http_method])
    |> validate_required([:name, :call_template_type])
    |> validate_inclusion(:call_template_type, 
         ["http", "cli", "websocket", "grpc", "graphql", "mcp", "webrtc", "tcp", "udp"])
  end
end
```

---

## 9. Required Changes Summary

### High Priority (Breaking Changes)

1. **Configuration Terminology**:
   - ✅ Rename `providers` → `manual_call_templates`
   - ✅ Rename `provider_type` → `call_template_type`
   - ✅ Update Config module to use new terminology

2. **Tool Format**:
   - ✅ Rename `parameters` → `inputs`
   - ✅ Rename `response` → `outputs`
   - ✅ Rename tool's `provider` → `tool_call_template`
   - ✅ Update Types module

3. **Manual Format**:
   - ✅ Add `manual_version` field (default: "1.0.0")
   - ✅ Add `utcp_version` field (default: "0.2.0")
   - ✅ Add `info` section with title, version, description
   - ✅ Update manual parsing

4. **CLI Enhancements**:
   - ✅ Support multiple commands array
   - ✅ Implement `append_to_final_output` flag
   - ✅ Support `UTCP_ARG_*_UTCP_END` placeholders
   - ✅ Support `$CMD_N_OUTPUT` output referencing

5. **Authentication**:
   - ✅ Rename `type` → `auth_type` in auth maps
   - ✅ Implement `auth_tools` for OpenAPI selective auth
   - ✅ Update auth handling code

### Medium Priority (Enhancements)

6. **Ecto Integration**:
   - ✅ Add Ecto dependency
   - ✅ Create Ecto schemas for validation
   - ✅ Implement changesets for data validation
   - ✅ Use Ecto for runtime validation

7. **Error Handling**:
   - ⚠️ Consider custom error modules
   - ✅ OR keep {:ok, result} / {:error, reason} pattern
   - ✅ Ensure error categories match v1.0

8. **Variable Loaders**:
   - ✅ Support `variable_loader_type: dotenv`
   - ✅ Already have dotenv support, ensure format matches

### Low Priority (Nice to Have)

9. **HTTP Template Fields**:
   - ✅ Ensure all v1.0 fields are supported
   - ✅ Add missing fields if any

10. **Validation Tools**:
    - ✅ Add configuration validator
    - ✅ Add manual validator
    - ✅ Use Ecto changesets

---

## 10. Implementation Roadmap

### Phase 1: Terminology Alignment (v0.3.2)

**Tasks**:
1. Add Ecto dependency
2. Create backward-compatible config parser
3. Support both `providers` and `manual_call_templates`
4. Support both `provider_type` and `call_template_type`
5. Add deprecation warnings for old terminology
6. Update Types module with new field names

**Estimated Effort**: 2-3 days  
**Breaking**: No (backward compatible)

### Phase 2: Manual Format Update (v0.3.3)

**Tasks**:
1. Add `manual_version` and `utcp_version` fields
2. Add `info` section support
3. Update tool format (inputs, outputs, tool_call_template)
4. Create Ecto schemas for validation
5. Update OpenAPI converter output
6. Add migration helper functions

**Estimated Effort**: 2-3 days  
**Breaking**: No (backward compatible)

### Phase 3: CLI Enhancements (v0.3.4)

**Tasks**:
1. Support commands array
2. Implement `append_to_final_output`
3. Support `UTCP_ARG_*_UTCP_END` placeholders
4. Implement `$CMD_N_OUTPUT` referencing
5. Update CLI transport
6. Add comprehensive CLI tests

**Estimated Effort**: 3-4 days  
**Breaking**: No (additive)

### Phase 4: Authentication Enhancement (v0.3.5)

**Tasks**:
1. Rename `type` → `auth_type`
2. Implement `auth_tools` support
3. Update OpenAPI converter for selective auth
4. Update all transports for new auth format
5. Add auth migration helper

**Estimated Effort**: 2-3 days  
**Breaking**: No (backward compatible)

### Phase 5: Validation & Testing (v0.4.0)

**Tasks**:
1. Complete Ecto schema implementation
2. Add validation for all configurations
3. Add validation for all manuals
4. Create migration helpers
5. Comprehensive testing
6. Update documentation
7. Mark as UTCP v1.0 compliant

**Estimated Effort**: 3-4 days  
**Breaking**: No (v1.0 compliant release)

---

## 11. Detailed Implementation Guide

### 11.1 Add Ecto Dependency

```elixir
# mix.exs
defp deps do
  [
    # ... existing deps ...
    {:ecto, "~> 3.11"},
    {:jason, "~> 1.4"}  # Already have this
  ]
end
```

### 11.2 Create Ecto Schemas

**File**: `lib/ex_utcp/schemas/manual.ex`

```elixir
defmodule ExUtcp.Schemas.Manual do
  @moduledoc """
  Ecto schema for UTCP v1.0 manual format validation.
  Equivalent to Python Pydantic models.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :manual_version, :string, default: "1.0.0"
    field :utcp_version, :string, default: "0.2.0"
    
    embeds_one :info, Info, primary_key: false do
      field :title, :string
      field :version, :string
      field :description, :string
    end
    
    embeds_many :tools, Tool, primary_key: false do
      field :name, :string
      field :description, :string
      field :inputs, :map
      field :outputs, :map
      field :tool_call_template, :map
      field :auth, :map
    end
  end

  def changeset(manual \\ %__MODULE__{}, attrs) do
    manual
    |> cast(attrs, [:manual_version, :utcp_version])
    |> cast_embed(:info, required: true, with: &info_changeset/2)
    |> cast_embed(:tools, required: true, with: &tool_changeset/2)
    |> validate_required([:manual_version, :utcp_version])
    |> validate_format(:manual_version, ~r/^\d+\.\d+\.\d+$/)
  end

  defp info_changeset(info, attrs) do
    info
    |> cast(attrs, [:title, :version, :description])
    |> validate_required([:title, :version])
  end

  defp tool_changeset(tool, attrs) do
    tool
    |> cast(attrs, [:name, :description, :inputs, :outputs, :tool_call_template, :auth])
    |> validate_required([:name, :description, :inputs, :tool_call_template])
  end

  @doc """
  Validates a manual map and returns {:ok, valid_manual} or {:error, changeset}.
  """
  def validate(attrs) do
    changeset = changeset(attrs)
    
    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end
end
```

### 11.3 Create Migration Helper

**File**: `lib/ex_utcp/migration.ex`

```elixir
defmodule ExUtcp.Migration do
  @moduledoc """
  Migration helpers for upgrading from legacy format to UTCP v1.0.
  """

  @doc """
  Migrates v0.1-style configuration to v1.0 format.
  """
  def migrate_config(old_config) do
    %{
      manual_call_templates: migrate_providers(Map.get(old_config, :providers, [])),
      load_variables_from: Map.get(old_config, :load_variables_from, []),
      variables: Map.get(old_config, :variables, %{})
    }
  end

  @doc """
  Migrates providers to manual_call_templates.
  """
  def migrate_providers(providers) when is_list(providers) do
    Enum.map(providers, &migrate_provider/1)
  end

  defp migrate_provider(provider) do
    provider
    |> Map.put(:call_template_type, Map.get(provider, :type) || Map.get(provider, :provider_type))
    |> Map.delete(:type)
    |> Map.delete(:provider_type)
  end

  @doc """
  Migrates tool format to v1.0.
  """
  def migrate_tool(tool) do
    %{
      name: tool.name,
      description: Map.get(tool, :description, ""),
      inputs: Map.get(tool, :parameters, Map.get(tool, :inputs, %{})),
      outputs: Map.get(tool, :response, Map.get(tool, :outputs, %{})),
      tool_call_template: Map.get(tool, :provider, Map.get(tool, :tool_call_template, %{})),
      auth: Map.get(tool, :auth)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  @doc """
  Migrates manual to v1.0 format.
  """
  def migrate_manual(old_manual) do
    %{
      manual_version: "1.0.0",
      utcp_version: "0.2.0",
      info: %{
        title: get_in(old_manual, [:provider_info, :name]) || "Migrated Manual",
        version: get_in(old_manual, [:provider_info, :version]) || "1.0.0",
        description: get_in(old_manual, [:provider_info, :description]) || ""
      },
      tools: Enum.map(Map.get(old_manual, :tools, []), &migrate_tool/1)
    }
  end

  @doc """
  Validates if configuration is v1.0 compliant.
  """
  def v1_compliant?(config) do
    has_manual_call_templates = Map.has_key?(config, :manual_call_templates)
    
    if has_manual_call_templates do
      templates = config.manual_call_templates
      Enum.all?(templates, fn template ->
        Map.has_key?(template, :call_template_type)
      end)
    else
      false
    end
  end
end
```

### 11.4 Update Config Module

**File**: `lib/ex_utcp/config.ex`

```elixir
defmodule ExUtcp.Config do
  # ... existing code ...

  @doc """
  Creates a new configuration with backward compatibility.
  Accepts both v0.1 (providers) and v1.0 (manual_call_templates) formats.
  """
  def new(opts \\ %{}) do
    config = %{
      # Support both old and new terminology
      manual_call_templates: get_call_templates(opts),
      load_variables_from: Keyword.get(opts, :load_variables_from, []),
      variables: Keyword.get(opts, :variables, %{})
    }
    
    # Migrate if needed
    if ExUtcp.Migration.v1_compliant?(config) do
      config
    else
      ExUtcp.Migration.migrate_config(config)
    end
  end

  defp get_call_templates(opts) do
    # Try v1.0 format first
    cond do
      Map.has_key?(opts, :manual_call_templates) ->
        Map.get(opts, :manual_call_templates)
      
      # Fall back to v0.1 format
      Map.has_key?(opts, :providers) ->
        IO.warn("Using deprecated 'providers' key. Please use 'manual_call_templates' instead.")
        ExUtcp.Migration.migrate_providers(Map.get(opts, :providers))
      
      true ->
        []
    end
  end
end
```

---

## 12. Testing Requirements

### 12.1 New Tests Needed

1. **Ecto Schema Tests**:
   - Manual schema validation
   - Call template schema validation
   - Changeset error handling

2. **Migration Tests**:
   - Config migration v0.1 → v1.0
   - Manual migration v0.1 → v1.0
   - Tool migration
   - Provider → CallTemplate migration

3. **Backward Compatibility Tests**:
   - Old format still works
   - Deprecation warnings shown
   - Migration is automatic

4. **v1.0 Compliance Tests**:
   - New format validates correctly
   - All required fields present
   - Field names match spec

### 12.2 Test Files to Create

```
test/ex_utcp/schemas/manual_test.exs
test/ex_utcp/schemas/call_template_test.exs
test/ex_utcp/migration_test.exs
test/ex_utcp/v1_compliance_test.exs
```

---

## 13. Documentation Updates

### 13.1 Documents to Update

1. **README.md**:
   - Add UTCP v1.0 compliance badge
   - Update terminology throughout
   - Add migration guide reference

2. **CHANGELOG.md**:
   - Add v1.0 alignment entries
   - Document breaking changes
   - Document new features

3. **Migration Guide**:
   - Create `docs/MIGRATION_GUIDE.md`
   - Document v0.1 → v1.0 changes
   - Provide code examples
   - Reference UTCP official guide

4. **API Documentation**:
   - Update @doc comments
   - Update examples
   - Update typespecs

---

## 14. Backward Compatibility Strategy

### 14.1 Approach

**Option 1: Automatic Migration (Recommended)**:
- Accept both old and new formats
- Automatically migrate internally
- Show deprecation warnings
- Seamless for users

**Option 2: Breaking Change**:
- Require v1.0 format
- Provide migration tool
- Clear upgrade path
- Better long-term

**Recommendation**: Use **Option 1** for smooth transition

### 14.2 Implementation

```elixir
defmodule ExUtcp.Config do
  def new(opts) do
    config = if has_old_format?(opts) do
      IO.warn("""
      Deprecated configuration format detected.
      Please update to UTCP v1.0 format:
      - Use 'manual_call_templates' instead of 'providers'
      - Use 'call_template_type' instead of 'provider_type'
      
      See migration guide: docs/MIGRATION_GUIDE.md
      """)
      
      ExUtcp.Migration.migrate_config(opts)
    else
      opts
    end
    
    struct(__MODULE__, config)
  end

  defp has_old_format?(opts) do
    Map.has_key?(opts, :providers) and not Map.has_key?(opts, :manual_call_templates)
  end
end
```

---

## 15. Benefits of UTCP v1.0 Alignment

### 15.1 Specification Compliance

- ✅ Official UTCP v1.0 compatibility
- ✅ Interoperability with Python implementation
- ✅ Follows standard terminology
- ✅ Better ecosystem integration

### 15.2 Improved Validation

- ✅ Ecto schemas provide runtime validation
- ✅ Clear error messages
- ✅ Type safety
- ✅ Better developer experience

### 15.3 Future-Proofing

- ✅ Aligned with official spec evolution
- ✅ Easier to adopt future UTCP updates
- ✅ Community alignment

---

## 16. Migration Checklist

### For ExUtcp Developers

- [ ] Add Ecto dependency
- [ ] Create Ecto schemas (Manual, CallTemplate, Tool, Auth)
- [ ] Implement Migration module with helpers
- [ ] Update Config module with backward compatibility
- [ ] Update Types module with new terminology
- [ ] Update all transports to use new terminology
- [ ] Update OpenAPI converter
- [ ] Add `auth_tools` support
- [ ] Enhance CLI transport (commands array, output referencing)
- [ ] Create comprehensive tests
- [ ] Update documentation
- [ ] Create migration guide
- [ ] Add deprecation warnings
- [ ] Test backward compatibility
- [ ] Bump to v0.4.0 (UTCP v1.0 compliant)

### For ExUtcp Users

- [ ] Review UTCP v1.0 migration guide
- [ ] Test current code with ExUtcp v0.3.1
- [ ] Plan migration to v1.0 terminology
- [ ] Update configurations when ready
- [ ] Update manual formats when ready
- [ ] Test thoroughly
- [ ] Update to ExUtcp v0.4.0 when released

---

## 17. Risks and Mitigation

### 17.1 Risks

1. **Breaking Changes**: Old code may break
   - **Mitigation**: Backward compatibility with auto-migration

2. **Performance Impact**: Ecto validation overhead
   - **Mitigation**: Optional validation, caching

3. **Complexity**: More code to maintain
   - **Mitigation**: Clear separation, good tests

4. **User Confusion**: Two formats supported
   - **Mitigation**: Clear deprecation warnings, migration guide

### 17.2 Migration Testing

```elixir
# Test both formats work
test "supports v0.1 format with migration" do
  old_config = %{
    providers: [
      %{name: "test", type: :http, url: "https://api.example.com"}
    ]
  }
  
  config = Config.new(old_config)
  assert config.manual_call_templates != nil
end

test "supports v1.0 format natively" do
  new_config = %{
    manual_call_templates: [
      %{name: "test", call_template_type: "http", url: "https://api.example.com"}
    ]
  }
  
  config = Config.new(new_config)
  assert config.manual_call_templates != nil
end
```

---

## 18. Conclusion

### Current Status

ExUtcp is **partially aligned** with UTCP v1.0:
- ✅ Core concepts match
- ✅ Functionality is compatible
- ❌ Terminology needs update
- ❌ Manual format needs update
- ❌ Some v1.0 features missing (CLI enhancements, auth_tools)

### Recommended Path Forward

1. **Immediate** (v0.3.2): Add Ecto, create schemas
2. **Short-term** (v0.3.3-0.3.5): Implement backward-compatible changes
3. **Medium-term** (v0.4.0): Full UTCP v1.0 compliance
4. **Long-term**: Maintain alignment with spec updates

### Impact Assessment

- **Development Effort**: 10-15 days total
- **Breaking Changes**: Minimal (with backward compatibility)
- **User Impact**: Low (automatic migration)
- **Value**: High (spec compliance, better validation)

**Recommendation**: Proceed with phased implementation for UTCP v1.0 alignment.

---

## References

1. [UTCP v1.0 Migration Guide](https://www.utcp.io/migration-v0.1-to-v1.0)
2. [UTCP Official Website](https://www.utcp.io/)
3. [Python UTCP Repository](https://github.com/universal-tool-calling-protocol/python-utcp)
4. [Ecto Documentation](https://hexdocs.pm/ecto)
5. [Ecto Schema Guide](https://hexdocs.pm/ecto/Ecto.Schema.html)

---

**Document Version**: 1.0  
**Last Updated**: October 5, 2025  
**Next Review**: After each UTCP spec update
