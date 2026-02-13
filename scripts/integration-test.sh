#!/bin/bash
# Local integration test script for mnenv
# Usage: ./scripts/integration-test.sh [gemfile|binary]

set -e

# Configuration
MNENV_VERSION="${MNENV_VERSION:-1.14.4}"
METHOD="${1:-gemfile}"
SAMPLES_REPO="${SAMPLES_REPO:-metanorma/mn-samples-cc}"
SAMPLES_DIR="/tmp/mn-samples-cc"

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

# Check if we're in the mnenv directory
if [ ! -f "mnenv.gemspec" ]; then
    log_error "Please run this script from the mnenv root directory"
    exit 1
fi

# Check if mnenv is installed
if ! command -v mnenv &> /dev/null; then
    log_info "Installing mnenv..."
    bundle install
    rake install
else
    log_info "mnenv is already installed"
fi

# Install Metanorma
log_info "Installing Metanorma ${MNENV_VERSION} (method: ${METHOD})..."
mnenv install "${MNENV_VERSION}" --source "${METHOD}"
mnenv global "${MNENV_VERSION}" --source "${METHOD}"

# Show installed versions
log_info "Installed versions:"
mnenv versions

# Clone or update samples repository
if [ -d "$SAMPLES_DIR" ]; then
    log_info "Updating samples repository..."
    cd "$SAMPLES_DIR"
    git pull
else
    log_info "Cloning samples repository..."
    git clone "https://github.com/${SAMPLES_REPO}.git" "$SAMPLES_DIR"
    cd "$SAMPLES_DIR"
fi

# Test single document compilation
log_info "Testing single document compilation..."
if metanorma compile sources/cc-18011.adoc; then
    log_info "Document compilation successful"
    ls -lah sources/cc-18011.* 2>/dev/null || true
else
    log_error "Document compilation failed"
    exit 1
fi

# Test site generation
log_info "Testing site generation..."
if metanorma site generate --agree-to-terms; then
    log_info "Site generation successful"
    if [ -d "site" ]; then
        log_info "Site contents:"
        ls -lah site/ | head -20
    fi
else
    log_error "Site generation failed"
    exit 1
fi

log_info "All tests passed!"
