# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Security Measures

### Static Analysis

This project uses [Sobelow](https://github.com/nccgroup/sobelow) for security-focused static analysis.

### Known Sobelow Findings (Mitigated)

The following Sobelow findings are present but have been properly mitigated:

#### 1. Directory Traversal in File.read (Low Confidence)

**Files:**
- `lib/ex_utcp/client.ex:252`
- `lib/ex_utcp/openapi_converter.ex:106`

**Mitigation:**
Both instances implement comprehensive path validation using `validate_file_path/1` and `validate_openapi_file_path/1` functions that:
- Resolve paths to absolute paths using `Path.expand/1`
- Check for directory traversal patterns (`../`, `..\\`, `..`)
- Verify file existence before reading
- Validate file extensions (OpenAPI files only)
- Return `{:error, :invalid_path}` for suspicious paths

```elixir
defp validate_file_path(file_path) do
  abs_path = Path.expand(file_path)
  
  cond do
    String.contains?(file_path, ["../", "..\\"]) ->
      {:error, :invalid_path}
    
    String.contains?(abs_path, "..") ->
      {:error, :invalid_path}
    
    not File.exists?(abs_path) ->
      {:error, :file_not_found}
    
    true ->
      {:ok, abs_path}
  end
end
```

#### 2. Command Injection via System (Low Confidence)

**Files:**
- `lib/ex_utcp/transports/cli.ex:96`
- `lib/ex_utcp/transports/cli.ex:132`

**Mitigation:**
Command paths are validated using `validate_command_path/1` which implements multiple security checks:
- Detects shell metacharacters (`;`, `&`, `|`, `` ` ``, `$`, `(`, `)`, `<`, `>`)
- Prevents command chaining (`&&`, `||`, `;`, `|`)
- Whitelists only safe characters: `[a-zA-Z0-9_\-\.\/]`
- Checks for directory traversal in command paths
- Rejects empty command paths
- Returns `{:error, reason}` for invalid paths

```elixir
defp validate_command_path(cmd_path) do
  cond do
    Regex.match?(~r/[;&|`$()<>]/, cmd_path) ->
      {:error, "Invalid command path: contains shell metacharacters"}
    
    String.contains?(cmd_path, ["&&", "||", ";", "|"]) ->
      {:error, "Invalid command path: contains command chaining"}
    
    not Regex.match?(~r/^[a-zA-Z0-9_\-\.\/]+$/, cmd_path) ->
      {:error, "Invalid command path: contains unsafe characters"}
    
    String.contains?(cmd_path, "..") ->
      {:error, "Invalid command path: contains directory traversal"}
    
    String.trim(cmd_path) == "" ->
      {:error, "Invalid command path: empty path"}
    
    true ->
      {:ok, cmd_path}
  end
end
```

#### 3. DOS via String.to_atom (Low Confidence)

**Files:**
- `lib/ex_utcp/transports/websocket.ex:274`
- `lib/ex_utcp/transports/websocket/testable.ex:317`

**Mitigation:**
Header conversion uses `safe_string_to_atom/1` which:
- First attempts `String.to_existing_atom/1` (safe, no new atoms created)
- Falls back to lowercase version with `String.to_existing_atom/1`
- Returns the original string if atom doesn't exist (prevents atom table exhaustion)
- Never creates new atoms dynamically from user input

```elixir
defp safe_string_to_atom(string) do
  try do
    String.to_existing_atom(string)
  rescue
    ArgumentError ->
      try do
        String.to_existing_atom(String.downcase(string))
      rescue
        ArgumentError -> string
      end
  end
end
```

### Security Testing

The project includes comprehensive security tests in `test/ex_utcp/security_test.exs` that verify:

- **Directory Traversal Prevention**: Tests for `../` and `..\\` patterns
- **OpenAPI File Validation**: Tests for file extension and path validation
- **Command Injection Prevention**: Tests for shell metacharacters and command chaining
- **String.to_atom DOS Prevention**: Tests to ensure atom table isn't exhausted
- **Input Sanitization**: Tests for special characters in provider names
- **Environment Variable Injection**: Tests for env var injection attempts
- **Path Canonicalization**: Tests for proper path resolution
- **Error Message Safety**: Tests to ensure errors don't leak sensitive information

Run security tests with:
```bash
mix test test/ex_utcp/security_test.exs
```

### Security Best Practices

1. **Input Validation**: All external inputs (file paths, commands, headers) are validated before use
2. **Atom Safety**: Never create atoms from untrusted user input
3. **Path Traversal Prevention**: File paths are validated and resolved to absolute paths
4. **Command Injection Prevention**: Command paths are validated against a whitelist pattern
5. **Error Handling**: Security-related errors are properly handled and logged
6. **Comprehensive Testing**: 16+ security-focused tests ensure mitigations work correctly

## Reporting a Vulnerability

If you discover a security vulnerability, please email security@example.com (replace with actual contact).

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours and provide a timeline for fixes.

## Security Updates

Security updates are released as patch versions and documented in the CHANGELOG.md file.

