# codex.sh

This is a one-stop installer and manager for the Codex CLI and its model configurations on Linux.

It supports:
- Installing/uninstalling the Codex CLI
- Downloading and switching LLM model configs
- Updating the CLI and self-upgrading this script
- Showing install status and versions

## Prerequisites

- Linux environment. If you’re on Windows, use WSL (Ubuntu recommended).
- bash, curl, ln, and sha256sum available (present on most distros).
- Network access to your Artifactory (see configuration below).

## Quick start

```bash
# Installs CLI and default model (kimi-k2)
./codex.sh install

# Or pick a model explicitly
./codex.sh install kimi-k2

# Apply PATH/API key changes made to ~/.bashrc
source ~/.bashrc

# Verify
./codex.sh info
./codex.sh version
```

Tip: Update the placeholder key in ~/.bashrc (LITELLM_API_KEY=sk-1234) to your real API key.

## Common commands

```bash
# Help and version
./codex.sh help
./codex.sh version
./codex.sh info

# Update the Codex CLI (re-install flows)
./codex.sh update

# Self-upgrade this script from Artifactory
./codex.sh upgrade

# List models and interactively pick one
./codex.sh model

# Set a model
./codex.sh model <model_name>

# List MCP servers and interactively pick one
./codex.sh mcp

# Set MCP server
./codex.sh mcp <mcp_name>

# Uninstall everything the script installed/added
./codex.sh uninstall
```

## MCP Server Updates

MCP (Model Context Protocol) server configurations are automatically managed:

- **Automatic Updates**: MCP configurations are downloaded and updated whenever you run:
  - `./codex.sh install` - Downloads MCP configurations during initial setup
  - `./codex.sh update` - Refreshes all components including MCP configurations
- **Configuration Location**: MCP configurations are stored in `~/.codex/mcp_servers.toml`
- **Version Management**: The `update` command ensures you have the latest MCP server definitions from the repository
- **No Manual Intervention**: You don't need to separately update MCP configurations - they're included in the standard update process

If you encounter issues with MCP servers or need the latest configurations, simply run `./codex.sh update`.

## MCP Server Configuration

The script supports Model Context Protocol (MCP) servers, which provide additional tools and capabilities to Codex:

- MCP server configurations are automatically downloaded during `install` or `update`
- Configurations are stored in `~/.codex/mcp_servers.toml`
- Use `./codex.sh mcp` to list available MCP configurations
- Use `./codex.sh mcp <mcp_name>` to apply a configuration
- MCP settings are merged into your active `config.toml`
- Supported MCP types include STDIO servers (Docker-based) and HTTP servers
- MCP configurations are automatically updated when running `./codex.sh update`

Example MCP servers:
- **code2prompt**: Converts codebase to prompts via Docker
- **docker**: Provides containerized project operations
- **custom_api**: HTTP-based MCP servers with bearer token authentication

**Important**: After setting an MCP configuration, ensure you set any required environment variables (like API tokens) in your shell environment.

## WSL notes (Windows Subsystem for Linux)

- Run the script inside your Linux (WSL) distro shell, not Windows PowerShell/cmd.
- ~/.bashrc refers to your Linux home. Changes won't affect Windows shells.
- The script supports Linux only; running from Windows directly will show a "only supports Linux" message.

## Troubleshooting

- ERROR: Only supports Linux system
	- Run in a Linux shell (or WSL). macOS/Windows shells aren’t supported by this script version.

- ERROR: Unable to query configuration information / downloads fail
	- Verify ARTIFACTORY_HOST/USER/PASS and network access.
	- Ensure the repository and paths exist: codex, codex.sh, config.toml.<model>.

- INFO: ~/.bashrc file not found
	- Create it or set BASHRC_PATH to your shell init file, then re-run install.

- codex: command not found after install
	- Source your shell: `source ~/.bashrc`.
	- Ensure ~/.local/bin is on PATH and the codex file exists/executable.

- Model not listed or selection fails
	- Re-run `./codex.sh update` to re-download models.

- MCP configuration issues
	- Ensure you've run `./codex.sh update` to download latest MCP configurations.
	- Check that required environment variables (API tokens, etc.) are set.
	- MCP servers require their respective tools (Docker for STDIO servers, network access for HTTP servers).
	- Use `./codex.sh mcp` to see available configurations.
	- If MCP configurations seem outdated, run `./codex.sh update` to refresh them from the repository.

- Self-upgrade issues
	- `./codex.sh upgrade` compares SHA256 with the remote. If verification fails, the script restores your previous version and exits.

## License

This project is licensed under the Apache License - see the LICENSE file for details.
