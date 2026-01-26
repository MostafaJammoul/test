# FYP-2 Blockchain Setup Guide

## Problem Diagnosis

The error "channel 'evidence-hot' not found" occurred because:

1. ❌ **Channel name mismatch**: API bridge was looking for `evidence-hot` but blockchain creates `hotchannel`
2. ❌ **Wrong peer endpoints**: `.env` pointed to Court peers instead of ForensicLab peers
3. ❌ **Channels not created**: The blockchain network was running but channels weren't created yet
4. ❌ **Chaincode not deployed**: Without channels, chaincode couldn't be deployed

## What Was Fixed

✅ Updated `/home/user/test/FYP-2/jumpserver-api/.env`:
- Channel names: `evidence-hot` → `hotchannel`, `evidence-cold` → `coldchannel`
- Hot peer endpoint: `7051` → `8051` (ForensicLab peer)
- Cold peer endpoint: `9051` → `10051` (ForensicLab peer)

## Blockchain Setup (Run on VM 2)

### Step 1: Verify Network is Running

```bash
cd ~/Desktop/FYP-2/blockchain
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(hot|cold)"
```

**Expected output:** You should see containers like:
- `peer0.forensiclab.hot.coc.com`
- `peer0.court.hot.coc.com`
- `orderer.hot.coc.com`
- (and cold chain equivalents)

**If containers are NOT running:**
```bash
cd ~/Desktop/FYP-2/blockchain
./start-all.sh
```

---

### Step 2: Create Channels

```bash
cd ~/Desktop/FYP-2/blockchain/scripts
./setup-network.sh channel
```

This creates:
- `hotchannel` on hot chain
- `coldchannel` on cold chain

**Expected output:**
```
✓ Channel hotchannel created on HOT chain (all orderers joined)
✓ Channel coldchannel created on COLD chain (all orderers joined)
```

---

### Step 3: Join Peers to Channels

```bash
cd ~/Desktop/FYP-2/blockchain/scripts
./setup-network.sh join
```

This joins both ForensicLab and Court peers to their respective channels.

**Expected output:**
```
✓ All peers joined to hotchannel
✓ All peers joined to coldchannel
```

---

### Step 4: Update Anchor Peers

```bash
cd ~/Desktop/FYP-2/blockchain/scripts
./setup-network.sh anchor
```

This sets up peer discovery between organizations.

---

### Step 5: Deploy Chaincode

```bash
cd ~/Desktop/FYP-2/blockchain/scripts
./deploy-chaincode.sh deploy
```

This will:
1. Package the chaincode
2. Install on all peers (ForensicLab + Court, Hot + Cold)
3. Approve for both organizations
4. Commit to channels

**Expected output:**
```
✓ Chaincode packaged as coc.tar.gz
✓ Chaincode installed on forensiclab peer (HOT chain)
✓ Chaincode installed on court peer (HOT chain)
✓ Chaincode approved by forensiclab (HOT chain)
✓ Chaincode approved by court (HOT chain)
✓ Chaincode committed on HOT chain
✓ Chaincode deployed to HOT chain
✓ Chaincode deployed to COLD chain
```

---

### Step 6: Verify Deployment

Check that chaincode is committed on both channels:

```bash
docker exec cli.hot peer lifecycle chaincode querycommitted -C hotchannel --name coc
docker exec cli.cold peer lifecycle chaincode querycommitted -C coldchannel --name coc
```

**Expected output (for each):**
```
Committed chaincode definition for chaincode 'coc' on channel 'hotchannel':
Version: 1.0, Sequence: 1, Endorsement Plugin: escc, Validation Plugin: vscc
```

---

### Step 7: Restart API Bridge

On VM 2, restart the API bridge to use the updated configuration:

```bash
cd ~/Desktop/FYP-2/jumpserver-api
./stop.sh
./start.sh
```

Check the logs:
```bash
tail -f ~/Desktop/FYP-2/jumpserver-api/api.log
```

**Expected output:**
```
✓ Connected to Hot Chain: peer0.forensiclab.hot.coc.com:8051
✓ Connected to Cold Chain: peer0.forensiclab.cold.coc.com:10051
✓ Hot chain: hotchannel
✓ Cold chain: coldchannel
Server running on https://0.0.0.0:3001
```

---

## Testing from JumpServer (VM 1)

After completing the above steps on VM 2, test from VM 1:

```bash
cd /home/jsroot/js/apps
./test_integration.sh
```

**All tests should now pass, including Test 5 (Django integration):**

```
Test 1: Verifying Certificates - ✓ PASS
Test 2: Checking Certificate Permissions - ✓ PASS
Test 3: Testing mTLS Connection - ✓ PASS
  ✓ Hot chain connected
  ✓ Cold chain connected
  ⚠ IPFS not connected (will use mock CIDs)
Test 4: Testing Security - ✓ PASS
Test 5: Testing Django Integration - ✓ PASS
  ✓ Health check successful
  ✓ Evidence upload successful
  ✓ Evidence query successful

✓ ALL TESTS PASSED!
```

---

## Troubleshooting

### Error: "Error: query failed with status: 500 - channel 'hotchannel' not found"

**Cause:** Channels not created yet
**Fix:** Run Step 2 above

### Error: "No metadata was found for chaincode coc in channel hotchannel"

**Cause:** Chaincode not deployed
**Fix:** Run Step 5 above

### Error: "Failed to authorize invocation due to failed ACL check"

**Cause:** Admin certificate doesn't have OU=ADMIN attribute
**Fix:** This is expected with the current certificate setup. Use the CLI containers instead:

```bash
# Instead of:
peer lifecycle chaincode queryinstalled

# Use:
docker exec cli.hot peer lifecycle chaincode queryinstalled
```

### Error: "Connection refused to peer"

**Cause:** Peer endpoints incorrect in `.env`
**Fix:** Already fixed above. Verify with:

```bash
grep "PEER_ENDPOINT" ~/Desktop/FYP-2/jumpserver-api/.env
```

Should show:
```
HOT_PEER_ENDPOINT=localhost:8051
COLD_PEER_ENDPOINT=localhost:10051
```

---

## Quick Setup (All-in-One Command)

If you need to set up everything from scratch:

```bash
cd ~/Desktop/FYP-2/blockchain

# Option 1: Full automated setup
./scripts/setup-network.sh up          # Generate crypto + start network
sleep 15                                 # Wait for network to stabilize
./scripts/setup-network.sh channel      # Create channels
./scripts/setup-network.sh join         # Join peers
./scripts/setup-network.sh anchor       # Update anchors
./scripts/deploy-chaincode.sh deploy    # Deploy chaincode

# Option 2: Step by step (recommended for first time)
# Follow Steps 1-5 above
```

---

## Network Architecture

```
VM 2 (Blockchain)                    VM 1 (JumpServer)
├─ Hot Chain                         └─ Django App
│  ├─ Channel: hotchannel               ├─ fabric_client.py
│  ├─ Chaincode: coc                    └─ Uses mTLS
│  ├─ Peer: peer0.forensiclab:8051
│  └─ Peer: peer0.court:7051
├─ Cold Chain
│  ├─ Channel: coldchannel
│  ├─ Chaincode: coc
│  ├─ Peer: peer0.forensiclab:10051
│  └─ Peer: peer0.court:9051
└─ API Bridge (port 3001)
   └─ Connects both chains
   └─ Accepts mTLS from JumpServer
```

---

## Summary

**What you need to do on VM 2:**

1. ✅ Verify blockchain network is running
2. ⚠️ Create channels (hotchannel, coldchannel) - **This is the critical missing step**
3. ⚠️ Join peers to channels
4. ⚠️ Deploy chaincode to channels
5. ✅ Restart API bridge (optional, but recommended)

**After that, everything should work from VM 1!**

---

## Files Modified

- `/home/user/test/FYP-2/jumpserver-api/.env` - Fixed channel names and peer endpoints

**No changes needed to:**
- JumpServer configuration (already correct)
- Certificate paths (already correct)
- mTLS setup (already working)

---

**Ready? Run the commands on VM 2 and then test from VM 1!**
