#!/bin/bash
# Local version switching test script for mnenv
# Usage: ./scripts/version-switching-test.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Versions to test
VERSIONS=("1.13.9" "1.14.3")
SOURCE="gemfile"

# Check if we're in the mnenv directory
if [ ! -f "mnenv.gemspec" ]; then
    log_error "Please run this script from the mnenv root directory"
    exit 1
fi

# Install mnenv
log_info "Installing mnenv..."
bundle install > /dev/null 2>&1
rake install > /dev/null 2>&1
log_info "mnenv $(mnenv version) installed"

# Add mnenv to PATH
export PATH="$HOME/.mnenv/shims:$PATH"

# Clean up any existing test state
log_info "Cleaning up previous test state..."
rm -f ~/.mnenv/version ~/.mnenv/source
rm -rf /tmp/mnenv-test-*

# Install test versions
log_info "Installing Metanorma versions: ${VERSIONS[*]}..."
for version in "${VERSIONS[@]}"; do
    if mnenv install "$version" --source "$SOURCE" > /dev/null 2>&1; then
        log_info "  ✓ Installed $version"
    else
        log_warn "  ⚠ Failed to install $version (may already be installed)"
    fi
done

echo ""
log_info "=== Test 1: Global Version Switching ==="
mnenv global "${VERSIONS[0]}" --source "$SOURCE"
v1=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")
if [ "$v1" = "${VERSIONS[0]}" ]; then
    log_info "  ✓ Global ${VERSIONS[0]} verified"
else
    log_error "  ✗ Expected ${VERSIONS[0]}, got $v1"
    exit 1
fi

mnenv global "${VERSIONS[1]}" --source "$SOURCE"
v2=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")
if [ "$v2" = "${VERSIONS[1]}" ]; then
    log_info "  ✓ Global ${VERSIONS[1]} verified"
else
    log_error "  ✗ Expected ${VERSIONS[1]}, got $v2"
    exit 1
fi

echo ""
log_info "=== Test 2: Local Version Override ==="
mnenv global "${VERSIONS[1]}" --source "$SOURCE"
TEST_DIR="/tmp/mnenv-test-local"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
mnenv local "${VERSIONS[0]}" --source "$SOURCE"

v_local=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")
if [ "$v_local" = "${VERSIONS[0]}" ]; then
    log_info "  ✓ Local ${VERSIONS[0]} overrides global ${VERSIONS[1]}"
else
    log_error "  ✗ Expected ${VERSIONS[0]}, got $v_local"
    exit 1
fi

cd /tmp
v_outside=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")
if [ "$v_outside" = "${VERSIONS[1]}" ]; then
    log_info "  ✓ Global ${VERSIONS[1]} restored outside project"
else
    log_error "  ✗ Expected ${VERSIONS[1]}, got $v_outside"
    exit 1
fi

echo ""
log_info "=== Test 3: Shell Session Override ==="
cd "$TEST_DIR"
export MNENV_VERSION="${VERSIONS[1]}"
export MNENV_SOURCE="$SOURCE"
v_env=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")
if [ "$v_env" = "${VERSIONS[1]}" ]; then
    log_info "  ✓ MNENV_VERSION=${VERSIONS[1]} overrides local ${VERSIONS[0]}"
else
    log_error "  ✗ Expected ${VERSIONS[1]}, got $v_env"
    exit 1
fi
unset MNENV_VERSION MNENV_SOURCE

echo ""
log_info "=== Test 4: Consecutive Switches ==="
for i in 1 2 3; do
    mnenv global "${VERSIONS[0]}" --source "$SOURCE"
    v1=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

    mnenv global "${VERSIONS[1]}" --source "$SOURCE"
    v2=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

    if [ "$v1" != "${VERSIONS[0]}" ] || [ "$v2" != "${VERSIONS[1]}" ]; then
        log_error "  ✗ Round $i failed: v1=$v1, v2=$v2"
        exit 1
    fi
done
log_info "  ✓ 3 rounds of consecutive switches successful"

echo ""
log_info "=== Test 5: Version List Command ==="
mnenv versions | grep -q "${VERSIONS[0]}"
log_info "  ✓ ${VERSIONS[0]} in version list"

mnenv versions | grep -q "${VERSIONS[1]}"
log_info "  ✓ ${VERSIONS[1]} in version list"

echo ""
log_info "=== All tests passed! ==="
echo ""
log_info "Final state:"
echo "  Global version: $(cat ~/.mnenv/version 2>/dev/null || echo 'not set')"
echo "  Global source: $(cat ~/.mnenv/source 2>/dev/null || echo 'not set')"
echo "  Current metanorma: $(metanorma --version 2>&1 | head -1)"

# Clean up test directory
rm -rf "$TEST_DIR"
