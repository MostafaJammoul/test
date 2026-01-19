#!/bin/bash
# Development startup script for JumpServer Blockchain Chain of Custody

set -e

PROJECT_DIR="/home/user/test"
VENV_DIR="$PROJECT_DIR/venv"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting JumpServer Blockchain Chain of Custody...${NC}"

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    jobs -p | xargs -r kill 2>/dev/null
    exit 0
}

trap cleanup SIGINT SIGTERM

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}Virtual environment not found. Run setup.sh first.${NC}"
    exit 1
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Check if PostgreSQL is running
if ! pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
    echo -e "${YELLOW}Starting PostgreSQL...${NC}"
    sudo systemctl start postgresql || sudo service postgresql start
    sleep 2
fi

# Check if Redis is running
if ! redis-cli ping >/dev/null 2>&1; then
    echo -e "${YELLOW}Starting Redis...${NC}"
    sudo systemctl start redis || sudo service redis-server start
    sleep 1
fi

# Start Django backend
echo -e "${GREEN}Starting Django backend on 0.0.0.0:8080...${NC}"
cd "$PROJECT_DIR/apps"
python manage.py runserver 0.0.0.0:8080 &
DJANGO_PID=$!

# Wait for Django to start
sleep 3

# Check if Django started successfully
if ! kill -0 $DJANGO_PID 2>/dev/null; then
    echo -e "${RED}Failed to start Django backend${NC}"
    exit 1
fi

# Start Vite frontend
echo -e "${GREEN}Starting Vite frontend on 0.0.0.0:3000...${NC}"
cd "$PROJECT_DIR/frontend"
npm run dev &
VITE_PID=$!

# Wait for Vite to start
sleep 3

# Check if Vite started successfully
if ! kill -0 $VITE_PID 2>/dev/null; then
    echo -e "${RED}Failed to start Vite frontend${NC}"
    kill $DJANGO_PID 2>/dev/null
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Services started successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Django Backend:  ${YELLOW}http://192.168.148.154:8080${NC}"
echo -e "Vite Frontend:   ${YELLOW}http://192.168.148.154:3000${NC}"
echo -e "Django Admin:    ${YELLOW}http://192.168.148.154:8080/admin${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Press ${RED}Ctrl+C${NC} to stop all services"
echo -e "${GREEN}========================================${NC}"

# Wait for both processes
wait
