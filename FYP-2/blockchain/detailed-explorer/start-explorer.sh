#!/bin/bash
#
# Start the Detailed Blockchain Explorer
# This script starts the API server on port 3001
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  DFIR Chain-of-Custody - Detailed Explorer"
echo "=============================================="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not installed."
    exit 1
fi

# Check Flask
if ! python3 -c "import flask" 2>/dev/null; then
    echo "Installing Flask and dependencies..."
    pip3 install flask flask-cors
fi

# Check if port 3001 is already in use
if lsof -i :3001 &>/dev/null; then
    echo "WARNING: Port 3001 is already in use."
    echo "Kill the existing process? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        lsof -ti :3001 | xargs kill -9 2>/dev/null || true
        sleep 1
    else
        echo "Aborting..."
        exit 1
    fi
fi

echo ""
echo "Starting Detailed Blockchain Explorer API..."
echo ""
echo "Access the explorer at: http://localhost:3001"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""
echo "=============================================="

# Start the API server
python3 block-explorer-api.py
