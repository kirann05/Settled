#!/bin/bash

# Settled Infrastructure Deployment Script
# Industry-standard Firebase deployment with environment management

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRASTRUCTURE_DIR="$(dirname "$SCRIPT_DIR")"
FIREBASE_DIR="$INFRASTRUCTURE_DIR/firebase"
PROJECT_ROOT="$(dirname "$INFRASTRUCTURE_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-dev}
COMPONENTS=${2:-all}
DRY_RUN=${3:-false}

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

# Validation functions
validate_environment() {
    if [[ ! -f "$FIREBASE_DIR/environments/$1.json" ]]; then
        log_error "Environment configuration not found: $1.json"
        log_info "Available environments: $(ls "$FIREBASE_DIR/environments/" | sed 's/.json//g' | tr '\n' ' ')"
        exit 1
    fi
}

validate_firebase_cli() {
    if ! command -v firebase &> /dev/null; then
        log_error "Firebase CLI not found. Install with: npm install -g firebase-tools"
        exit 1
    fi
    
    log_info "Firebase CLI version: $(firebase --version)"
}

validate_authentication() {
    if ! firebase projects:list &> /dev/null; then
        log_error "Firebase authentication required. Run: firebase login"
        exit 1
    fi
}

# Deployment functions  
deploy_firestore_rules() {
    log_info "Deploying Firestore security rules..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would deploy Firestore rules"
        return 0
    fi
    
    firebase deploy --only firestore:rules --project="$(get_project_id)"
    log_success "Firestore rules deployed successfully"
}

deploy_firestore_indexes() {
    log_info "Deploying Firestore composite indexes..."
    log_warning "Index deployment can take 5-10 minutes. Please wait..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would deploy Firestore indexes"
        return 0
    fi
    
    firebase deploy --only firestore:indexes --project="$(get_project_id)"
    log_success "Firestore indexes deployed successfully"
}

deploy_functions() {
    log_info "Deploying Cloud Functions..."
    
    if [[ ! -d "$PROJECT_ROOT/functions" ]]; then
        log_warning "Functions directory not found. Skipping functions deployment."
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would deploy Cloud Functions"
        return 0
    fi
    
    firebase deploy --only functions --project="$(get_project_id)"
    log_success "Cloud Functions deployed successfully"
}

# Helper functions
get_project_id() {
    grep -o '"projectId": "[^"]*' "$FIREBASE_DIR/environments/$ENVIRONMENT.json" | cut -d'"' -f4
}

show_deployment_summary() {
    local project_id=$(get_project_id)
    
    echo ""
    log_success "🚀 Deployment Summary"
    echo "======================================"
    echo "Environment: $ENVIRONMENT"
    echo "Project ID:  $project_id" 
    echo "Components:  $COMPONENTS"
    echo "Dry Run:     $DRY_RUN"
    echo "======================================"
    echo ""
    
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "🔗 Firebase Console: https://console.firebase.google.com/project/$project_id"
        echo "📊 Firestore Database: https://console.firebase.google.com/project/$project_id/firestore"
        echo ""
    fi
}

# Main deployment logic
main() {
    echo ""
    log_info "🏗️  Settled Infrastructure Deployment"
    echo "=========================================="
    
    # Change to Firebase directory
    cd "$FIREBASE_DIR"
    
    # Validation steps
    log_info "Validating deployment environment..."
    validate_environment "$ENVIRONMENT"
    validate_firebase_cli
    validate_authentication
    
    # Set Firebase project
    local project_id=$(get_project_id)
    log_info "Using Firebase project: $project_id"
    firebase use "$project_id" --quiet
    
    # Deploy components based on selection
    case $COMPONENTS in
        "rules")
            deploy_firestore_rules
            ;;
        "indexes") 
            deploy_firestore_indexes
            ;;
        "functions")
            deploy_functions
            ;;
        "firestore")
            deploy_firestore_rules
            deploy_firestore_indexes
            ;;
        "all")
            deploy_firestore_rules
            deploy_firestore_indexes
            deploy_functions
            ;;
        *)
            log_error "Invalid component: $COMPONENTS"
            log_info "Valid components: rules, indexes, functions, firestore, all"
            exit 1
            ;;
    esac
    
    # Show summary
    show_deployment_summary
    log_success "✅ Deployment completed successfully!"
}

# Usage function
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [COMPONENTS] [DRY_RUN]"
    echo ""
    echo "Parameters:"
    echo "  ENVIRONMENT  Target environment (dev, staging, prod) [default: dev]"
    echo "  COMPONENTS   Components to deploy (rules, indexes, functions, firestore, all) [default: all]"
    echo "  DRY_RUN      Preview deployment without executing (true, false) [default: false]"
    echo ""
    echo "Examples:"
    echo "  $0                              # Deploy all components to dev"
    echo "  $0 staging                      # Deploy all components to staging"
    echo "  $0 prod firestore              # Deploy only Firestore to production"
    echo "  $0 dev indexes true            # Preview index deployment to dev"
    echo ""
    echo "Available environments: $(ls "$FIREBASE_DIR/environments/" 2>/dev/null | sed 's/.json//g' | tr '\n' ' ' || echo 'None found')"
}

# Handle help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Run main deployment
main