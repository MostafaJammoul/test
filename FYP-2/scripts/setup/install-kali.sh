#!/bin/bash
#
# Complete Setup Script for Kali Linux
# This script installs all dependencies and deploys the DFIR blockchain system
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}DFIR Blockchain Setup for Kali Linux${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run as root. Run as regular user."
    exit 1
fi

# Step 1: Update system
step1_update_system() {
    print_step "Step 1: Updating system packages"
    echo ""

    sudo apt-get update
    sudo apt-get upgrade -y

    print_status "System updated successfully"
    echo ""
}

# Step 2: Install Docker
step2_install_docker() {
    print_step "Step 2: Installing Docker"
    echo ""

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_warning "Docker is already installed"
        docker --version
    else
        # Install dependencies
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        # Set up the repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker Engine
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Add current user to docker group
        sudo usermod -aG docker $USER

        print_status "Docker installed successfully"
    fi

    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker

    print_status "Docker version:"
    docker --version
    echo ""
}

# Step 3: Install Docker Compose
step3_install_docker_compose() {
    print_step "Step 3: Installing Docker Compose"
    echo ""

    # Docker Compose v2 is installed as a plugin with Docker, but we'll also install standalone
    if command -v docker-compose &> /dev/null; then
        print_warning "Docker Compose is already installed"
        docker-compose --version
    else
        # Install docker-compose-plugin (v2)
        sudo apt-get install -y docker-compose-plugin

        # Also install standalone version
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        print_status "Docker Compose installed successfully"
    fi

    print_status "Docker Compose version:"
    docker-compose --version
    echo ""
}

# Step 4: Install Go
step4_install_go() {
    print_step "Step 4: Installing Go"
    echo ""

    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}')
        print_warning "Go is already installed: $GO_VERSION"
    else
        # Download and install Go 1.21
        GO_VERSION="1.21.6"
        wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
        rm go${GO_VERSION}.linux-amd64.tar.gz

        # Add Go to PATH
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin
        export GOPATH=$HOME/go

        print_status "Go installed successfully"
    fi

    print_status "Go version:"
    /usr/local/go/bin/go version
    echo ""
}

# Step 5: Install additional tools
step5_install_tools() {
    print_step "Step 5: Installing additional tools"
    echo ""

    sudo apt-get install -y \
        git \
        curl \
        wget \
        jq \
        python3 \
        python3-pip \
        build-essential \
        libtool \
        autoconf \
        unzip

    print_status "Additional tools installed successfully"
    echo ""
}

# Step 6: Clone repository
step6_clone_repo() {
    print_step "Step 6: Cloning repository"
    echo ""

    # Ask for repository URL
    read -p "Enter the repository URL (or press Enter for default GitHub URL): " REPO_URL

    if [ -z "$REPO_URL" ]; then
        REPO_URL="https://github.com/omar-kaaki/FYP-2.git"
        print_status "Using default repository: $REPO_URL"
    fi

    # Clone to home directory
    cd ~

    if [ -d "FYP-2" ]; then
        print_warning "FYP-2 directory already exists. Removing it..."
        rm -rf FYP-2
    fi

    git clone $REPO_URL
    cd FYP-2

    # Checkout the correct branch
    git checkout claude/blockchain-dfir-implementation-HW9NU

    print_status "Repository cloned successfully"
    print_status "Location: $(pwd)"
    echo ""
}

# Step 7: Download Hyperledger Fabric binaries
step7_download_fabric() {
    print_step "Step 7: Downloading Hyperledger Fabric binaries"
    echo ""

    cd ~/FYP-2

    # Download Fabric binaries
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 3.0.0 1.5.7 -s

    # Create bin directory and copy binaries
    mkdir -p fabric-network/bin
    cp -r fabric-samples/bin/* fabric-network/bin/
    cp -r fabric-samples/config fabric-network/

    # Clean up
    rm -rf fabric-samples

    print_status "Fabric binaries downloaded and installed"
    print_status "Binaries location: $(pwd)/fabric-network/bin"
    echo ""
}

# Step 8: Set permissions
step8_set_permissions() {
    print_step "Step 8: Setting permissions"
    echo ""

    cd ~/FYP-2

    # Make all scripts executable
    chmod +x scripts/deploy/*.sh
    chmod +x scripts/test/*.sh

    print_status "Permissions set successfully"
    echo ""
}

# Step 9: Verify Docker access
step9_verify_docker() {
    print_step "Step 9: Verifying Docker access"
    echo ""

    # Test Docker without sudo
    if docker ps > /dev/null 2>&1; then
        print_status "Docker access verified (no sudo needed)"
    else
        print_warning "Docker requires sudo or you need to log out and log back in"
        print_warning "After this script completes, please run: newgrp docker"
        print_warning "Or log out and log back in to apply docker group membership"
    fi
    echo ""
}

# Step 10: Display summary and next steps
step10_display_summary() {
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""

    print_status "Installed Components:"
    echo "  ✓ Docker $(docker --version | awk '{print $3}')"
    echo "  ✓ Docker Compose $(docker-compose --version | awk '{print $4}')"
    echo "  ✓ Go $(/usr/local/go/bin/go version | awk '{print $3}')"
    echo "  ✓ Hyperledger Fabric 3.0.0 binaries"
    echo "  ✓ DFIR Blockchain repository"
    echo ""

    print_status "Project Location:"
    echo "  ~/FYP-2"
    echo ""

    print_status "IMPORTANT: Docker Group Membership"
    echo "  If you just installed Docker, you need to activate the docker group:"
    echo ""
    echo "  ${YELLOW}Option 1 (Quick):${NC}"
    echo "    newgrp docker"
    echo ""
    echo "  ${YELLOW}Option 2 (Recommended):${NC}"
    echo "    Log out and log back in"
    echo ""

    print_status "Next Steps to Deploy Blockchain:"
    echo ""
    echo "  ${BLUE}1. If needed, activate docker group:${NC}"
    echo "     newgrp docker"
    echo ""
    echo "  ${BLUE}2. Navigate to project directory:${NC}"
    echo "     cd ~/FYP-2"
    echo ""
    echo "  ${BLUE}3. Run the complete deployment:${NC}"
    echo "     ./scripts/deploy/complete-setup.sh"
    echo ""
    echo "  ${BLUE}Or run step-by-step:${NC}"
    echo "     ./scripts/deploy/setup-ca.sh"
    echo "     ./scripts/deploy/generate-artifacts.sh"
    echo "     ./scripts/deploy/start-hot-chain.sh"
    echo "     ./scripts/deploy/create-channel-hot.sh"
    echo "     ./scripts/deploy/deploy-chaincode.sh hot"
    echo "     ./scripts/test/test-chaincode.sh hot"
    echo ""

    print_status "Documentation:"
    echo "  - Quick Start: ~/FYP-2/BLOCKCHAIN_README.md"
    echo "  - Full Guide:  ~/FYP-2/DEPLOYMENT_GUIDE.md"
    echo ""
}

# Main execution
main() {
    print_status "This script will install all dependencies and set up the DFIR blockchain"
    print_status "Estimated time: 10-15 minutes"
    echo ""

    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo ""

    step1_update_system
    step2_install_docker
    step3_install_docker_compose
    step4_install_go
    step5_install_tools
    step6_clone_repo
    step7_download_fabric
    step8_set_permissions
    step9_verify_docker
    step10_display_summary
}

# Run main function
main "$@"
