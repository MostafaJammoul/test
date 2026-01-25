#!/usr/bin/env python3
"""
Detailed Blockchain Explorer API Server
Provides REST API endpoints for querying block-level data from Fabric networks
Port: 3001
"""

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import subprocess
import json
import os
import re
import base64
import tempfile
import hashlib

app = Flask(__name__, static_folder='.')
CORS(app)

# Configuration for both chains
CHAINS = {
    'hot': {
        'peer': 'peer0.forensiclab.hot.coc.com',
        'cli': 'cli.hot',
        'channel': 'hotchannel',
        'orderer': 'orderer.hot.coc.com:7050',
        'orderer_tls': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem',
        'msp_path': '/etc/hyperledger/fabric/msp',
        'tls_cert': '/etc/hyperledger/fabric/tls/server.crt',
        'tls_key': '/etc/hyperledger/fabric/tls/server.key',
        'tls_ca': '/etc/hyperledger/fabric/tls/ca.crt',
        'chaincode': 'coc',
    },
    'cold': {
        'peer': 'peer0.forensiclab.cold.coc.com',
        'cli': 'cli.cold',
        'channel': 'coldchannel',
        'orderer': 'orderer.cold.coc.com:8050',
        'orderer_tls': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem',
        'msp_path': '/etc/hyperledger/fabric/msp',
        'tls_cert': '/etc/hyperledger/fabric/tls/server.crt',
        'tls_key': '/etc/hyperledger/fabric/tls/server.key',
        'tls_ca': '/etc/hyperledger/fabric/tls/ca.crt',
        'chaincode': 'coc',
    }
}

def run_peer_command(chain, command, timeout=30):
    """Execute a peer command inside the CLI container"""
    cfg = CHAINS.get(chain)
    if not cfg:
        return None, f"Invalid chain: {chain}"

    # Use CLI container for commands
    container = cfg.get('cli', cfg['peer'])
    full_cmd = f"docker exec {container} {command}"

    try:
        result = subprocess.run(
            full_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.stdout + result.stderr, None
    except subprocess.TimeoutExpired:
        return None, "Command timed out"
    except Exception as e:
        return None, str(e)

def decode_hash(hash_value):
    """Decode base64 hash to hex format for display"""
    if not hash_value or hash_value in ['', 'null', None]:
        return None
    try:
        # Fabric returns base64-encoded hashes
        decoded = base64.b64decode(hash_value)
        return decoded.hex()
    except:
        # If it's already hex or another format, return as-is
        return hash_value

def get_chain_info(chain):
    """Get blockchain height and hash"""
    cfg = CHAINS.get(chain)
    if not cfg:
        return {'error': 'Invalid chain'}

    output, err = run_peer_command(
        chain,
        f"peer channel getinfo -c {cfg['channel']}"
    )

    if err:
        return {'height': 0, 'currentBlockHash': 'N/A', 'previousBlockHash': 'N/A', 'error': err}

    # Parse output: Blockchain info: {"height":5,"currentBlockHash":"...","previousBlockHash":"..."}
    try:
        match = re.search(r'\{.*\}', output)
        if match:
            info = json.loads(match.group())
            height = info.get('height', 0)

            # Decode hashes from base64 to hex for display
            current_hash = decode_hash(info.get('currentBlockHash'))
            prev_hash = decode_hash(info.get('previousBlockHash'))

            # Handle genesis block case - when height is 1, previous hash will be empty/null
            if height == 1 and not prev_hash:
                prev_hash = 'Genesis Block (no previous)'
            elif not prev_hash:
                prev_hash = 'N/A'

            if not current_hash:
                current_hash = 'N/A'

            return {
                'height': height,
                'currentBlockHash': current_hash,
                'previousBlockHash': prev_hash
            }
    except Exception as e:
        return {'height': 0, 'currentBlockHash': 'N/A', 'previousBlockHash': 'N/A', 'parseError': str(e)}

    return {'height': 0, 'currentBlockHash': 'N/A', 'previousBlockHash': 'N/A'}

def fetch_block(chain, block_num):
    """Fetch and decode a specific block"""
    cfg = CHAINS.get(chain)
    if not cfg:
        return None, "Invalid chain"

    # Create temp file for block data
    block_file = f"/tmp/block_{chain}_{block_num}.block"
    json_file = f"/tmp/block_{chain}_{block_num}.json"

    # Fetch block using peer channel fetch
    fetch_cmd = f"peer channel fetch {block_num} {block_file} -c {cfg['channel']} -o {cfg['orderer']} --tls --cafile {cfg['orderer_tls']}"
    output, err = run_peer_command(chain, fetch_cmd)

    if err:
        return None, f"Failed to fetch block: {err}"

    # Try to decode block using configtxlator
    decode_cmd = f"configtxlator proto_decode --input {block_file} --type common.Block"
    output, err = run_peer_command(chain, decode_cmd)

    if err or not output:
        # Try alternative approach - read block directly and parse
        read_cmd = f"cat {block_file} | base64"
        output, _ = run_peer_command(chain, read_cmd)
        if output:
            return parse_block_basic(chain, block_num, output.strip())
        return None, "Failed to decode block"

    try:
        block_data = json.loads(output)
        return parse_block_data(chain, block_num, block_data), None
    except json.JSONDecodeError:
        return parse_block_from_output(chain, block_num, output), None

def parse_block_basic(chain, block_num, base64_data):
    """Parse basic block info when full decode isn't available"""
    cfg = CHAINS.get(chain)

    # Create a hash from the base64 data as a placeholder
    data_hash = hashlib.sha256(base64_data.encode()).hexdigest()

    # Handle genesis block
    if block_num == 0:
        prev_hash = 'Genesis Block (no previous)'
    else:
        prev_hash = f"Block #{block_num - 1}"

    return {
        'blockNumber': block_num,
        'chain': chain,
        'channel': cfg['channel'] if cfg else 'unknown',
        'dataHash': data_hash,
        'blockHash': str(block_num),
        'previousHash': prev_hash,
        'timestamp': 'N/A',
        'transactions': [],
        'txCount': 0,
        'rawDataAvailable': True,
        'rawData': base64_data[:500] + '...' if len(base64_data) > 500 else base64_data
    }

def parse_block_data(chain, block_num, block_json):
    """Parse decoded block JSON into structured format"""
    cfg = CHAINS.get(chain)

    header = block_json.get('header', {})
    data = block_json.get('data', {})
    metadata = block_json.get('metadata', {})

    # Extract transactions
    transactions = []
    envelopes = data.get('data', [])

    for idx, env in enumerate(envelopes):
        tx = parse_transaction(env, idx)
        if tx:
            transactions.append(tx)

    # Extract timestamp from first transaction if available
    timestamp = 'N/A'
    if transactions:
        timestamp = transactions[0].get('timestamp', 'N/A')

    # Decode hashes from base64 to hex
    data_hash = decode_hash(header.get('data_hash')) or 'N/A'
    prev_hash_raw = header.get('previous_hash')

    # Handle genesis block (block 0) - no previous hash
    if block_num == 0:
        prev_hash = 'Genesis Block (no previous)'
    elif prev_hash_raw:
        prev_hash = decode_hash(prev_hash_raw) or 'N/A'
    else:
        prev_hash = 'N/A'

    return {
        'blockNumber': block_num,
        'chain': chain,
        'channel': cfg['channel'],
        'dataHash': data_hash,
        'blockHash': str(block_num),
        'previousHash': prev_hash,
        'timestamp': timestamp,
        'transactions': transactions,
        'txCount': len(transactions),
    }

def parse_transaction(envelope, idx):
    """Parse a transaction envelope"""
    try:
        payload = envelope.get('payload', {})
        header = payload.get('header', {})
        data = payload.get('data', {})

        channel_header = header.get('channel_header', {})
        signature_header = header.get('signature_header', {})

        # Extract chaincode actions
        actions = []
        tx_actions = data.get('actions', [])

        for action in tx_actions:
            action_payload = action.get('payload', {})
            chaincode_action = action_payload.get('action', {})
            proposal = action_payload.get('chaincode_proposal_payload', {})

            # Get chaincode spec - try multiple paths
            chaincode_spec = proposal.get('input', {}).get('chaincode_spec', {})
            cc_input = chaincode_spec.get('input', {})
            args = cc_input.get('args', [])

            # Extract chaincode name from various possible locations
            chaincode_name = chaincode_spec.get('chaincode_id', {}).get('name', '')
            if not chaincode_name:
                # Try from endorsement
                chaincode_name = chaincode_action.get('proposal_response_payload', {}).get('extension', {}).get('chaincode_id', {}).get('name', '')
            if not chaincode_name:
                chaincode_name = 'coc'  # Default for this system

            # Decode args from base64 if needed
            decoded_args = []
            for arg in args:
                if isinstance(arg, str):
                    try:
                        decoded = base64.b64decode(arg).decode('utf-8', errors='replace')
                        decoded_args.append(decoded)
                    except:
                        decoded_args.append(arg)
                else:
                    decoded_args.append(str(arg))

            # Get response
            response = chaincode_action.get('proposal_response_payload', {}).get('extension', {}).get('response', {})

            actions.append({
                'chaincode': chaincode_name,
                'function': decoded_args[0] if decoded_args else 'unknown',
                'args': decoded_args[1:] if len(decoded_args) > 1 else [],
                'responseStatus': response.get('status', 0),
                'responsePayload': response.get('payload', ''),
            })

        # Extract creator info
        creator = signature_header.get('creator', {})

        return {
            'txIndex': idx,
            'txId': channel_header.get('tx_id', f'tx_{idx}'),
            'timestamp': channel_header.get('timestamp', 'N/A'),
            'channelId': channel_header.get('channel_id', 'N/A'),
            'type': get_tx_type_name(channel_header.get('type', 0)),
            'typeCode': channel_header.get('type', 0),
            'creatorMSP': creator.get('mspid', 'N/A'),
            'actions': actions,
            'validationCode': 'VALID',  # Would need to parse metadata for actual validation
        }
    except Exception as e:
        return {
            'txIndex': idx,
            'txId': f'tx_{idx}',
            'error': str(e),
            'type': 'UNKNOWN',
        }

def parse_block_from_output(chain, block_num, output):
    """Parse block from raw configtxlator output when JSON parsing fails"""
    cfg = CHAINS.get(chain)

    # Try to extract key information from output
    lines = output.split('\n')

    data_hash = 'N/A'
    prev_hash = 'N/A'

    for line in lines:
        if 'data_hash' in line.lower():
            # Try to extract base64 or hex hash
            match = re.search(r'"([a-zA-Z0-9+/=]+)"', line)
            if match:
                hash_val = match.group(1)
                decoded = decode_hash(hash_val)
                data_hash = decoded if decoded else hash_val
        if 'previous_hash' in line.lower():
            match = re.search(r'"([a-zA-Z0-9+/=]+)"', line)
            if match:
                hash_val = match.group(1)
                decoded = decode_hash(hash_val)
                prev_hash = decoded if decoded else hash_val

    # Handle genesis block
    if block_num == 0:
        prev_hash = 'Genesis Block (no previous)'

    return {
        'blockNumber': block_num,
        'chain': chain,
        'channel': cfg['channel'],
        'dataHash': data_hash,
        'previousHash': prev_hash,
        'timestamp': 'N/A',
        'transactions': [],
        'txCount': 0,
        'rawOutput': output[:2000] if len(output) > 2000 else output,
    }

def get_tx_type_name(type_code):
    """Convert transaction type code to human-readable name"""
    types = {
        0: 'MESSAGE',
        1: 'CONFIG',
        2: 'CONFIG_UPDATE',
        3: 'ENDORSER_TRANSACTION',
        4: 'ORDERER_TRANSACTION',
        5: 'DELIVER_SEEK_INFO',
        6: 'CHAINCODE_PACKAGE',
    }
    return types.get(type_code, f'UNKNOWN({type_code})')

def query_chaincode(chain, function, args):
    """Query chaincode function"""
    cfg = CHAINS.get(chain)
    if not cfg:
        return None, "Invalid chain"

    args_json = json.dumps({"function": function, "Args": args})
    cmd = f"peer chaincode query -C {cfg['channel']} -n {cfg['chaincode']} -c '{args_json}'"

    output, err = run_peer_command(chain, cmd)

    if err:
        return None, err

    try:
        return json.loads(output.strip()), None
    except:
        return output.strip(), None

# ==================== API ENDPOINTS ====================

@app.route('/')
def serve_index():
    """Serve the main HTML page"""
    return send_from_directory('.', 'index.html')

@app.route('/api/status', methods=['GET'])
def api_status():
    """Get status of both chains"""
    hot_info = get_chain_info('hot')
    cold_info = get_chain_info('cold')

    return jsonify({
        'hot': hot_info,
        'cold': cold_info,
        'timestamp': subprocess.run(['date', '-Iseconds'], capture_output=True, text=True).stdout.strip()
    })

@app.route('/api/<chain>/info', methods=['GET'])
def api_chain_info(chain):
    """Get chain info (height, hashes)"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    info = get_chain_info(chain)
    return jsonify(info)

@app.route('/api/<chain>/blocks', methods=['GET'])
def api_list_blocks(chain):
    """List blocks with pagination"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    # Get parameters
    start = request.args.get('start', 0, type=int)
    limit = request.args.get('limit', 10, type=int)

    # Get chain height
    info = get_chain_info(chain)
    height = info.get('height', 0)

    if height == 0:
        return jsonify({
            'chain': chain,
            'height': 0,
            'blocks': [],
            'error': info.get('error')
        })

    # Fetch blocks (from newest to oldest)
    blocks = []
    end_block = max(0, height - 1 - start)
    start_block = max(0, end_block - limit + 1)

    for block_num in range(end_block, start_block - 1, -1):
        block_data, err = fetch_block(chain, block_num)
        if block_data:
            blocks.append(block_data)

    return jsonify({
        'chain': chain,
        'height': height,
        'start': start,
        'limit': limit,
        'blocks': blocks
    })

@app.route('/api/<chain>/block/<int:block_num>', methods=['GET'])
def api_get_block(chain, block_num):
    """Get a specific block by number"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    # Check if block exists
    info = get_chain_info(chain)
    height = info.get('height', 0)

    if block_num < 0 or block_num >= height:
        return jsonify({'error': f'Block {block_num} not found. Chain height is {height}'}), 404

    block_data, err = fetch_block(chain, block_num)

    if err:
        return jsonify({'error': err}), 500

    return jsonify(block_data)

@app.route('/api/<chain>/tx/<tx_id>', methods=['GET'])
def api_get_transaction(chain, tx_id):
    """Get transaction details by ID"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    cfg = CHAINS[chain]

    # Use peer channel fetch to get block containing transaction
    cmd = f"peer channel fetch -c {cfg['channel']} --txID {tx_id} /tmp/tx_block.block -o {cfg['orderer']} --tls --cafile {cfg['orderer_tls']}"
    output, err = run_peer_command(chain, cmd)

    if err:
        return jsonify({'error': f'Transaction not found: {err}'}), 404

    # Decode the block and find the transaction
    decode_cmd = "configtxlator proto_decode --input /tmp/tx_block.block --type common.Block"
    output, err = run_peer_command(chain, decode_cmd)

    if err:
        return jsonify({'error': 'Failed to decode transaction block'}), 500

    try:
        block_data = json.loads(output)
        # Find the transaction with matching ID
        for env in block_data.get('data', {}).get('data', []):
            tx = parse_transaction(env, 0)
            if tx and tx.get('txId') == tx_id:
                return jsonify(tx)
    except:
        pass

    return jsonify({'error': 'Transaction not found in block'}), 404

@app.route('/api/<chain>/evidence', methods=['GET'])
def api_query_evidence(chain):
    """Query evidence by case and evidence ID"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    case_id = request.args.get('caseID')
    evidence_id = request.args.get('evidenceID')

    if not case_id or not evidence_id:
        return jsonify({'error': 'Missing caseID or evidenceID'}), 400

    data, err = query_chaincode(chain, 'GetEvidenceSummary', [case_id, evidence_id])

    if err:
        return jsonify({'error': err}), 500

    return jsonify({'success': True, 'data': data})

@app.route('/api/<chain>/evidence/case/<case_id>', methods=['GET'])
def api_query_by_case(chain, case_id):
    """Query all evidence for a case"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    data, err = query_chaincode(chain, 'QueryEvidencesByCase', [case_id])

    if err:
        return jsonify({'error': err}), 500

    return jsonify({'success': True, 'data': data})

@app.route('/api/<chain>/custody', methods=['GET'])
def api_get_custody_chain(chain):
    """Get custody chain for evidence"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    case_id = request.args.get('caseID')
    evidence_id = request.args.get('evidenceID')

    if not case_id or not evidence_id:
        return jsonify({'error': 'Missing caseID or evidenceID'}), 400

    data, err = query_chaincode(chain, 'GetCustodyChain', [case_id, evidence_id])

    if err:
        return jsonify({'error': err}), 500

    return jsonify({'success': True, 'data': data})

@app.route('/api/containers', methods=['GET'])
def api_check_containers():
    """Check status of blockchain containers"""
    try:
        result = subprocess.run(
            "docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}' | grep -E '(hot|cold)'",
            shell=True,
            capture_output=True,
            text=True
        )

        containers = []
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split('|')
                if len(parts) >= 2:
                    containers.append({
                        'name': parts[0],
                        'status': parts[1],
                        'ports': parts[2] if len(parts) > 2 else ''
                    })

        return jsonify({
            'running': len(containers) > 0,
            'count': len(containers),
            'containers': containers
        })
    except Exception as e:
        return jsonify({'running': False, 'error': str(e)})

if __name__ == '__main__':
    print("=" * 60)
    print("Detailed Blockchain Explorer API Server")
    print("=" * 60)
    print("API available at: http://localhost:3001")
    print("UI available at:  http://localhost:3001/")
    print("")
    print("Endpoints:")
    print("  GET /api/status              - Get both chains status")
    print("  GET /api/<chain>/info        - Get chain info")
    print("  GET /api/<chain>/blocks      - List blocks (with pagination)")
    print("  GET /api/<chain>/block/<num> - Get specific block")
    print("  GET /api/<chain>/tx/<txid>   - Get transaction details")
    print("  GET /api/<chain>/evidence    - Query evidence")
    print("  GET /api/containers          - Check Docker containers")
    print("=" * 60)
    app.run(host='0.0.0.0', port=3001, debug=True)
