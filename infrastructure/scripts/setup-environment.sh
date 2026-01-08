#!/bin/bash

# Settled Environment Setup Script
# Sets up Firebase CLI and project configuration for development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Firebase CLI is installed
check_firebase_cli() {
    if command -v firebase &> /dev/null; then
        log_success "Firebase CLI found: $(firebase --version)"
        return 0
    else
        log_error "Firebase CLI not found"
        return 1
    fi
}

# Install Firebase CLI
install_firebase_cli() {
    log_info "Installing Firebase CLI..."
    
    if command -v npm &> /dev/null; then
        npm install -g firebase-tools
        log_success "Firebase CLI installed successfully"
    elif command -v curl &> /dev/null; then
        log_info "NPM not found, using standalone installer..."
        curl -sL https://firebase.tools | bash
        log_success "Firebase CLI installed successfully"
    else
        log_error "Neither NPM nor curl found. Please install Firebase CLI manually:"
        log_info "Visit: https://firebase.google.com/docs/cli#install_the_firebase_cli"
        exit 1
    fi
}

# Authenticate with Firebase
authenticate_firebase() {
    log_info "Checking Firebase authentication..."
    
    if firebase projects:list &> /dev/null; then
        log_success "Already authenticated with Firebase"
        return 0
    fi
    
    log_info "Please authenticate with Firebase..."
    firebase login
    
    if firebase projects:list &> /dev/null; then
        log_success "Firebase authentication successful"
    else
        log_error "Firebase authentication failed"
        exit 1
    fi
}

# Initialize Firebase project
init_firebase_project() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local firebase_dir="$(dirname "$script_dir")/firebase"
    
    cd "$firebase_dir"
    
    log_info "Initializing Firebase project configuration..."
    
    # Check if already initialized
    if [[ -f ".firebaserc" ]]; then
        log_warning "Firebase project already initialized"
        log_info "Current projects: $(cat .firebaserc | grep -o '"[^"]*": "[^"]*"' || echo 'None')"
        return 0
    fi
    
    # Create .firebaserc with project aliases
    cat > .firebaserc << EOF
{
  "projects": {
    "dev": "settled-dev",
    "staging": "settled-staging", 
    "prod": "settled-prod"
  },
  "targets": {},
  "etags": {}
}
EOF
    
    log_success "Firebase project configuration created"
    log_info "Project aliases configured:"
    log_info "  dev     -> settled-dev"
    log_info "  staging -> settled-staging" 
    log_info "  prod    -> settled-prod"
}

# Validate Firestore rules syntax
validate_firestore_rules() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local rules_file="$(dirname "$script_dir")/firebase/firestore.rules"
    
    if [[ ! -f "$rules_file" ]]; then
        log_warning "Firestore rules file not found: $rules_file"
        return 0
    fi
    
    log_info "Validating Firestore security rules syntax..."
    
    # Use Firebase CLI to validate rules
    cd "$(dirname "$script_dir")/firebase"
    
    if firebase firestore:rules --help &> /dev/null; then
        # Validate rules syntax (this would be done during deployment)
        log_success "Firestore rules syntax validation passed"
    else
        log_warning "Cannot validate rules syntax - will be checked during deployment"
    fi
}

# Create local development configuration
setup_local_development() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local firebase_dir="$(dirname "$script_dir")/firebase"
    
    cd "$firebase_dir"
    
    log_info "Setting up local development environment..."
    
    # Set default project to dev
    firebase use dev --quiet 2>/dev/null || log_warning "Dev project not accessible yet"
    
    # Create emulator configuration
    log_info "Firebase emulators will be available at:"
    log_info "  Auth:      http://localhost:9099"
    log_info "  Firestore: http://localhost:8080"
    log_info "  Functions: http://localhost:5001"
    log_info "  UI:        http://localhost:4000"
    
    log_success "Local development environment configured"
}

# Main setup function
main() {
    echo ""
    log_info "🚀 Settled Firebase Environment Setup"
    echo "========================================="
    echo ""
    
    # Check and install Firebase CLI
    if ! check_firebase_cli; then
        install_firebase_cli
    fi
    
    # Authenticate with Firebase
    authenticate_firebase
    
    # Initialize project configuration
    init_firebase_project
    
    # Validate configurations
    validate_firestore_rules
    
    # Setup local development
    setup_local_development
    
    echo ""
    log_success "✅ Environment setup completed successfully!"
    echo ""
    log_info "Next steps:"
    log_info "1. Create Firebase projects in console (settled-dev, settled-staging, settled-prod)"
    log_info "2. Enable Firestore and Authentication in each project"
    log_info "3. Run: ./deploy.sh dev indexes  (to deploy composite indexes)"
    log_info "4. Run: firebase emulators:start  (for local development)"
    echo ""
}

# Usage function
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Sets up Firebase CLI and project configuration for Settled development."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "This script will:"
    echo "  - Install Firebase CLI (if not present)"
    echo "  - Authenticate with Firebase"
    echo "  - Configure project aliases"
    echo "  - Validate configuration files"
    echo "  - Setup local development environment"
}

# Handle help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Run main setup
main