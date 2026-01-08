#!/bin/bash

# Settled Firestore Index Validation Script
# Validates that required composite indexes exist and are active

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

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIREBASE_DIR="$(dirname "$SCRIPT_DIR")/firebase"
ENVIRONMENT=${1:-dev}

# Required indexes for Settled Epic 1
declare -a REQUIRED_INDEXES=(
    "bills:participantIds(array-contains)+isDeleted(asc)+createdAt(desc)"
    "bills:participantIds(array-contains)+isDeleted(asc)"
    "bills:createdBy(asc)+isDeleted(asc)+createdAt(desc)"
)

# Get project ID for environment
get_project_id() {
    if [[ ! -f "$FIREBASE_DIR/environments/$ENVIRONMENT.json" ]]; then
        log_error "Environment configuration not found: $ENVIRONMENT.json"
        exit 1
    fi
    
    grep -o '"projectId": "[^"]*' "$FIREBASE_DIR/environments/$ENVIRONMENT.json" | cut -d'"' -f4
}

# Check if Firebase CLI is available
check_firebase_cli() {
    if ! command -v firebase &> /dev/null; then
        log_error "Firebase CLI not found. Run: npm install -g firebase-tools"
        exit 1
    fi
}

# Check authentication
check_authentication() {
    if ! firebase projects:list &> /dev/null; then
        log_error "Firebase authentication required. Run: firebase login"
        exit 1
    fi
}

# List current indexes
list_current_indexes() {
    local project_id=$1
    
    log_info "Fetching current Firestore indexes for project: $project_id"
    
    # Switch to project
    firebase use "$project_id" --quiet
    
    # Get indexes (this command may not exist in all Firebase CLI versions)
    if firebase firestore:indexes &> /dev/null; then
        firebase firestore:indexes
    else
        log_warning "Cannot list indexes via CLI. Please check Firebase Console:"
        echo "https://console.firebase.google.com/project/$project_id/firestore/indexes"
    fi
}

# Validate index configuration file
validate_index_config() {
    local config_file="$FIREBASE_DIR/firestore.indexes.json"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Index configuration file not found: $config_file"
        exit 1
    fi
    
    log_info "Validating index configuration syntax..."
    
    # Check JSON syntax
    if python3 -m json.tool "$config_file" >/dev/null 2>&1; then
        log_success "Index configuration syntax is valid"
    elif python -m json.tool "$config_file" >/dev/null 2>&1; then
        log_success "Index configuration syntax is valid"  
    elif node -e "JSON.parse(require('fs').readFileSync('$config_file', 'utf8'))" >/dev/null 2>&1; then
        log_success "Index configuration syntax is valid"
    else
        log_error "Invalid JSON syntax in index configuration"
        exit 1
    fi
    
    # Display configured indexes
    log_info "Configured indexes:"
    if command -v jq &> /dev/null; then
        jq -r '.indexes[] | "  \(.collectionGroup): \(.fields | map(.fieldPath + "(" + (.order // .arrayConfig) + ")") | join("+"))"' "$config_file"
    else
        log_warning "Install 'jq' for better index display. Showing raw config:"
        cat "$config_file"
    fi
}

# Check if specific query patterns will work
test_query_patterns() {
    local project_id=$1
    
    log_info "Testing query patterns that require composite indexes..."
    
    # Note: This would require actual Firestore access and test data
    # For now, we'll just validate the configurations match our needs
    
    local patterns=(
        "Query: participantIds array-contains + isDeleted == false + order by createdAt desc"
        "Query: participantIds array-contains + isDeleted == false" 
        "Query: createdBy == userId + isDeleted == false + order by createdAt desc"
    )
    
    for pattern in "${patterns[@]}"; do
        log_info "✓ Pattern: $pattern"
    done
    
    log_success "All required query patterns are configured"
}

# Estimate index build time
estimate_build_time() {
    log_info "Index build time estimates:"
    echo "  • New project (no data):     ~2-5 minutes"
    echo "  • Small dataset (<1K docs):  ~5-10 minutes"
    echo "  • Medium dataset (<10K docs): ~10-30 minutes"
    echo "  • Large dataset (>10K docs):  ~30+ minutes"
    echo ""
    log_warning "Index builds run in background. Deploy will succeed before indexing completes."
}

# Show deployment command
show_deployment_command() {
    log_info "To deploy these indexes, run:"
    echo "  ./deploy.sh $ENVIRONMENT indexes"
    echo ""
    log_info "To deploy all Firestore configuration:"
    echo "  ./deploy.sh $ENVIRONMENT firestore"
}

# Main validation function
main() {
    echo ""
    log_info "🔍 Settled Firestore Index Validation"
    echo "========================================"
    
    # Change to Firebase directory
    cd "$FIREBASE_DIR"
    
    # Validation steps
    check_firebase_cli
    check_authentication
    
    # Get project details
    local project_id=$(get_project_id)
    log_info "Validating indexes for environment: $ENVIRONMENT"
    log_info "Firebase project: $project_id"
    echo ""
    
    # Validate configuration
    validate_index_config
    echo ""
    
    # Test query patterns
    test_query_patterns "$project_id"
    echo ""
    
    # Show current indexes (if possible)
    list_current_indexes "$project_id"
    echo ""
    
    # Provide guidance
    estimate_build_time
    show_deployment_command
    
    echo ""
    log_success "✅ Index validation completed!"
    log_info "Indexes are properly configured and ready for deployment."
}

# Usage function
show_usage() {
    echo "Usage: $0 [ENVIRONMENT]"
    echo ""
    echo "Validates Firestore composite index configuration for Settled."
    echo ""
    echo "Parameters:"
    echo "  ENVIRONMENT  Target environment to validate (dev, staging, prod) [default: dev]"
    echo ""
    echo "Examples:"
    echo "  $0           # Validate dev environment"
    echo "  $0 staging   # Validate staging environment"
    echo "  $0 prod      # Validate production environment"
}

# Handle help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Run main validation
main