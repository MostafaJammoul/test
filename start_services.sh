#!/bin/bash
# =============================================================================
# JumpServer Blockchain - Start Services Script
# =============================================================================
# This script starts both the Django backend and React frontend development
# servers for the JumpServer Blockchain Chain of Custody application.
#
# Usage:
#   ./start_services.sh
#
# To stop:
#   Press Ctrl+C (will stop both services)
#   OR run: ./stop_services.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Cleanup function to stop services on exit
cleanup() {
    log_warning "Stopping services..."

    if [ ! -z "$BACKEND_PID" ] && ps -p $BACKEND_PID > /dev/null 2>&1; then
        log_info "Stopping backend (PID: $BACKEND_PID)..."
        kill $BACKEND_PID 2>/dev/null || true
    fi

    if [ ! -z "$FRONTEND_PID" ] && ps -p $FRONTEND_PID > /dev/null 2>&1; then
        log_info "Stopping frontend (PID: $FRONTEND_PID)..."
        kill $FRONTEND_PID 2>/dev/null || true
    fi

    log_success "Services stopped"
    exit 0
}

# Set up trap to call cleanup on Ctrl+C or script exit
trap cleanup SIGINT SIGTERM EXIT

# =============================================================================
# Check Prerequisites
# =============================================================================
log_info "Checking prerequisites..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    log_error "Virtual environment not found. Did you run setup.sh?"
    exit 1
fi

# Check if node_modules exists
if [ ! -d "frontend/node_modules" ]; then
    log_error "Frontend dependencies not installed. Did you run setup.sh?"
    exit 1
fi

log_success "Prerequisites OK"

# =============================================================================
# Check if services are already running
# =============================================================================
log_info "Checking for running services..."

if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    log_warning "Port 8080 is already in use (Backend may be running)"
    read -p "Kill existing process and continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PID=$(lsof -Pi :8080 -sTCP:LISTEN -t)
        kill $PID 2>/dev/null || true
        sleep 2
        log_info "Killed process on port 8080"
    else
        exit 1
    fi
fi

if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    log_warning "Port 3000 is already in use (Frontend may be running)"
    read -p "Kill existing process and continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PID=$(lsof -Pi :3000 -sTCP:LISTEN -t)
        kill $PID 2>/dev/null || true
        sleep 2
        log_info "Killed process on port 3000"
    else
        exit 1
    fi
fi

# =============================================================================
# Start Backend (Django)
# =============================================================================
log_info "Starting Django backend on http://0.0.0.0:8080..."

# Activate virtual environment and start Django
source venv/bin/activate

# Create logs directory if it doesn't exist
mkdir -p data/logs

# Start Django in background, redirect output to log file
cd apps
nohup python manage.py runserver 0.0.0.0:8080 > ../data/logs/backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# Wait a moment and check if backend started successfully
sleep 3
if ps -p $BACKEND_PID > /dev/null 2>&1; then
    log_success "Backend started (PID: $BACKEND_PID)"
    log_info "Backend logs: tail -f data/logs/backend.log"
else
    log_error "Backend failed to start. Check data/logs/backend.log"
    tail -20 data/logs/backend.log
    exit 1
fi

# =============================================================================
# Start Frontend (React/Vite)
# =============================================================================
log_info "Starting React frontend on http://localhost:3000..."

# Start React in background, redirect output to log file
cd frontend
nohup npm run dev > ../data/logs/frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

# Wait a moment and check if frontend started successfully
sleep 5
if ps -p $FRONTEND_PID > /dev/null 2>&1; then
    log_success "Frontend started (PID: $FRONTEND_PID)"
    log_info "Frontend logs: tail -f data/logs/frontend.log"
else
    log_error "Frontend failed to start. Check data/logs/frontend.log"
    tail -20 data/logs/frontend.log
    exit 1
fi

# =============================================================================
# Display Access Information
# =============================================================================
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}  Services Started Successfully!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
log_info "Access the application:"
echo ""
echo "  Frontend (React):  http://192.168.148.154:3000"
echo "                     http://localhost:3000"
echo ""
echo "  Backend (Django):  http://192.168.148.154:8080"
echo "                     http://localhost:8080"
echo ""
echo "  API Documentation: http://192.168.148.154:8080/api/docs"
echo "  Django Admin:      http://192.168.148.154:8080/admin"
echo ""

log_info "Superuser Credentials:"
echo "  Username: admin (or value from setup.sh)"
echo "  Password: admin (or value from setup.sh)"
echo ""

log_info "Process IDs:"
echo "  Backend:  $BACKEND_PID"
echo "  Frontend: $FRONTEND_PID"
echo ""

log_info "View Logs:"
echo "  Backend:  tail -f data/logs/backend.log"
echo "  Frontend: tail -f data/logs/frontend.log"
echo ""

log_warning "Press Ctrl+C to stop both services"
echo ""

# =============================================================================
# Keep script running and monitor services
# =============================================================================
log_info "Monitoring services... (Ctrl+C to stop)"

# Monitor both processes
while true; do
    # Check backend
    if ! ps -p $BACKEND_PID > /dev/null 2>&1; then
        log_error "Backend process died unexpectedly!"
        log_info "Last 20 lines of backend log:"
        tail -20 data/logs/backend.log
        cleanup
    fi

    # Check frontend
    if ! ps -p $FRONTEND_PID > /dev/null 2>&1; then
        log_error "Frontend process died unexpectedly!"
        log_info "Last 20 lines of frontend log:"
        tail -20 data/logs/frontend.log
        cleanup
    fi

    # Wait before next check
    sleep 5
done
