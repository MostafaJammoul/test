#!/bin/bash
# Check FYP-2 Blockchain Status
# Run this on your blockchain VM (VM 2)

echo "================================"
echo "FYP-2 Blockchain Status Check"
echo "================================"
echo ""

echo "1. Docker Containers:"
echo "--------------------"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "peer|orderer|couchdb|ipfs"
echo ""

echo "2. Hyperledger Fabric Peers:"
echo "---------------------------"
docker logs peer0.forensiclab.hot.coc.com 2>&1 | tail -5 || echo "Hot peer not found"
docker logs peer0.forensiclab.cold.coc.com 2>&1 | tail -5 || echo "Cold peer not found"
echo ""

echo "3. IPFS Cluster:"
echo "---------------"
docker exec ipfs-lab ipfs id 2>/dev/null | grep "ID" || echo "IPFS not running"
echo ""

echo "4. Open Ports:"
echo "-------------"
netstat -tuln 2>/dev/null | grep -E ":(5001|7051|9051|9094)" || ss -tuln | grep -E ":(5001|7051|9051|9094)"
echo ""

echo "5. Chaincode Installed:"
echo "----------------------"
docker exec peer0.forensiclab.hot.coc.com peer lifecycle chaincode queryinstalled 2>/dev/null || echo "Cannot query chaincode"
echo ""

echo "================================"
echo "Status check complete!"
echo "================================"
