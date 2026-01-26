#!/bin/bash
# Start JumpServer-Fabric API Bridge

cd "$(dirname "$0")"

echo "================================"
echo "JumpServer-Fabric API Bridge"
echo "================================"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
    echo ""
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "✓ Created .env file"
    echo "  Please review and update the configuration if needed"
    echo ""
fi

# Start server
echo "Starting API bridge..."
echo ""
npm start
