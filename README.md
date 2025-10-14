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

# Uninstall everything the script installed/added
./codex.sh uninstall
```

## WSL notes (Windows Subsystem for Linux)

- Run the script inside your Linux (WSL) distro shell, not Windows PowerShell/cmd.
- ~/.bashrc refers to your Linux home. Changes won’t affect Windows shells.
- The script supports Linux only; running from Windows directly will show a “only supports Linux” message.

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

- Self-upgrade issues
	- `./codex.sh upgrade` compares SHA256 with the remote. If verification fails, the script restores your previous version and exits.

## License

This project is licensed under the Apache License - see the LICENSE file for details.
