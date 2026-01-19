#!/bin/bash
# =============================================================================
# JumpServer Blockchain - Stop Services Script
# =============================================================================
# This script stops both the Django backend and React frontend development
# servers.
#
# Usage:
#   ./stop_services.sh
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_info "Stopping JumpServer services..."

# Stop backend (port 8080)
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    BACKEND_PID=$(lsof -Pi :8080 -sTCP:LISTEN -t)
    kill $BACKEND_PID 2>/dev/null
    log_success "Backend stopped (PID: $BACKEND_PID)"
else
    log_info "Backend not running"
fi

# Stop frontend (port 3000)
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    FRONTEND_PID=$(lsof -Pi :3000 -sTCP:LISTEN -t)
    kill $FRONTEND_PID 2>/dev/null
    log_success "Frontend stopped (PID: $FRONTEND_PID)"
else
    log_info "Frontend not running"
fi

# Also kill any remaining Python runserver or npm processes
pkill -f "manage.py runserver" 2>/dev/null && log_info "Killed remaining Django processes"
pkill -f "vite" 2>/dev/null && log_info "Killed remaining Vite processes"

log_success "All services stopped"
