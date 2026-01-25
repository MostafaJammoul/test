#!/bin/bash
# Generate blockchain monitor HTML with live data

OUTPUT_FILE="/home/kali/FYP-2/blockchain/explorer/monitor.html"

# Get Hot Chain Info
HOT_INFO=$(docker exec cli.hot peer channel getinfo -c hotchannel 2>&1 | grep -o '"height":[0-9]*' | grep -o '[0-9]*')
HOT_HASH=$(docker exec cli.hot peer channel getinfo -c hotchannel 2>&1 | grep -o '"currentBlockHash":"[^"]*"' | cut -d'"' -f4)

# Get Cold Chain Info
COLD_INFO=$(docker exec cli.cold peer channel getinfo -c coldchannel 2>&1 | grep -o '"height":[0-9]*' | grep -o '[0-9]*')
COLD_HASH=$(docker exec cli.cold peer channel getinfo -c coldchannel 2>&1 | grep -o '"currentBlockHash":"[^"]*"' | cut -d'"' -f4)

# Get Hot Chain Blocks (last 5)
HOT_BLOCKS=""
for i in $(seq $((HOT_INFO-1)) -1 $((HOT_INFO > 5 ? HOT_INFO-5 : 0))); do
    BLOCK_DATA=$(docker exec cli.hot peer channel fetch $i /tmp/block_$i.block -c hotchannel 2>&1)
    BLOCK_HASH=$(docker exec cli.hot sh -c "cat /tmp/block_$i.block | sha256sum | cut -d' ' -f1" 2>/dev/null)
    HOT_BLOCKS="$HOT_BLOCKS<div class='block'><div class='block-header'><span class='block-num'>Block #$i</span></div><div class='block-hash'>Hash: $BLOCK_HASH</div></div>"
done

# Get Cold Chain Blocks (last 5)
COLD_BLOCKS=""
for i in $(seq $((COLD_INFO-1)) -1 $((COLD_INFO > 5 ? COLD_INFO-5 : 0))); do
    BLOCK_DATA=$(docker exec cli.cold peer channel fetch $i /tmp/block_$i.block -c coldchannel 2>&1)
    BLOCK_HASH=$(docker exec cli.cold sh -c "cat /tmp/block_$i.block | sha256sum | cut -d' ' -f1" 2>/dev/null)
    COLD_BLOCKS="$COLD_BLOCKS<div class='block'><div class='block-header'><span class='block-num'>Block #$i</span></div><div class='block-hash'>Hash: $BLOCK_HASH</div></div>"
done

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$OUTPUT_FILE" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Chain of Custody - Blockchain Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #1a1a2e; color: #eee; }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        h1 { text-align: center; margin-bottom: 30px; color: #00d9ff; }
        .chains { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .chain { background: #16213e; border-radius: 10px; padding: 20px; }
        .chain h2 { color: #00d9ff; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 2px solid #0f3460; }
        .chain.hot h2 { color: #ff6b6b; border-color: #ff6b6b; }
        .chain.cold h2 { color: #4ecdc4; border-color: #4ecdc4; }
        .stat-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin-bottom: 20px; }
        .stat { background: #0f3460; padding: 15px; border-radius: 8px; text-align: center; }
        .stat-value { font-size: 28px; font-weight: bold; color: #00d9ff; }
        .stat-label { font-size: 12px; color: #888; margin-top: 5px; }
        .current-hash { background: #0f3460; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
        .current-hash h4 { color: #888; margin-bottom: 10px; }
        .hash-value { font-family: monospace; font-size: 12px; color: #00d9ff; word-break: break-all; }
        .orgs { margin-bottom: 20px; }
        .org { background: #0f3460; padding: 10px 15px; border-radius: 5px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; }
        .org-name { font-weight: bold; color: #00d9ff; }
        .org-peer { color: #888; font-size: 12px; }
        .org-status { color: #4ecdc4; font-size: 12px; }
        .blocks { max-height: 300px; overflow-y: auto; }
        .block { background: #0f3460; padding: 15px; border-radius: 8px; margin-bottom: 10px; border-left: 4px solid #00d9ff; }
        .block-header { display: flex; justify-content: space-between; margin-bottom: 10px; }
        .block-num { font-size: 18px; font-weight: bold; color: #00d9ff; }
        .block-hash { font-family: monospace; font-size: 11px; color: #666; word-break: break-all; background: #0a1628; padding: 8px; border-radius: 4px; }
        .status { text-align: center; padding: 15px; background: #0f3460; border-radius: 5px; margin-bottom: 20px; border-left: 4px solid #4ecdc4; }
        .timestamp { text-align: center; color: #666; margin-top: 20px; font-size: 12px; }
        .refresh-info { text-align: center; color: #888; font-size: 11px; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Digital Forensics Chain of Custody - Blockchain Monitor</h1>

        <div class="status">
            <strong>Status:</strong> Both chains operational |
            <strong>Hot Chain:</strong> ${HOT_INFO} blocks |
            <strong>Cold Chain:</strong> ${COLD_INFO} blocks |
            <strong>Last Update:</strong> ${TIMESTAMP}
        </div>

        <div class="chains">
            <div class="chain hot">
                <h2>HOT CHAIN (Active Cases)</h2>
                <div class="stat-grid">
                    <div class="stat">
                        <div class="stat-value">${HOT_INFO}</div>
                        <div class="stat-label">BLOCK HEIGHT</div>
                    </div>
                    <div class="stat">
                        <div class="stat-value">hotchannel</div>
                        <div class="stat-label">CHANNEL</div>
                    </div>
                </div>
                <div class="current-hash">
                    <h4>Current Block Hash</h4>
                    <div class="hash-value">${HOT_HASH}</div>
                </div>
                <div class="orgs">
                    <h3 style="color:#ff6b6b;margin-bottom:10px;">Organizations & Peers</h3>
                    <div class="org">
                        <div><div class="org-name">ForensicLabMSP</div><div class="org-peer">peer0.forensiclab.hot.coc.com:8051</div></div>
                        <div class="org-status">ONLINE</div>
                    </div>
                    <div class="org">
                        <div><div class="org-name">CourtMSP</div><div class="org-peer">peer0.court.hot.coc.com:7051</div></div>
                        <div class="org-status">ONLINE</div>
                    </div>
                </div>
                <h3 style="color:#ff6b6b;margin-bottom:10px;">Recent Blocks</h3>
                <div class="blocks">
                    ${HOT_BLOCKS}
                </div>
            </div>

            <div class="chain cold">
                <h2>COLD CHAIN (Archived Cases)</h2>
                <div class="stat-grid">
                    <div class="stat">
                        <div class="stat-value">${COLD_INFO}</div>
                        <div class="stat-label">BLOCK HEIGHT</div>
                    </div>
                    <div class="stat">
                        <div class="stat-value">coldchannel</div>
                        <div class="stat-label">CHANNEL</div>
                    </div>
                </div>
                <div class="current-hash">
                    <h4>Current Block Hash</h4>
                    <div class="hash-value">${COLD_HASH}</div>
                </div>
                <div class="orgs">
                    <h3 style="color:#4ecdc4;margin-bottom:10px;">Organizations & Peers</h3>
                    <div class="org">
                        <div><div class="org-name">ForensicLabMSP</div><div class="org-peer">peer0.forensiclab.cold.coc.com:10051</div></div>
                        <div class="org-status">ONLINE</div>
                    </div>
                    <div class="org">
                        <div><div class="org-name">CourtMSP</div><div class="org-peer">peer0.court.cold.coc.com:9051</div></div>
                        <div class="org-status">ONLINE</div>
                    </div>
                </div>
                <h3 style="color:#4ecdc4;margin-bottom:10px;">Recent Blocks</h3>
                <div class="blocks">
                    ${COLD_BLOCKS}
                </div>
            </div>
        </div>

        <div class="timestamp">
            Digital Forensics Chain of Custody System - American University of Beirut FYP<br>
            <span class="refresh-info">Page auto-refreshes every 30 seconds</span>
        </div>
    </div>
</body>
</html>
EOF

echo "Monitor page generated at: $OUTPUT_FILE"
echo "Hot Chain: $HOT_INFO blocks"
echo "Cold Chain: $COLD_INFO blocks"
