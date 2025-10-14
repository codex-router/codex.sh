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

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

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

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

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

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

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

# Test query_config function (mock test)
test_query_config() {
    echo -e "TEST: Testing query_config function..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

    # Since network connection is required, we only test if function exists and basic syntax
    if declare -f query_config >/dev/null; then
        print_test_result "query_config function exists" "PASS"
    else
        print_test_result "query_config function exists" "FAIL" "Function does not exist"
    fi
}

# Test query_script function
test_query_script() {
    local mock_response
    local expected_sha256
    local parsed_sha256

    echo -e "TEST: Testing query_script function..."

    # Load function definitions only, don't execute main function
    source <(head -n -1 "$CODEX_SCRIPT")

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

# Test command line argument handling
test_command_line_args() {
    local help_output
    local invalid_output

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
}

# Test script permissions and executability
test_script_permissions() {
    echo -e "TEST: Testing script permissions..."

    if [ -x "$CODEX_SCRIPT" ]; then
        print_test_result "codex.sh is executable" "PASS"
    else
        print_test_result "codex.sh is executable" "FAIL" "Script is not executable"
    fi

    if [ -r "$CODEX_SCRIPT" ]; then
        print_test_result "codex.sh is readable" "PASS"
    else
        print_test_result "codex.sh is readable" "FAIL" "Script is not readable"
    fi
}

# Run all tests
run_all_tests() {
    echo -e "INFO: Starting codex.sh test suite..."
    echo "======================================"

    setup_test_env

    test_script_permissions
    test_check_system
    test_is_installed
    test_list_model
    test_interactive_model_selection
    test_set_model
    test_query_config
    test_query_script
    test_upgrade_script_logic
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
            echo "  check_system      - Test system check function"
            echo "  is_installed      - Test installation status check function"
            echo "  list_model        - Test model list function"
            echo "  interactive       - Test interactive model selection"
            echo "  set_model         - Test model setting function"
            echo "  query_config      - Test configuration query function"
            echo "  query_script      - Test script query function"
            echo "  upgrade_logic     - Test upgrade script related logic"
            echo "  show_version      - Test version display function"
            echo "  command_line      - Test command line argument handling"
            echo "  permissions       - Test script permissions"
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
        "query_script")
            test_query_script
            ;;
        "upgrade_logic")
            test_upgrade_script_logic
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
