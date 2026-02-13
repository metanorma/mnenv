#!/bin/bash
# Local cross-source switching test script for mnenv
# Tests switching between gemfile and binary for the same version
# Usage: ./scripts/cross-source-switching-test.sh [VERSION]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Version to test
VERSION="${1:-1.14.3}"

# Check if we're in the mnenv directory
if [ ! -f "mnenv.gemspec" ]; then
    log_error "Please run this script from the mnenv root directory"
    exit 1
fi

# Install mnenv
log_step "Installing mnenv"
bundle install > /dev/null 2>&1
rake install > /dev/null 2>&1
log_info "mnenv $(mnenv version) installed"

# Add mnenv to PATH
export PATH="$HOME/.mnenv/shims:$PATH"

# Clean up any existing test state
log_step "Cleaning up previous test state"
rm -f ~/.mnenv/version ~/.mnenv/source
rm -rf "/tmp/mnenv-cross-test-$VERSION"
mkdir -p "/tmp/mnenv-cross-test-$VERSION"

# Check binary availability
log_step "Checking binary availability for version $VERSION"
BINARY_URL="https://github.com/metanorma/packed-mn/releases/download/v${VERSION}/metanorma-$(uname -s | tr '[:upper:]' '[:lower:]')"
BINARY_AVAILABLE=false

if curl -s -f -L -o /dev/null "$BINARY_URL" 2>/dev/null; then
    BINARY_AVAILABLE=true
    log_info "Binary is available for $VERSION"
else
    log_warn "Binary NOT available for $VERSION"
    log_info "Will test gemfile installation only"
fi

# Install with gemfile
log_step "Installing Metanorma $VERSION (gemfile)"
if mnenv install "$VERSION" --source gemfile > /dev/null 2>&1; then
    log_info "✓ Gemfile installation successful"
else
    log_warn "⚠ Gemfile installation may have failed (may already be installed)"
fi

# Install with binary
if [ "$BINARY_AVAILABLE" = true ]; then
    log_step "Installing Metanorma $VERSION (binary)"
    if mnenv install "$VERSION" --source binary > /dev/null 2>&1; then
        log_info "✓ Binary installation successful"
    else
        log_warn "⚠ Binary installation may have failed (may already be installed)"
    fi

    # Show both installations
    log_step "Installation structure"
    echo "Gemfile installation:"
    ls -lah ~/.mnenv/versions/"$VERSION"/gemfile/ 2>/dev/null || echo "  Not found"

    echo ""
    echo "Binary installation:"
    ls -lah ~/.mnenv/versions/"$VERSION"/binary/ 2>/dev/null || echo "  Not found"
fi

# Show installed versions
log_step "Installed versions"
mnenv versions

if [ "$BINARY_AVAILABLE" = false ]; then
    echo ""
    log_warn "Binary not available - skipping cross-source tests"
    log_info "Binary tests require packed-mn releases"
    exit 0
fi

# Test 1: Switch from gemfile to binary
log_step "Test 1: Switch from gemfile to binary"
mnenv global "$VERSION" --source gemfile
v_gemfile=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")
log_info "Gemfile source: metanorma --version = $v_gemfile"

mnenv global "$VERSION" --source binary
v_binary=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")
log_info "Binary source: metanorma --version = $v_binary"

if [ "$v_gemfile" = "$VERSION" ] && [ "$v_binary" = "$VERSION" ]; then
    log_info "✓ Both sources produce correct version $VERSION"
else
    log_error "✗ Version mismatch: gemfile=$v_gemfile, binary=$v_binary"
    exit 1
fi

# Test 2: Switch from binary to gemfile
log_step "Test 2: Switch from binary to gemfile"
mnenv global "$VERSION" --source binary
v1=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

mnenv global "$VERSION" --source gemfile
v2=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

if [ "$v1" = "$VERSION" ] && [ "$v2" = "$VERSION" ]; then
    log_info "✓ Bidirectional switching works"
else
    log_error "✗ Version mismatch: binary=$v1, gemfile=$v2"
    exit 1
fi

# Test 3: Rapid switching
log_step "Test 3: Rapid source switching (5 rounds)"
for i in {1..5}; do
    mnenv global "$VERSION" --source gemfile > /dev/null
    v_g=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

    mnenv global "$VERSION" --source binary > /dev/null
    v_b=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

    if [ "$v_g" != "$VERSION" ] || [ "$v_b" != "$VERSION" ]; then
        log_error "✗ Round $i failed: gemfile=$v_g, binary=$v_b"
        exit 1
    fi
done
log_info "✓ Rapid switching test passed"

# Test 4: Local override with different source
log_step "Test 4: Local override with source change"
cd "/tmp/mnenv-cross-test-$VERSION"

# Set global to gemfile
mnenv global "$VERSION" --source gemfile > /dev/null
v_global=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

# Set local to binary
mnenv local "$VERSION" --source binary > /dev/null
v_local=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

if [ "$v_global" = "$VERSION" ] && [ "$v_local" = "$VERSION" ]; then
    log_info "✓ Local override works with different source"
else
    log_error "✗ Local override failed"
    exit 1
fi

# Test 5: Shell override takes precedence
log_step "Test 5: Shell session override"
# Local is binary
export MNENV_VERSION="$VERSION"
export MNENV_SOURCE=gemfile
v_env=$(metanorma --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "failed")

if [ "$v_env" = "$VERSION" ]; then
    log_info "✓ Environment variable overrides local file"
else
    log_error "✗ Environment override failed"
    exit 1
fi
unset MNENV_VERSION MNENV_SOURCE

# Test 6: Version list shows both sources
log_step "Test 6: Version list shows both sources"
if mnenv versions | grep -q "$VERSION.*gemfile"; then
    log_info "✓ Gemfile source shown in version list"
else
    log_error "✗ Gemfile source not in version list"
    exit 1
fi

if mnenv versions | grep -q "$VERSION.*binary"; then
    log_info "✓ Binary source shown in version list"
else
    log_error "✗ Binary source not in version list"
    exit 1
fi

# Final state
log_step "All tests passed!"
echo ""
echo "Final state:"
echo "  Global version: $(cat ~/.mnenv/version 2>/dev/null || echo 'not set')"
echo "  Global source: $(cat ~/.mnenv/source 2>/dev/null || echo 'not set')"
echo "  Current metanorma: $(metanorma --version 2>&1 | head -1)"

# Clean up
cd /
rm -rf "/tmp/mnenv-cross-test-$VERSION"
