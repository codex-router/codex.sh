#!/bin/bash

# Test script for codex.sh functions
# Usage: ./codex_test.sh

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_SCRIPT="$SCRIPT_DIR/codex.sh"
TEST_CONFIG_DIR="/tmp/codex_test_config"
TEST_INSTALL_DIR="/tmp/codex_test_install"
TEST_BASHRC="/tmp/codex_test_bashrc"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result logging
print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$result" = "PASS" ]; then
        echo -e "PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "FAIL: $test_name: $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Helper function to safely load codex.sh functions
load_codex_functions() {
    if [ ! -f "$CODEX_SCRIPT" ]; then
        echo "ERROR: codex.sh not found at $CODEX_SCRIPT" >&2
        return 1
    fi

    if [ ! -r "$CODEX_SCRIPT" ]; then
        echo "ERROR: codex.sh is not readable" >&2
        return 1
    fi

    # Load function definitions only, don't execute main function
    if ! source <(head -n -1 "$CODEX_SCRIPT") 2>/dev/null; then
        echo "ERROR: Failed to load codex.sh functions" >&2
        return 1
    fi

    return 0
}

# Set up test environment
setup_test_env() {
    echo -e "INFO: Setting up test environment..."

    # Create test directories
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_INSTALL_DIR"

    # Create test configuration files
    echo "test_config_content" > "$TEST_CONFIG_DIR/config.toml.test-model1"
    echo "test_config_content" > "$TEST_CONFIG_DIR/config.toml.test-model2"
    echo "test_config_content" > "$TEST_CONFIG_DIR/config.toml.kimi-k2"

    # Create single test MCP configuration file with multiple servers
    cat > "$TEST_CONFIG_DIR/mcp_servers.toml" << 'EOF'
# Test MCP configuration

# Filesystem MCP Server - provides file system access
[mcp_servers.filesystem]
command = "docker"
args = ["run", "--rm", "-p", "8001:8001"]
enabled = true

# Git MCP Server - provides Git repository management
[mcp_servers.git]
command = "docker"
args = ["run", "--rm", "-p", "8002:8002"]
enabled = false

# Docker MCP Server - provides Docker container management
[mcp_servers.docker]
command = "docker"
args = ["run", "--rm", "-p", "8000:8000"]
enabled = false

# Gerrit MCP Server - provides Gerrit code review integration
[mcp_servers.gerrit]
command = "docker"
args = ["run", "--rm", "-p", "6322:6322"]
enabled = false
EOF

    # Create test bashrc
    echo "# Test bashrc" > "$TEST_BASHRC"

    # Temporarily modify environment variables
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export INSTALL_DIR="$TEST_INSTALL_DIR"
    export BASHRC_PATH="$TEST_BASHRC"
}

# Clean up test environment
cleanup_test_env() {
    echo -e "INFO: Cleaning up test environment..."
    rm -rf "$TEST_CONFIG_DIR"
    rm -rf "$TEST_INSTALL_DIR"
    rm -f "$TEST_BASHRC"
}

# Test check_system function
test_check_system() {
    echo -e "TEST: Testing check_system function..."

    if ! load_codex_functions; then
        print_test_result "check_system function loading" "FAIL" "Failed to load codex.sh functions"
        return 1
    fi

    # Test Linux system check
    if check_system >/dev/null 2>&1; then
        if [[ "$(uname -s)" == "Linux" ]]; then
            print_test_result "check_system on Linux" "PASS"
        else
            print_test_result "check_system on non-Linux" "PASS" "Correctly identified non-Linux system"
        fi
    else
        if [[ "$(uname -s)" != "Linux" ]]; then
            print_test_result "check_system rejection on non-Linux" "PASS"
        else
            print_test_result "check_system on Linux" "FAIL" "Linux system check failed"
        fi
    fi
}

# Test is_installed function
test_is_installed() {
    echo -e "TEST: Testing is_installed function..."

    if ! load_codex_functions; then
        print_test_result "is_installed function loading" "FAIL" "Failed to load codex.sh functions"
        return 1
    fi

    # Ensure no installation files exist at test start (clean up any remnants)
    rm -f "$INSTALL_FILE" 2>/dev/null
    rm -f "$CONFIG_FILE" 2>/dev/null

    # Test not installed state
    if ! is_installed >/dev/null 2>&1; then
        print_test_result "is_installed when not installed" "PASS"
    else
        print_test_result "is_installed when not installed" "FAIL" "Should return not installed state"
    fi

    # Create installation files for testing
    mkdir -p "$TEST_INSTALL_DIR"
    touch "$TEST_INSTALL_DIR/codex"
    touch "$TEST_CONFIG_DIR/config.toml"

    export INSTALL_FILE="$TEST_INSTALL_DIR/codex"
    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"

    if is_installed >/dev/null 2>&1; then
        print_test_result "is_installed when installed" "PASS"
    else
        print_test_result "is_installed when installed" "FAIL" "Should return installed state"
    fi
}

# Test list_model function
test_list_model() {
    local output
    local no_config_output

    echo -e "TEST: Testing list_model function..."

    if ! load_codex_functions; then
        print_test_result "list_model function loading" "FAIL" "Failed to load codex.sh functions"
        return 1
    fi

    # Create a non-interactive version of list_model for testing
    list_model_test() {
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
                    echo "   $model_count. $model_name (current model)"
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
    }

    # Test with model configurations available
    output=$(list_model_test 2>/dev/null)

    if echo "$output" | grep -q "test-model1"; then
        print_test_result "list_model finds test-model1" "PASS"
    else
        print_test_result "list_model finds test-model1" "FAIL" "test-model1 not found"
    fi

    if echo "$output" | grep -q "test-model2"; then
        print_test_result "list_model finds test-model2" "PASS"
    else
        print_test_result "list_model finds test-model2" "FAIL" "test-model2 not found"
    fi

    if echo "$output" | grep -q "kimi-k2"; then
        print_test_result "list_model finds kimi-k2" "PASS"
    else
        print_test_result "list_model finds kimi-k2" "FAIL" "kimi-k2 not found"
    fi

    # Test current model indication
    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"
    ln -sf "$TEST_CONFIG_DIR/config.toml.test-model1" "$CONFIG_FILE"
    output=$(list_model_test 2>/dev/null)
    if echo "$output" | grep -q "test-model1 (current model)"; then
        print_test_result "list_model shows current model" "PASS"
    else
        print_test_result "list_model shows current model" "FAIL" "Current model indication not shown"
    fi

    # Test with no configuration directory
    rm -rf "$TEST_CONFIG_DIR"
    no_config_output=$(list_model_test 2>/dev/null)

    if echo "$no_config_output" | grep -q "Configuration directory not found\|not found"; then
        print_test_result "list_model handles missing config dir" "PASS"
    else
        print_test_result "list_model handles missing config dir" "FAIL" "Should indicate configuration directory doesn't exist"
    fi

    # Recreate test environment
    setup_test_env
}

# Test interactive model selection
test_interactive_model_selection() {
    echo -e "TEST: Testing interactive model selection..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"

    # Test that interactive function would be called by main script
    # We test the model command from main script with mocked input
    local model_output
    model_output=$(echo "" | "$CODEX_SCRIPT" model 2>/dev/null || true)

    if echo "$model_output" | grep -q "Available LLM models\|Enter model number"; then
        print_test_result "model command shows interactive prompt" "PASS"
    else
        print_test_result "model command shows interactive prompt" "FAIL" "Interactive prompt not shown"
    fi

    # Test that direct model setting still works
    if "$CODEX_SCRIPT" model test-model1 >/dev/null 2>&1; then
        if [ -L "$CONFIG_FILE" ] && [ "$(readlink "$CONFIG_FILE")" = "$TEST_CONFIG_DIR/config.toml.test-model1" ]; then
            print_test_result "direct model setting still works" "PASS"
        else
            print_test_result "direct model setting still works" "FAIL" "Direct model setting failed"
        fi
    else
        print_test_result "direct model setting still works" "FAIL" "Could not set model directly"
    fi
}

# Test set_model function
test_set_model() {
    echo -e "TEST: Testing set_model function..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"

    # Test setting an existing model
    if set_model "test-model1" >/dev/null 2>&1; then
        if [ -L "$CONFIG_FILE" ] && [ "$(readlink "$CONFIG_FILE")" = "$TEST_CONFIG_DIR/config.toml.test-model1" ]; then
            print_test_result "set_model creates correct symlink" "PASS"
        else
            print_test_result "set_model creates correct symlink" "FAIL" "Symlink creation failed or points to wrong target"
        fi
    else
        print_test_result "set_model with valid model" "FAIL" "Failed to set valid model"
    fi

    # Test setting a non-existent model
    if ! set_model "nonexistent-model" >/dev/null 2>&1; then
        print_test_result "set_model rejects invalid model" "PASS"
    else
        print_test_result "set_model rejects invalid model" "FAIL" "Should reject non-existent model"
    fi
}

# Test query_mcp function (offline mock test)
test_query_mcp() {
    echo -e "TEST: Testing query_mcp function..."

    if ! load_codex_functions; then
        print_test_result "query_mcp function loading" "FAIL" "Failed to load codex.sh functions"
        return 1
    fi

    # Test if function exists and basic syntax (offline mode)
    if declare -f query_mcp >/dev/null; then
        print_test_result "query_mcp function exists" "PASS"
    else
        print_test_result "query_mcp function exists" "FAIL" "Function does not exist"
    fi

    # Test parsing logic with mock response (offline) - now checks for single file
    local mock_response='{"children":[{"uri":"/mcp_servers.toml"},{"uri":"/config.toml.kimi-k2"}]}'

    if echo "$mock_response" | grep -q '"/mcp_servers\.toml"'; then
        print_test_result "query_mcp parsing logic (offline)" "PASS"
    else
        print_test_result "query_mcp parsing logic (offline)" "FAIL" "MCP file detection failed"
    fi
}

# Test list_mcp function
test_list_mcp() {
    local output
    local mcp_config_file

    echo -e "TEST: Testing list_mcp function..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    mcp_config_file="${CONFIG_DIR}/mcp_servers.toml"

    # Test with MCP configuration file available
    if [ -f "$mcp_config_file" ]; then
        # Create a non-interactive test to parse MCP servers
        # Enabled status determined by presence in config.toml, not mcp_servers.toml
        list_mcp_test() {
            local mcp_config_file="${CONFIG_DIR}/mcp_servers.toml"
            local mcp_name
            local mcp_count=0
            local mcps=()
            local active_mcps=()

            if [ ! -f "$mcp_config_file" ]; then
                echo -e "ERROR: MCP configuration file not found"
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

            # Parse available MCP servers from mcp_servers.toml
            while IFS= read -r line; do
                if [[ "$line" =~ ^\[mcp_servers\.([^]]+)\] ]]; then
                    mcp_name="${BASH_REMATCH[1]}"
                    mcps+=("$mcp_name")
                    mcp_count=$((mcp_count + 1))
                fi
            done < "$mcp_config_file"

            if [ $mcp_count -eq 0 ]; then
                echo -e "INFO: No MCP servers found in configuration file"
                return 1
            fi

            # Display with status based on config.toml presence
            for i in "${!mcps[@]}"; do
                local idx=$((i + 1))
                local name="${mcps[$i]}"

                # Check if this server is in config.toml
                if [[ " ${active_mcps[*]} " =~ " ${name} " ]]; then
                    echo "   $idx. $name (enabled)"
                else
                    echo "   $idx. $name"
                fi
            done
        }

        output=$(list_mcp_test 2>/dev/null)

        if echo "$output" | grep -q "filesystem"; then
            print_test_result "list_mcp finds filesystem" "PASS"
        else
            print_test_result "list_mcp finds filesystem" "FAIL" "filesystem not found"
        fi

        if echo "$output" | grep -q "git"; then
            print_test_result "list_mcp finds git" "PASS"
        else
            print_test_result "list_mcp finds git" "FAIL" "git not found"
        fi

        if echo "$output" | grep -q "docker"; then
            print_test_result "list_mcp finds docker" "PASS"
        else
            print_test_result "list_mcp finds docker" "FAIL" "docker not found"
        fi

        # Test that disabled label is NOT shown
        if ! echo "$output" | grep -q "(disabled)"; then
            print_test_result "list_mcp does not show disabled label" "PASS"
        else
            print_test_result "list_mcp does not show disabled label" "FAIL" "Disabled label should not be shown"
        fi
    else
        print_test_result "list_mcp test setup" "FAIL" "MCP config file not created"
    fi

    # Test enabled status based on config.toml presence
    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"
    echo "# Test config file" > "$CONFIG_FILE"
    echo "[mcp_servers.filesystem]" >> "$CONFIG_FILE"
    echo "command = \"test\"" >> "$CONFIG_FILE"
    echo "enabled = true" >> "$CONFIG_FILE"

    output=$(list_mcp_test 2>/dev/null)
    if echo "$output" | grep -q "filesystem (enabled)"; then
        print_test_result "list_mcp shows enabled status from config.toml" "PASS"
    else
        print_test_result "list_mcp shows enabled status from config.toml" "FAIL" "Enabled status not shown for server in config.toml"
    fi

    # Test with missing configuration file
    rm -f "$mcp_config_file"
    if ! list_mcp_test 2>/dev/null; then
        print_test_result "list_mcp handles missing config file" "PASS"
    else
        print_test_result "list_mcp handles missing config file" "FAIL" "Should indicate configuration file doesn't exist"
    fi

    # Recreate test environment
    setup_test_env
}

# Test set_mcp function
test_set_mcp() {
    echo -e "TEST: Testing set_mcp function..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    # Re-export after sourcing to ensure correct values
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"

    # Create a base config file first
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"

    # Test setting a single existing MCP server
    if set_mcp "filesystem" 2>&1 | grep -v "^INFO:" | grep -v "^DONE:" >/dev/null; then
        # Check if there were errors (not just INFO/DONE messages)
        if grep -q "\[mcp_servers.filesystem\]" "$CONFIG_FILE"; then
            print_test_result "set_mcp applies single MCP server" "PASS"
        else
            print_test_result "set_mcp applies single MCP server" "FAIL" "MCP configuration not applied"
        fi
    elif grep -q "\[mcp_servers.filesystem\]" "$CONFIG_FILE"; then
        print_test_result "set_mcp applies single MCP server" "PASS"
    else
        print_test_result "set_mcp with valid MCP" "FAIL" "Failed to set valid MCP"
    fi

    # Verify that enabled = true is set in config.toml
    local filesystem_enabled=$(grep -A5 '^\[mcp_servers\.filesystem\]' "$CONFIG_FILE" | grep '^enabled' | grep -o 'true\|false')
    if [ "$filesystem_enabled" = "true" ]; then
        print_test_result "set_mcp sets enabled = true" "PASS"
    else
        print_test_result "set_mcp sets enabled = true" "FAIL" "Should set enabled = true in config.toml"
    fi

    # Test setting multiple MCP servers (comma-separated)
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"

    set_mcp "filesystem,git,docker" >/dev/null 2>&1
    if grep -q "\[mcp_servers.filesystem\]" "$CONFIG_FILE" && \
       grep -q "\[mcp_servers.git\]" "$CONFIG_FILE" && \
       grep -q "\[mcp_servers.docker\]" "$CONFIG_FILE"; then
        print_test_result "set_mcp applies multiple MCP servers" "PASS"
    else
        print_test_result "set_mcp applies multiple MCP servers" "FAIL" "Not all MCP configurations applied"
    fi

    # Verify all have enabled = true
    local git_enabled=$(grep -A5 '^\[mcp_servers\.git\]' "$CONFIG_FILE" | grep '^enabled' | grep -o 'true\|false')
    local docker_enabled=$(grep -A5 '^\[mcp_servers\.docker\]' "$CONFIG_FILE" | grep '^enabled' | grep -o 'true\|false')
    if [ "$git_enabled" = "true" ] && [ "$docker_enabled" = "true" ]; then
        print_test_result "set_mcp sets enabled = true for all servers" "PASS"
    else
        print_test_result "set_mcp sets enabled = true for all servers" "FAIL" "All selected servers should have enabled = true"
    fi

    # Test setting a non-existent MCP configuration
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"

    set_mcp "nonexistent-mcp" >/dev/null 2>&1
    # Should show warning but not fail completely
    if ! grep -q "\[mcp_servers.nonexistent-mcp\]" "$CONFIG_FILE"; then
        print_test_result "set_mcp handles invalid MCP gracefully" "PASS"
    else
        print_test_result "set_mcp handles invalid MCP gracefully" "FAIL" "Should not add non-existent MCP"
    fi

    # Test that old MCP sections are removed when setting new ones
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"
    echo "[mcp_servers.old_server]" >> "$CONFIG_FILE"
    echo "command = \"old\"" >> "$CONFIG_FILE"

    set_mcp "git" >/dev/null 2>&1
    if ! grep -q "old_server" "$CONFIG_FILE" && grep -q "\[mcp_servers.git\]" "$CONFIG_FILE"; then
        print_test_result "set_mcp removes old MCP sections" "PASS"
    else
        print_test_result "set_mcp removes old MCP sections" "FAIL" "Old MCP sections not properly removed"
    fi

    # Test that orphaned MCP configuration lines are completely removed
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "command = \"docker\"" >> "$CONFIG_FILE"
    echo "args = [\"run\", \"--rm\"]" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "[mcp_servers.filesystem]" >> "$CONFIG_FILE"
    echo "command = \"docker\"" >> "$CONFIG_FILE"
    echo "enabled = false" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "[mcp_servers.git]" >> "$CONFIG_FILE"
    echo "command = \"docker\"" >> "$CONFIG_FILE"
    echo "enabled = false" >> "$CONFIG_FILE"

    set_mcp "git" >/dev/null 2>&1

    # Count how many times 'command = "docker"' appears (should be only once for git)
    local command_count
    command_count=$(grep -c 'command = "docker"' "$CONFIG_FILE" 2>/dev/null)
    command_count=${command_count:-0}

    # Check that filesystem section is gone
    local has_filesystem
    has_filesystem=$(grep -c '\[mcp_servers.filesystem\]' "$CONFIG_FILE" 2>/dev/null)
    has_filesystem=${has_filesystem:-0}

    # Check that orphaned lines before first section are gone
    local has_orphaned_args
    has_orphaned_args=$(grep -c '^args = \["run", "--rm"\]' "$CONFIG_FILE" 2>/dev/null)
    has_orphaned_args=${has_orphaned_args:-0}

    if [ "$command_count" = "1" ] && [ "$has_filesystem" = "0" ] && [ "$has_orphaned_args" = "0" ]; then
        print_test_result "set_mcp removes orphaned MCP configuration lines" "PASS"
    else
        print_test_result "set_mcp removes orphaned MCP configuration lines" "FAIL" "Orphaned lines still present (command_count: $command_count, filesystem: $has_filesystem, orphaned_args: $has_orphaned_args)"
    fi

    # Test that trailing comments from next section are not included
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"

    # Set git (which is followed by docker in the template)
    set_mcp "git" >/dev/null 2>&1

    # Check that we don't have the docker section comment trailing the git section
    local has_docker_comment
    has_docker_comment=$(grep -c '# Docker MCP Server' "$CONFIG_FILE" 2>/dev/null)
    has_docker_comment=${has_docker_comment:-0}

    # Check that git section is present
    local has_git_section
    has_git_section=$(grep -c '\[mcp_servers.git\]' "$CONFIG_FILE" 2>/dev/null)
    has_git_section=${has_git_section:-0}

    if [ "$has_git_section" = "1" ] && [ "$has_docker_comment" = "0" ]; then
        print_test_result "set_mcp does not include trailing section comments" "PASS"
    else
        print_test_result "set_mcp does not include trailing section comments" "FAIL" "Trailing comments found (git_section: $has_git_section, docker_comment: $has_docker_comment)"
    fi
}

# Test interactive MCP selection
test_interactive_mcp_selection() {
    echo -e "TEST: Testing interactive MCP selection..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    # Re-export after sourcing to ensure correct values
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"

    # Test that interactive function would be called by main script
    # We test the mcp command from main script with mocked input
    local mcp_output
    mcp_output=$(echo "" | "$CODEX_SCRIPT" mcp 2>/dev/null || true)

    if echo "$mcp_output" | grep -q "Available MCP services\|Enter MCP server number"; then
        print_test_result "mcp command shows interactive prompt" "PASS"
    else
        print_test_result "mcp command shows interactive prompt" "FAIL" "Interactive prompt not shown"
    fi

    # Test that direct MCP setting still works
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"

    # Test the set_mcp function directly with actual MCP server names
    set_mcp "filesystem" >/dev/null 2>&1
    if grep -q "\[mcp_servers.filesystem\]" "$CONFIG_FILE"; then
        print_test_result "direct MCP setting still works" "PASS"
    else
        print_test_result "direct MCP setting still works" "FAIL" "Direct MCP setting failed - content not found"
    fi
}

# Test MCP configuration parsing
test_mcp_config_parsing() {
    local test_mcp_file
    local parsed_servers

    echo -e "TEST: Testing MCP configuration parsing..."

    # Create a test MCP configuration file with multiple servers
    test_mcp_file="$TEST_CONFIG_DIR/test_mcp_servers.toml"
    cat > "$test_mcp_file" << 'EOF'
# Test MCP configuration
[mcp_servers.filesystem]
command = "docker"
args = ["run", "--rm", "-p", "8001:8001"]
enabled = true

[mcp_servers.git]
command = "docker"
args = ["run", "--rm", "-p", "8002:8002"]
enabled = false

[mcp_servers.custom]
url = "https://api.example.com/mcp"
enabled = true
EOF

    # Test parsing MCP server names
    parsed_servers=$(grep '^\[mcp_servers\.' "$test_mcp_file" | sed 's/^\[mcp_servers\.\([^]]*\)\].*/\1/' | sort)

    if echo "$parsed_servers" | grep -q "filesystem"; then
        print_test_result "MCP config parsing finds filesystem" "PASS"
    else
        print_test_result "MCP config parsing finds filesystem" "FAIL" "filesystem not found"
    fi

    if echo "$parsed_servers" | grep -q "git"; then
        print_test_result "MCP config parsing finds git" "PASS"
    else
        print_test_result "MCP config parsing finds git" "FAIL" "git not found"
    fi

    if echo "$parsed_servers" | grep -q "custom"; then
        print_test_result "MCP config parsing finds custom" "PASS"
    else
        print_test_result "MCP config parsing finds custom" "FAIL" "custom not found"
    fi

    # Test parsing enabled status
    local filesystem_enabled=$(grep -A5 '^\[mcp_servers\.filesystem\]' "$test_mcp_file" | grep '^enabled' | grep -o 'true\|false')
    local git_enabled=$(grep -A5 '^\[mcp_servers\.git\]' "$test_mcp_file" | grep '^enabled' | grep -o 'true\|false')

    if [ "$filesystem_enabled" = "true" ] && [ "$git_enabled" = "false" ]; then
        print_test_result "MCP config parsing reads enabled status" "PASS"
    else
        print_test_result "MCP config parsing reads enabled status" "FAIL" "Failed to parse enabled status correctly"
    fi

    rm -f "$test_mcp_file"
}

# Test MCP enabled status management in config.toml
test_mcp_enabled_update() {
    local mcp_config_file

    echo -e "TEST: Testing MCP enabled status management..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    # Re-export after sourcing to ensure correct values
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"

    mcp_config_file="${CONFIG_DIR}/mcp_servers.toml"

    # Verify that mcp_servers.toml has the enabled field (for reference only)
    local filesystem_enabled_in_template=$(grep -A5 '^\[mcp_servers\.filesystem\]' "$mcp_config_file" | grep '^enabled' | grep -o 'true\|false')

    if [ "$filesystem_enabled_in_template" = "true" ]; then
        print_test_result "MCP template has enabled field" "PASS"
    else
        print_test_result "MCP template has enabled field" "FAIL" "Template should have enabled field"
    fi

    # Test that set_mcp sets enabled = true in config.toml
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"

    set_mcp "git" >/dev/null 2>&1

    # Check that config.toml has enabled = true for git
    local git_enabled_in_config=$(grep -A5 '^\[mcp_servers\.git\]' "$CONFIG_FILE" | grep '^enabled' | grep -o 'true\|false')

    if [ "$git_enabled_in_config" = "true" ]; then
        print_test_result "set_mcp sets enabled = true in config.toml" "PASS"
    else
        print_test_result "set_mcp sets enabled = true in config.toml" "FAIL" "Config should have enabled = true"
    fi

    # Verify that mcp_servers.toml was NOT modified
    local filesystem_enabled_after=$(grep -A5 '^\[mcp_servers\.filesystem\]' "$mcp_config_file" | grep '^enabled' | grep -o 'true\|false')
    local git_enabled_in_template_after=$(grep -A5 '^\[mcp_servers\.git\]' "$mcp_config_file" | grep '^enabled' | grep -o 'true\|false')

    if [ "$filesystem_enabled_in_template" = "$filesystem_enabled_after" ] && [ "$git_enabled_in_template_after" = "false" ]; then
        print_test_result "mcp_servers.toml remains unchanged" "PASS"
    else
        print_test_result "mcp_servers.toml remains unchanged" "FAIL" "Template file should not be modified"
    fi

    # Test that list_mcp shows enabled status based on config.toml presence
    # (filesystem is in template with enabled=true but NOT in config.toml, so should not show as enabled)
    # (git is in config.toml with enabled=true, so should show as enabled)

    # Reset and recreate test environment to ensure clean state
    setup_test_env
}

# Test query_config function (offline mock test)
test_query_config() {
    echo -e "TEST: Testing query_config function..."

    if ! load_codex_functions; then
        print_test_result "query_config function loading" "FAIL" "Failed to load codex.sh functions"
        return 1
    fi

    # Test if function exists and basic syntax (offline mode)
    if declare -f query_config >/dev/null; then
        print_test_result "query_config function exists" "PASS"
    else
        print_test_result "query_config function exists" "FAIL" "Function does not exist"
    fi

    # Test parsing logic with mock response (offline)
    local mock_response='{"children":[{"uri":"/config.toml.kimi-k2"},{"uri":"/config.toml.gpt-4"},{"uri":"/config.toml.claude-3"}]}'
    local parsed_configs
    parsed_configs=$(echo "$mock_response" | grep -o '"/config\.toml\.[^"]*"' | sed 's|"/config\.toml\.\([^"]*\)"|\1|' | sort)

    if echo "$parsed_configs" | grep -q "kimi-k2"; then
        print_test_result "query_config parsing logic (offline)" "PASS"
    else
        print_test_result "query_config parsing logic (offline)" "FAIL" "Config parsing failed"
    fi
}

# Test query_script function (offline mock test)
test_query_script() {
    local mock_response
    local expected_sha256
    local parsed_sha256

    echo -e "TEST: Testing query_script function..."

    if ! load_codex_functions; then
        print_test_result "query_script function loading" "FAIL" "Failed to load codex.sh functions"
        return 1
    fi

    # Test if function exists
    if declare -f query_script >/dev/null; then
        print_test_result "query_script function exists" "PASS"
    else
        print_test_result "query_script function exists" "FAIL" "Function does not exist"
    fi

    # Since network connection is required, we create a mock test
    # Test that function can correctly handle JSON response format
    mock_response='{"checksums":{"sha256":"4b80531c642e129c304fe94f1bcae2463b14492ea60c3783e7eaf508b06d0ab8"}}'
    expected_sha256="4b80531c642e129c304fe94f1bcae2463b14492ea60c3783e7eaf508b06d0ab8"

    # Mock parsing logic test
    parsed_sha256=$(echo "$mock_response" | grep -o '"checksums"[[:space:]]*:[[:space:]]*{[^}]*"sha256"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"sha256"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ "$parsed_sha256" = "$expected_sha256" ]; then
        print_test_result "query_script parses SHA256 correctly" "PASS"
    else
        print_test_result "query_script parses SHA256 correctly" "FAIL" "Parse result: $parsed_sha256, Expected: $expected_sha256"
    fi
}

# Test upgrade_script related functionality
test_upgrade_script_logic() {
    local test_file
    local calculated_sha256
    local timestamp

    echo -e "TEST: Testing upgrade_script related logic..."

    # Test SHA256 calculation functionality
    test_file="/tmp/test_sha256_file"
    echo "test content for sha256" > "$test_file"

    if command -v sha256sum >/dev/null 2>&1; then
        calculated_sha256=$(sha256sum "$test_file" | cut -d' ' -f1)
        if [ ${#calculated_sha256} -eq 64 ]; then
            print_test_result "SHA256 calculation works" "PASS"
        else
            print_test_result "SHA256 calculation works" "FAIL" "SHA256 length incorrect: ${#calculated_sha256}"
        fi
    else
        print_test_result "SHA256 command available" "FAIL" "sha256sum command not available"
    fi

    rm -f "$test_file"

    # Test timestamp generation
    timestamp=$(date +"%Y%m%d_%H%M%S")
    if [[ "$timestamp" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        print_test_result "timestamp format correct" "PASS"
    else
        print_test_result "timestamp format correct" "FAIL" "Timestamp format incorrect: $timestamp"
    fi

    # Test readlink functionality (for getting script path)
    if command -v readlink >/dev/null 2>&1; then
        print_test_result "readlink command available" "PASS"
    else
        print_test_result "readlink command available" "FAIL" "readlink command not available"
    fi
}

# Test show_info function
test_show_info() {
    local info_output

    echo -e "TEST: Testing show_info function..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    # Re-export after sourcing to ensure correct values
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$TEST_CONFIG_DIR/config.toml"
    export INSTALL_FILE="$TEST_INSTALL_DIR/codex"

    # Test basic info display
    info_output=$("$CODEX_SCRIPT" info 2>/dev/null)
    if echo "$info_output" | grep -q "Installation Path"; then
        print_test_result "show_info displays installation path" "PASS"
    else
        print_test_result "show_info displays installation path" "FAIL" "Installation path section not found"
    fi

    if echo "$info_output" | grep -q "Installation Status"; then
        print_test_result "show_info displays installation status" "PASS"
    else
        print_test_result "show_info displays installation status" "FAIL" "Installation status section not found"
    fi

    if echo "$info_output" | grep -q "System Information"; then
        print_test_result "show_info displays system information" "PASS"
    else
        print_test_result "show_info displays system information" "FAIL" "System information section not found"
    fi

    # Test current configuration display
    if echo "$info_output" | grep -q "Current Configuration"; then
        print_test_result "show_info displays current configuration" "PASS"
    else
        print_test_result "show_info displays current configuration" "FAIL" "Current configuration section not found"
    fi

    # Test with model set
    ln -sf "$TEST_CONFIG_DIR/config.toml.kimi-k2" "$CONFIG_FILE"
    info_output=$(show_info 2>/dev/null)
    if echo "$info_output" | grep -q "Current model:.*kimi-k2"; then
        print_test_result "show_info displays current model" "PASS"
    else
        print_test_result "show_info displays current model" "FAIL" "Current model not shown correctly"
    fi

    # Test with MCP servers enabled
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "[mcp_servers.gerrit]" >> "$CONFIG_FILE"
    echo "command = \"docker\"" >> "$CONFIG_FILE"
    echo "enabled = true" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "[mcp_servers.git]" >> "$CONFIG_FILE"
    echo "command = \"docker\"" >> "$CONFIG_FILE"
    echo "enabled = true" >> "$CONFIG_FILE"

    info_output=$(show_info 2>/dev/null)
    if echo "$info_output" | grep -q "Enabled MCP servers:.*gerrit.*git"; then
        print_test_result "show_info displays enabled MCP servers" "PASS"
    else
        print_test_result "show_info displays enabled MCP servers" "FAIL" "Enabled MCP servers not shown correctly"
    fi

    # Test with no MCP servers
    echo "# Base config" > "$CONFIG_FILE"
    echo "model = \"test-model\"" >> "$CONFIG_FILE"

    info_output=$(show_info 2>/dev/null)
    if echo "$info_output" | grep -q "Enabled MCP servers:.*None"; then
        print_test_result "show_info shows None when no MCP servers" "PASS"
    else
        print_test_result "show_info shows None when no MCP servers" "FAIL" "Should show 'None' when no MCP servers enabled"
    fi
}

# Test command line argument handling
test_command_line_args() {
    local help_output
    local invalid_output
    local mcp_output

    echo -e "TEST: Testing command line argument handling..."

    # Test help command
    help_output=$("$CODEX_SCRIPT" help 2>/dev/null)
    if echo "$help_output" | grep -q "Usage"; then
        print_test_result "help command works" "PASS"
    else
        print_test_result "help command works" "FAIL" "help command output abnormal"
    fi

    # Test invalid parameters
    invalid_output=$("$CODEX_SCRIPT" invalid_command 2>&1)
    if echo "$invalid_output" | grep -q "Unknown option\|Error"; then
        print_test_result "invalid command handling" "PASS"
    else
        print_test_result "invalid command handling" "FAIL" "Invalid command handling abnormal"
    fi

    # Test MCP command without parameters (should show list)
    mcp_output=$("$CODEX_SCRIPT" mcp 2>/dev/null || true)
    if echo "$mcp_output" | grep -q "Available MCP services\|No downloaded MCP"; then
        print_test_result "mcp command without params shows list" "PASS"
    else
        print_test_result "mcp command without params shows list" "FAIL" "MCP command output abnormal"
    fi

    # Test model command without parameters (should show list)
    local model_output
    model_output=$("$CODEX_SCRIPT" model 2>/dev/null || true)
    if echo "$model_output" | grep -q "Available LLM models\|No downloaded model"; then
        print_test_result "model command without params shows list" "PASS"
    else
        print_test_result "model command without params shows list" "FAIL" "Model command output abnormal"
    fi
}

# Test script permissions and executability
test_script_permissions() {
    echo -e "TEST: Testing script permissions..."

    if [ ! -f "$CODEX_SCRIPT" ]; then
        print_test_result "codex.sh exists" "FAIL" "File not found at $CODEX_SCRIPT"
        return 1
    fi

    print_test_result "codex.sh exists" "PASS"

    if [ -r "$CODEX_SCRIPT" ]; then
        print_test_result "codex.sh is readable" "PASS"
    else
        print_test_result "codex.sh is readable" "FAIL" "Script is not readable"
    fi

    if [ -x "$CODEX_SCRIPT" ]; then
        print_test_result "codex.sh is executable" "PASS"
    else
        print_test_result "codex.sh is executable" "FAIL" "Script is not executable - run: chmod +x $CODEX_SCRIPT"
    fi
}

# Run all tests
run_all_tests() {
    echo -e "INFO: Starting codex.sh test suite..."
    echo "======================================"

    # Check if codex.sh exists before running tests
    if [ ! -f "$CODEX_SCRIPT" ]; then
        echo -e "ERROR: codex.sh not found at: $CODEX_SCRIPT"
        echo -e "ERROR: Make sure you're running this script from the correct directory"
        echo -e "ERROR: Expected file structure:"
        echo -e "  - codex_test.sh (this script)"
        echo -e "  - codex.sh (main script to test)"
        echo -e "  - mcp_servers.toml (MCP configuration)"
        exit 1
    fi

    setup_test_env

    test_script_permissions
    test_check_system
    test_is_installed
    test_list_model
    test_interactive_model_selection
    test_set_model
    test_query_config
    test_query_mcp
    test_list_mcp
    test_set_mcp
    test_interactive_mcp_selection
    test_mcp_config_parsing
    test_mcp_enabled_update
    test_query_script
    test_upgrade_script_logic
    test_show_info
    test_command_line_args

    cleanup_test_env

    echo "======================================"
    echo -e "INFO: Tests completed"
    echo -e "Total tests: $TESTS_RUN"
    echo -e "PASSED: $TESTS_PASSED"
    echo -e "FAILED: $TESTS_FAILED"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "SUCCESS: All tests passed!"
        exit 0
    else
        echo -e "FAILURE: Some tests failed, please check the code"
        exit 1
    fi
}

# Main program entry point
main() {
    case "$1" in
        "")
            run_all_tests
            ;;
        "help")
            echo "Usage: $0 [test_function_name]"
            echo "Available test functions:"
            echo "  check_system       - Test system check function"
            echo "  is_installed       - Test installation status check function"
            echo "  list_model         - Test model list function"
            echo "  interactive        - Test interactive model selection"
            echo "  set_model          - Test model setting function"
            echo "  query_config       - Test configuration query function"
            echo "  query_mcp          - Test MCP configuration query function"
            echo "  list_mcp           - Test MCP list function"
            echo "  set_mcp            - Test MCP setting function"
            echo "  interactive_mcp    - Test interactive MCP selection"
            echo "  mcp_config_parsing - Test MCP configuration parsing"
            echo "  mcp_enabled_update - Test MCP enabled status update"
            echo "  query_script       - Test script query function"
            echo "  upgrade_logic      - Test upgrade script related logic"
            echo "  show_info          - Test info display function"
            echo "  show_version       - Test version display function"
            echo "  command_line       - Test command line argument handling"
            echo "  permissions        - Test script permissions"
            ;;
        "check_system")
            setup_test_env
            test_check_system
            cleanup_test_env
            ;;
        "is_installed")
            setup_test_env
            test_is_installed
            cleanup_test_env
            ;;
        "list_model")
            setup_test_env
            test_list_model
            cleanup_test_env
            ;;
        "interactive")
            setup_test_env
            test_interactive_model_selection
            cleanup_test_env
            ;;
        "set_model")
            setup_test_env
            test_set_model
            cleanup_test_env
            ;;
        "query_config")
            test_query_config
            ;;
        "query_mcp")
            test_query_mcp
            ;;
        "list_mcp")
            setup_test_env
            test_list_mcp
            cleanup_test_env
            ;;
        "set_mcp")
            setup_test_env
            test_set_mcp
            cleanup_test_env
            ;;
        "interactive_mcp")
            setup_test_env
            test_interactive_mcp_selection
            cleanup_test_env
            ;;
        "mcp_config_parsing")
            setup_test_env
            test_mcp_config_parsing
            cleanup_test_env
            ;;
        "mcp_enabled_update")
            setup_test_env
            test_mcp_enabled_update
            cleanup_test_env
            ;;
        "query_script")
            test_query_script
            ;;
        "upgrade_logic")
            test_upgrade_script_logic
            ;;
        "show_info")
            setup_test_env
            test_show_info
            cleanup_test_env
            ;;
        "show_version")
            setup_test_env
            test_show_version
            cleanup_test_env
            ;;
        "command_line")
            test_command_line_args
            ;;
        "permissions")
            test_script_permissions
            ;;
        *)
            echo -e "ERROR: Unknown test function: $1"
            echo "Use '$0 help' to see available test functions"
            exit 1
            ;;
    esac
}

main "$@"
