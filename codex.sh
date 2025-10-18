#!/bin/bash

# Script version
SCRIPT_VERSION="1.1.0-rc.1"

# System configuration
SUPPORTED_OS="Linux"

# Artifactory configuration
ARTIFACTORY_HOST="http://locahost:8080"
ARTIFACTORY_CODEX="codex"
ARTIFACTORY_USER="your_name"
ARTIFACTORY_PASS="your_pass"
ARTIFACTORY_URL="${ARTIFACTORY_HOST}/${ARTIFACTORY_CODEX}"

# Model configuration
DEFAULT_MODEL="kimi-k2"

# Initialize configuration
init_config() {
    BASHRC_PATH="${BASHRC_PATH:-${HOME}/.bashrc}"
    INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
    CONFIG_DIR="${CONFIG_DIR:-${HOME}/.codex}"

    if [ -z "${INSTALL_FILE}" ]; then
        INSTALL_FILE="${INSTALL_DIR}/codex"
    fi

    if [ -z "${CONFIG_FILE}" ]; then
        CONFIG_FILE="${CONFIG_DIR}/config.toml"
    fi
}

# Initialize configuration
init_config

# Check if already installed
is_installed() {
    if [ ! -f "${INSTALL_FILE}" ]; then
        return 1
    fi

    if [ ! -f "${CONFIG_FILE}" ]; then
        return 1
    fi

    return 0
}

# Check system version
check_system() {
    local current_os

    current_os=$(uname -s)
    if [[ "$current_os" == "${SUPPORTED_OS}" ]]; then
        return 0
    else
        echo -e "ERROR: Current system is ${current_os}, only supports ${SUPPORTED_OS}"
        return 1
    fi
}

# Query configuration
query_config() {
    local response

    response=$(curl -s -u "${ARTIFACTORY_USER}":"${ARTIFACTORY_PASS}" "${ARTIFACTORY_HOST}/api/storage/${ARTIFACTORY_CODEX}")
    if [ $? -eq 0 ]; then
        echo "$response" | grep -o '"/config\.toml\.[^"]*"' | sed 's|"/config\.toml\.\([^"]*\)"|\1|' | sort
    else
        echo -e "ERROR: Unable to query configuration information"
        return 1
    fi
}

# Query MCP
query_mcp() {
    local response

    response=$(curl -s -u "${ARTIFACTORY_USER}":"${ARTIFACTORY_PASS}" "${ARTIFACTORY_HOST}/api/storage/${ARTIFACTORY_CODEX}")
    if [ $? -eq 0 ]; then
        if echo "$response" | grep -q '"/mcp_servers\.toml"'; then
            echo "mcp_servers.toml"
            return 0
        else
            echo -e "ERROR: MCP configuration file not found in repository"
            return 1
        fi
    else
        echo -e "ERROR: Unable to query MCP configuration information"
        return 1
    fi
}

# Query script
query_script() {
    local response
    local sha256_value

    response=$(curl -s -u "${ARTIFACTORY_USER}":"${ARTIFACTORY_PASS}" "${ARTIFACTORY_HOST}/api/storage/${ARTIFACTORY_CODEX}/codex.sh")
    if [ $? -ne 0 ]; then
        echo -e "ERROR: Command execution failed" >&2
        return 1
    fi

    if [ -z "$response" ]; then
        echo -e "ERROR: Empty response received" >&2
        return 1
    fi

    sha256_value=$(echo "$response" | grep -o '"sha256"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"sha256"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
    if [ -z "$sha256_value" ]; then
        echo -e "ERROR: Unable to get SHA256" >&2
        return 1
    fi

    echo "$sha256_value"
}

# Update Codex
update_codex() {
    if [ ! -d "${INSTALL_DIR}" ]; then
        mkdir -p "${INSTALL_DIR}"
    fi

    if curl -k -u "${ARTIFACTORY_USER}":"${ARTIFACTORY_PASS}" -L "${ARTIFACTORY_URL}/codex" -o "${INSTALL_FILE}" -s; then
        chmod +x "${INSTALL_FILE}"
        echo -e "DONE: Codex saved to: ${INSTALL_FILE}"
    else
        echo -e "ERROR: Failed to download Codex"
        exit 1
    fi

    if [ -f "${BASHRC_PATH}" ]; then
        if ! grep -q "# Added by codex.sh" "${BASHRC_PATH}"; then
            echo "" >> "${BASHRC_PATH}"
            echo "# Added by codex.sh" >> "${BASHRC_PATH}"
            echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "${BASHRC_PATH}"
            echo "export LITELLM_API_KEY=sk-1234" >> "${BASHRC_PATH}"
            echo -e "DONE: Added ${INSTALL_DIR} to PATH"
            echo -e "DONE: Added LITELLM_API_KEY to PATH"
        else
            echo -e "INFO: PATH already contains ${INSTALL_DIR}"
        fi
    else
        echo -e "INFO: ~/.bashrc file not found"
    fi
}

# Update Model
update_model() {
    local available_models

    if [ ! -d "${CONFIG_DIR}" ]; then
        mkdir -p "${CONFIG_DIR}"
    fi

    available_models=$(query_config)
    if [ $? -ne 0 ] || [ -z "$available_models" ]; then
        exit 1
    fi

    for item in $available_models; do
        local config_file="${CONFIG_DIR}/config.toml.${item}"
        if curl -k -u "${ARTIFACTORY_USER}":"${ARTIFACTORY_PASS}" -L "${ARTIFACTORY_URL}/config.toml.$item" -o "$config_file" -s; then
            echo -e "DONE: Model configuration $item saved to: $config_file"
        else
            echo -e "ERROR: Failed to download model configuration $item"
        fi
    done
}

# Update MCP
update_mcp() {
    if [ ! -d "${CONFIG_DIR}" ]; then
        mkdir -p "${CONFIG_DIR}"
    fi

    local mcp_config_file="${CONFIG_DIR}/mcp_servers.toml"

    if curl -k -u "${ARTIFACTORY_USER}":"${ARTIFACTORY_PASS}" -L "${ARTIFACTORY_URL}/mcp_servers.toml" -o "$mcp_config_file" -s; then
        echo -e "DONE: MCP configuration saved to: $mcp_config_file"
    else
        echo -e "ERROR: Failed to download MCP configuration"
        return 1
    fi
}

# Update Agent
update_agent() {
    # TODO: FIXME
    echo -e "INFO: Agent update not supported"
}

# Set Model
set_model() {
    if [ -z "$1" ]; then
        echo -e "ERROR: Model name is required"
        return 1
    fi

    if [ -f "${CONFIG_DIR}/config.toml.${1}" ]; then
        ln -sf "${CONFIG_DIR}/config.toml.${1}" "${CONFIG_FILE}"
        echo -e "DONE: Model configuration ${1} linked to: ${CONFIG_FILE}"
        return 0
    else
        echo -e "ERROR: Model configuration file not found: ${CONFIG_DIR}/config.toml.${1}"
        echo -e "\033[32mINFO: Run 'codex.sh model' to see available models or 'codex.sh update' to download model configurations\033[0m"
        return 1
    fi
}

# Set MCP
set_mcp() {
    local mcp_servers="$1"
    local temp_config

    if [ -z "$mcp_servers" ]; then
        echo -e "ERROR: MCP server name(s) required"
        return 1
    fi

    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "ERROR: Main configuration file not found: ${CONFIG_FILE}"
        echo -e "INFO: Run 'codex.sh model' to set a model first"
        return 1
    fi

    local mcp_config_file="${CONFIG_DIR}/mcp_servers.toml"

    if [ ! -f "$mcp_config_file" ]; then
        echo -e "ERROR: MCP configuration file not found: $mcp_config_file"
        echo -e "\033[32mINFO: Run 'codex.sh update' to download MCP configuration\033[0m"
        return 1
    fi

    temp_config="/tmp/codex_config_$(date +%s).toml"

    # If CONFIG_FILE is a symlink, resolve it to the actual file and preserve the symlink
    local actual_config_file="${CONFIG_FILE}"
    if [ -L "${CONFIG_FILE}" ]; then
        actual_config_file=$(readlink -f "${CONFIG_FILE}")
    fi

    # Remove existing MCP server configurations completely
    # Copy everything before the first [mcp_servers.* section
    # Skip orphaned MCP configuration lines (command, args, env, etc.)
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[mcp_servers\. ]]; then
            break
        # Skip orphaned MCP config lines that might appear before any section header
        elif [[ "$line" =~ ^(command|args|env|enabled|startup_timeout_sec|tool_timeout_sec)[[:space:]]*= ]]; then
            continue
        else
            echo "$line" >> "$temp_config"
        fi
    done < "${actual_config_file}"

    # Parse comma-separated MCP server names
    IFS=',' read -ra MCP_ARRAY <<< "$mcp_servers"

    # Extract and append requested MCP server configurations
    for mcp_name in "${MCP_ARRAY[@]}"; do
        mcp_name=$(echo "$mcp_name" | xargs)  # Trim whitespace

        if grep -q "^\[mcp_servers\.${mcp_name}\]" "$mcp_config_file"; then
            echo "" >> "$temp_config"
            # Extract the specific MCP server section and set enabled = true
            local in_section=0
            local section_started=0
            while IFS= read -r line; do
                if [[ "$line" =~ ^\[mcp_servers\.${mcp_name}\]$ ]]; then
                    in_section=1
                    section_started=0
                    echo "$line" >> "$temp_config"
                elif [ $in_section -eq 1 ]; then
                    if [[ "$line" =~ ^\[.*\]$ ]]; then
                        # Hit next section, stop
                        break
                    elif [[ "$line" =~ ^#.*MCP[[:space:]]Server ]] && [ $section_started -eq 1 ]; then
                        # Hit comment line for next MCP server section, stop
                        break
                    elif [[ "$line" =~ ^enabled[[:space:]]*= ]]; then
                        # Always set enabled = true for selected servers
                        echo "enabled = true" >> "$temp_config"
                        section_started=1
                    else
                        echo "$line" >> "$temp_config"
                        # Mark that we've started writing content (not just the header)
                        if [[ ! "$line" =~ ^[[:space:]]*$ ]] && [[ ! "$line" =~ ^# ]]; then
                            section_started=1
                        fi
                    fi
                fi
            done < "$mcp_config_file"
            echo -e "INFO: Added MCP server: $mcp_name"
        else
            echo -e "WARNING: MCP server '$mcp_name' not found in configuration"
        fi
    done

    mv "$temp_config" "${actual_config_file}"
    echo -e "DONE: MCP configuration applied to: ${CONFIG_FILE}"
    echo -e "INFO: Make sure to set required environment variables for your MCP servers"
}

# Disable all MCP servers
disable_all_mcp() {
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "ERROR: Main configuration file not found: ${CONFIG_FILE}"
        return 1
    fi

    local temp_config
    temp_config="/tmp/codex_config_$(date +%s).toml"

    # If CONFIG_FILE is a symlink, resolve it to the actual file and preserve the symlink
    local actual_config_file="${CONFIG_FILE}"
    if [ -L "${CONFIG_FILE}" ]; then
        actual_config_file=$(readlink -f "${CONFIG_FILE}")
    fi

    # Remove all MCP server configurations completely
    # Copy everything before the first [mcp_servers.* section
    # Skip orphaned MCP configuration lines (command, args, env, etc.)
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[mcp_servers\. ]]; then
            break
        # Skip orphaned MCP config lines that might appear before any section header
        elif [[ "$line" =~ ^(command|args|env|enabled|startup_timeout_sec|tool_timeout_sec)[[:space:]]*= ]]; then
            continue
        else
            echo "$line" >> "$temp_config"
        fi
    done < "${actual_config_file}"

    mv "$temp_config" "${actual_config_file}"
    echo -e "INFO: All MCP servers have been disabled"
    return 0
}

# Set Agent
set_agent() {
    # TODO: FIXME
    echo -e "INFO: Agent setting not supported"
}

# Delete Codex
delete_codex() {
    if [ -f "${INSTALL_FILE}" ]; then
        rm -f "${INSTALL_FILE}"
        echo -e "DONE: Deleted ${INSTALL_FILE}"
    fi

    if [ -f "${BASHRC_PATH}" ]; then
        if grep -q "# Added by codex.sh" "${BASHRC_PATH}"; then
            sed -i.bak '/# Added by codex.sh/,+2d' "${BASHRC_PATH}"
            sed -i ':a;/^\s*$/{$d;N;ba;}' "${BASHRC_PATH}"
            echo -e "DONE: Removed codex.sh settings from ~/.bashrc"
        fi
    fi

    if [[ ":$PATH:" == *":${INSTALL_DIR}:"* ]]; then
        PATH=$(echo "$PATH" | sed -e "s|:${INSTALL_DIR}:|:|g" -e "s|^${INSTALL_DIR}:||" -e "s|:${INSTALL_DIR}$||" -e "s|^${INSTALL_DIR}$||")
        export PATH
        echo -e "DONE: Removed ${INSTALL_DIR} from current session PATH"
    fi

    if [ -n "$LITELLM_API_KEY" ]; then
        unset LITELLM_API_KEY
        echo -e "DONE: Removed LITELLM_API_KEY from current session"
    fi
}

# Delete model
delete_model() {
    if [ -d "${CONFIG_DIR}" ]; then
        rm -rf "${CONFIG_DIR}"
        echo -e "DONE: Deleted ${CONFIG_DIR}"
    fi
}

# Delete MCP
delete_mcp() {
    local mcp_config_file="${CONFIG_DIR}/mcp_servers.toml"

    if [ -f "$mcp_config_file" ]; then
        rm -f "$mcp_config_file"
        echo -e "DONE: Deleted MCP configuration file: $mcp_config_file"
    else
        echo -e "INFO: No MCP configuration file found to delete"
    fi

    if [ -f "${CONFIG_FILE}" ]; then
        local temp_config
        temp_config="/tmp/codex_config_$(date +%s).toml"
        if grep -v '^\[mcp_servers\.' "${CONFIG_FILE}" > "$temp_config" 2>/dev/null; then
            mv "$temp_config" "${CONFIG_FILE}"
            echo -e "DONE: Removed MCP server configurations from: ${CONFIG_FILE}"
        else
            rm -f "$temp_config"
            echo -e "INFO: No MCP configurations found in: ${CONFIG_FILE}"
        fi
    fi
}

# Delete Agent
delete_agent() {
    # TODO: FIXME
    echo -e "INFO: Agent deletion not supported"
}

# List model
list_model() {
    local model_name
    local model_count=0
    local current_model=""
    local models=()

    if [ ! -d "${CONFIG_DIR}" ]; then
        echo -e "ERROR: Configuration directory not found, please run install or update first"
        return 1
    fi

    if [ -L "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
        local current_config_file
        current_config_file=$(readlink "${CONFIG_FILE}")
        if [ -n "$current_config_file" ]; then
            current_model=$(basename "$current_config_file" | sed 's/config\.toml\.//')
        fi
    fi

    for item in "${CONFIG_DIR}"/config.toml.*; do
        if [ -f "$item" ]; then
            model_name=$(basename "$item" | sed 's/config\.toml\.//')
            model_count=$((model_count + 1))
            models+=("$model_name")
            if [ "$model_name" = "$current_model" ]; then
                echo -e "\033[32m   $model_count. $model_name (current model)\033[0m"
            else
                echo "   $model_count. $model_name"
            fi
        fi
    done

    if [ $model_count -eq 0 ]; then
        echo -e "INFO: No downloaded model configuration files found"
        echo -e "INFO: Please run 'install' or 'update' first to download model configurations"
        return 1
    fi

    echo ""
    echo "Enter model number to set (1-$model_count), or press Enter to exit:"
    read -r selection

    if [ -z "$selection" ]; then
        echo "No selection made, exiting."
        return 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$model_count" ]; then
        echo -e "ERROR: Invalid selection. Please enter a number between 1 and $model_count"
        return 1
    fi

    local selected_model="${models[$((selection - 1))]}"
    if set_model "$selected_model"; then
        echo -e "DONE: Set LLM model: $selected_model"
    else
        echo -e "ERROR: Failed to set model $selected_model"
        return 1
    fi
}

# List MCP
list_mcp() {
    local mcp_config_file="${CONFIG_DIR}/mcp_servers.toml"
    local mcp_name
    local mcp_count=0
    local active_mcps=()
    local mcps=()
    local mcp_enabled_status=()

    if [ ! -f "$mcp_config_file" ]; then
        echo -e "ERROR: MCP configuration file not found: $mcp_config_file"
        echo -e "INFO: Please run 'install' or 'update' first to download MCP configuration"
        return 1
    fi

    # Get list of active MCP servers from main config
    if [ -f "${CONFIG_FILE}" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[mcp_servers\.([^]]+)\] ]]; then
                active_mcps+=("${BASH_REMATCH[1]}")
            fi
        done < "${CONFIG_FILE}"
    fi

    # Parse available MCP servers from mcp_servers.toml and check enabled status
    local current_mcp=""
    local current_enabled="false"
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[mcp_servers\.([^]]+)\] ]]; then
            # Save previous MCP if exists
            if [ -n "$current_mcp" ]; then
                mcps+=("$current_mcp")
                mcp_enabled_status+=("$current_enabled")
            fi
            # Start new MCP section
            mcp_name="${BASH_REMATCH[1]}"
            current_mcp="$mcp_name"
            current_enabled="false"
            mcp_count=$((mcp_count + 1))
        elif [[ "$line" =~ ^enabled[[:space:]]*=[[:space:]]*(true|false) ]]; then
            current_enabled="${BASH_REMATCH[1]}"
        fi
    done < "$mcp_config_file"

    # Save last MCP
    if [ -n "$current_mcp" ]; then
        mcps+=("$current_mcp")
        mcp_enabled_status+=("$current_enabled")
    fi

    if [ $mcp_count -eq 0 ]; then
        echo -e "INFO: No MCP servers found in configuration file"
        return 1
    fi

    # Display MCP servers with status
    for i in "${!mcps[@]}"; do
        local idx=$((i + 1))
        local name="${mcps[$i]}"
        local is_enabled=false
        # Check if this MCP is in main config (this determines enabled status)
        if [[ " ${active_mcps[*]} " =~ " ${name} " ]]; then
            is_enabled=true
        fi

        if [ "$is_enabled" = true ]; then
            echo -e "\033[32m   $idx. $name (enabled)\033[0m"
        else
            echo "   $idx. $name"
        fi
    done

    echo ""
    echo "Enter MCP server number(s) to enable (e.g., 1 or 1,3,5),"
    echo "enter 0 to disable all MCP servers, or press Enter to exit:"
    read -r selection

    if [ -z "$selection" ]; then
        echo "No selection made, exiting."
        return 0
    fi

    # Check for disable all option
    if [ "$selection" = "0" ]; then
        if disable_all_mcp; then
            echo -e "DONE: Disabled all MCP servers"
        else
            echo -e "ERROR: Failed to disable MCP servers"
            return 1
        fi
        return 0
    fi

    # Convert selection numbers to MCP names
    local selected_names=()
    IFS=',' read -ra SELECTIONS <<< "$selection"

    for sel in "${SELECTIONS[@]}"; do
        sel=$(echo "$sel" | xargs)  # Trim whitespace
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "$mcp_count" ]; then
            echo -e "ERROR: Invalid selection: $sel. Please enter numbers between 1 and $mcp_count"
            return 1
        fi
        selected_names+=("${mcps[$((sel - 1))]}")
    done

    # Join array elements with comma
    local mcp_list
    mcp_list=$(IFS=,; echo "${selected_names[*]}")

    if set_mcp "$mcp_list"; then
        echo -e "DONE: Enabled MCP servers: $mcp_list"
    else
        echo -e "ERROR: Failed to enable MCP servers"
        return 1
    fi
}

# List Agent
list_agent() {
    # TODO: FIXME
    echo -e "INFO: Agent listing not supported"
}

# Upgrade codex.sh
upgrade_script() {
    local timestamp
    local temp_script
    local backup_script
    local script_path
    local remote_sha256
    local local_sha256
    local downloaded_sha256

    timestamp=$(date +"%Y%m%d_%H%M%S")
    temp_script="/tmp/codex.sh.${timestamp}"
    backup_script="/tmp/codex.sh.backup.${timestamp}"
    script_path="$(readlink -f "${BASH_SOURCE[0]}")"

    echo -e "INFO: Querying remote version information..."

    remote_sha256=$(query_script)
    if [ $? -ne 0 ] || [ -z "$remote_sha256" ]; then
        echo -e "ERROR: Unable to get remote version information"
        exit 1
    fi

    if [ -f "$script_path" ]; then
        local_sha256=$(sha256sum "$script_path" | cut -d' ' -f1)
        if [ "$local_sha256" = "$remote_sha256" ]; then
            echo -e "INFO: Local file is already the latest version, no upgrade needed"
            return 0
        else
            echo -e "INFO: New version detected, starting download..."
        fi
    else
        echo -e "INFO: Local file does not exist, starting download..."
    fi

    if curl -k -u "${ARTIFACTORY_USER}":"${ARTIFACTORY_PASS}" -L "${ARTIFACTORY_URL}/codex.sh" -o "$temp_script" -s; then
        if [ ! -s "$temp_script" ]; then
            echo -e "ERROR: Downloaded file is empty"
            rm -f "$temp_script"
            exit 1
        fi

        if ! head -1 "$temp_script" | grep -q "^#!/bin/bash"; then
            echo -e "ERROR: Downloaded file is not a valid Bash script"
            rm -f "$temp_script"
            exit 1
        fi

        downloaded_sha256=$(sha256sum "$temp_script" | cut -d' ' -f1)
        if [ "$downloaded_sha256" != "$remote_sha256" ]; then
            echo -e "ERROR: Downloaded file verification failed"
            echo -e "ERROR: Expected: $remote_sha256"
            echo -e "ERROR: Actual: $downloaded_sha256"
            rm -f "$temp_script"
            exit 1
        fi
        echo -e "DONE: Downloaded file verification successful"

        cp "$script_path" "$backup_script"
        echo -e "INFO: Current version backed up to: $backup_script"

        if mv "$temp_script" "$script_path"; then
            chmod +x "$script_path"
            if "$script_path" help >/dev/null 2>&1; then
                echo -e "DONE: New version verification successful"
                rm -f "$backup_script"
            else
                echo -e "ERROR: New version verification failed, restoring backup..."
                mv "$backup_script" "$script_path"
                chmod +x "$script_path"
                echo -e "INFO: Restored to original version"
                exit 1
            fi
        else
            echo -e "ERROR: Unable to replace script file"
            rm -f "$temp_script"
            exit 1
        fi
    else
        echo -e "ERROR: Download failed"
        exit 1
    fi
}

# Show installation information
show_info() {
    echo -e "Installation Path:"
    echo "   Command directory: ${INSTALL_FILE}"
    echo "   Configuration directory: ${CONFIG_DIR}"

    echo -e "\nInstallation Status:"
    if is_installed; then
        echo "   Installed"
        if [ -f "${INSTALL_FILE}" ]; then
            echo "   Version: $("${INSTALL_FILE}" --version 2>/dev/null || echo "Unknown")"
        fi
    else
        echo "   Not installed"
    fi

    echo -e "\nCurrent Configuration:"
    # Show current model
    local current_model=""

    if [ -L "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
        # CONFIG_FILE is a symlink - try to extract model name from symlink target filename
        local current_config_file
        current_config_file=$(readlink "${CONFIG_FILE}")
        if [ -n "$current_config_file" ]; then
            # Extract model name from symlink target (handle both relative and absolute paths)
            current_model=$(basename "$current_config_file" | sed 's/^config\.toml\.//')
            # If extraction failed or resulted in empty/original filename, fallback to reading content
            if [ -z "$current_model" ] || [ "$current_model" = "$(basename "$current_config_file")" ]; then
                current_model=""
            fi
        fi
    fi

    # If model not found from symlink name, read from file content
    if [ -z "$current_model" ] && [ -f "${CONFIG_FILE}" ]; then
        current_model=$(grep '^model[[:space:]]*=' "${CONFIG_FILE}" | head -1 | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/' | tr -d '"')
    fi

    if [ -n "$current_model" ]; then
        echo "   Current model: ${current_model}"
    else
        echo "   Current model: Not set"
    fi

    # Show enabled MCP servers
    if [ -f "${CONFIG_FILE}" ]; then
        local active_mcps=()
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[mcp_servers\.([^]]+)\] ]]; then
                active_mcps+=("${BASH_REMATCH[1]}")
            fi
        done < "${CONFIG_FILE}"
        if [ ${#active_mcps[@]} -gt 0 ]; then
            echo "   Enabled MCP servers: ${active_mcps[*]}"
        else
            echo "   Enabled MCP servers: None"
        fi
    else
        echo "   Enabled MCP servers: None"
    fi

    echo -e "\nSystem Information:"
    if check_system; then
        echo "   Compatible system: ${SUPPORTED_OS}"
    else
        echo "   System version check failed"
    fi
}

# Show script version
show_version() {
    echo "codex.sh ${SCRIPT_VERSION}"

    if [ -f "${INSTALL_FILE}" ]; then
        "${INSTALL_FILE}" --version 2>/dev/null
    fi
}

# Show help information
show_help() {
    cat << EOF
Codex CLI One-Stop Installation Script

Usage: $0 [options]

Options:
    install                      Install Codex CLI
    uninstall                    Uninstall Codex CLI
    update                       Update Codex CLI
    model [model_name]           Set LLM model
    mcp [mcp_name,mcp_name,...]  Set MCP services
    agent [agent_name]           Set Agent template
    upgrade                      Upgrade codex.sh
    info                         Show installation information
    version                      Show version information
    help                         Show help information

Examples:
    $0 install          Install Codex CLI (default model: ${DEFAULT_MODEL})
    $0 install kimi-k2  Install Codex CLI and set model
    $0 uninstall        Uninstall Codex CLI
    $0 update           Update Codex CLI
    $0 info             Show Codex CLI installation information
    $0 model            Show LLM model list
    $0 model kimi-k2    Set LLM model to kimi-k2
    $0 mcp              Show MCP service list (interactive, 0 to disable all)
    $0 mcp gerrit,git   Set MCP services to gerrit and git
    $0 agent            Show Agent template list
    $0 agent android    Set Agent template to android
EOF
}

# Main program
main() {
    case "$1" in
        install)
            echo -e "INFO: Starting Codex CLI installation..."
            if ! check_system; then
                echo -e "ERROR: Only supports ${SUPPORTED_OS} system"
                exit 1
            fi
            if is_installed; then
                echo -e "INFO: Codex CLI already installed"
                exit 1
            fi
            update_codex
            update_model
            update_mcp
            update_agent
            local MODEL=${2:-$DEFAULT_MODEL}
            if set_model "${MODEL}"; then
                echo -e "DONE: Codex CLI installation completed!"
                echo -e "\033[32mINFO: Run 'source ~/.bashrc' or reopen terminal for changes to take effect\033[0m"
                echo -e "\033[32mINFO: Run 'codex' to start using (model: ${MODEL})\033[0m"
            else
                echo -e "ERROR: Failed to set model ${MODEL}, installation incomplete"
                exit 1
            fi
            ;;
        uninstall)
            echo -e "INFO: Starting Codex CLI uninstallation..."
            delete_agent
            delete_mcp
            delete_model
            delete_codex
            echo -e "DONE: Codex CLI uninstallation completed!"
            ;;
        update)
            echo -e "INFO: Starting Codex CLI update..."
            if is_installed; then
                echo -e "INFO: Codex CLI already installed, update will overwrite existing installation"
                read -p "Continue? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "INFO: Codex CLI update cancelled"
                    exit 0
                fi
                delete_agent
                delete_mcp
                delete_model
                delete_codex
            fi
            update_codex
            update_model
            update_mcp
            update_agent
            local MODEL=${DEFAULT_MODEL}
            if set_model "${MODEL}"; then
                echo -e "DONE: Codex CLI update completed!"
                echo -e "\033[32mINFO: Run 'source ~/.bashrc' or reopen terminal for changes to take effect\033[0m"
                echo -e "\033[32mINFO: Run 'codex' to start using (model: ${MODEL})\033[0m"
            else
                echo -e "ERROR: Failed to set model ${MODEL}, update incomplete"
                exit 1
            fi
            ;;
        model)
            if [ -z "$2" ]; then
                echo "Available LLM models:"
                list_model
                exit 0
            fi
            if set_model "$2"; then
                echo -e "DONE: Set LLM model: $2"
            else
                echo -e "ERROR: Failed to set model $2"
                exit 1
            fi
            ;;
        mcp)
            if [ -z "$2" ]; then
                echo "Available MCP services:"
                list_mcp
                exit 0
            fi
            if set_mcp "$2"; then
                echo -e "DONE: Set MCP services: $2"
            else
                echo -e "ERROR: Failed to set MCP services"
                exit 1
            fi
            ;;
        agent)
            if [ -z "$2" ]; then
                echo "Available Agent templates:"
                list_agent
                exit 0
            fi
            shift 2
            set_agent "$2"
            echo -e "DONE: Set Agent template: $2"
            ;;
        upgrade)
            echo -e "INFO: Starting codex.sh upgrade..."
            upgrade_script
            echo -e "DONE: codex.sh upgrade completed!"
            echo -e "\033[32mINFO: Run 'codex.sh' to start using\033[0m"
            ;;
        info)
            show_info
            ;;
        version)
            show_version
            ;;
        help)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            echo -e "ERROR: Unknown option: $1"
            echo -e "INFO: Use '$0 help' for help"
            exit 1
            ;;
    esac
}

main "$@"
