#!/usr/bin/env python3
"""
Chain of Custody - Blockchain API Server
Provides REST API endpoints for all chaincode functions
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import json
import os

app = Flask(__name__)
CORS(app)

# Configuration for both chains
CHAINS = {
    'hot': {
        'cli': 'cli.hot',
        'channel': 'hotchannel',
        'orderer': 'orderer.hot.coc.com:7050',
        'orderer_ca': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem',
        'peer_forensiclab': 'peer0.forensiclab.hot.coc.com:8051',
        'peer_forensiclab_tls': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt',
        'peer_court': 'peer0.court.hot.coc.com:7051',
        'peer_court_tls': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.hot.coc.com/peers/peer0.court.hot.coc.com/tls/ca.crt',
    },
    'cold': {
        'cli': 'cli.cold',
        'channel': 'coldchannel',
        'orderer': 'orderer.cold.coc.com:8050',
        'orderer_ca': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem',
        'peer_forensiclab': 'peer0.forensiclab.cold.coc.com:10051',
        'peer_forensiclab_tls': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.cold.coc.com/peers/peer0.forensiclab.cold.coc.com/tls/ca.crt',
        'peer_court': 'peer0.court.cold.coc.com:9051',
        'peer_court_tls': '/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/court.cold.coc.com/peers/peer0.court.cold.coc.com/tls/ca.crt',
    }
}

def run_invoke(chain, function, args):
    """Execute a chaincode invoke command"""
    cfg = CHAINS[chain]
    args_json = json.dumps({"function": function, "Args": args})

    cmd = f'''docker exec {cfg['cli']} peer chaincode invoke \
        -o {cfg['orderer']} --tls \
        --cafile {cfg['orderer_ca']} \
        -C {cfg['channel']} -n coc \
        --peerAddresses {cfg['peer_forensiclab']} \
        --tlsRootCertFiles {cfg['peer_forensiclab_tls']} \
        --peerAddresses {cfg['peer_court']} \
        --tlsRootCertFiles {cfg['peer_court_tls']} \
        -c '{args_json}' 2>&1'''

    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    output = result.stdout + result.stderr

    if 'Chaincode invoke successful' in output or 'status:200' in output:
        return {'success': True, 'message': 'Transaction successful', 'output': output}
    else:
        return {'success': False, 'message': 'Transaction failed', 'output': output}

def run_query(chain, function, args):
    """Execute a chaincode query command"""
    cfg = CHAINS[chain]
    args_json = json.dumps({"function": function, "Args": args})

    cmd = f'''docker exec {cfg['cli']} peer chaincode query \
        -C {cfg['channel']} -n coc \
        -c '{args_json}' 2>&1'''

    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    output = result.stdout + result.stderr

    try:
        # Try to parse as JSON
        data = json.loads(output.strip())
        return {'success': True, 'data': data}
    except:
        if 'Error' in output:
            return {'success': False, 'message': output}
        return {'success': True, 'data': output}

def get_chain_info(chain):
    """Get blockchain info"""
    cfg = CHAINS[chain]
    cmd = f"docker exec {cfg['cli']} peer channel getinfo -c {cfg['channel']} 2>&1"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    output = result.stdout + result.stderr

    try:
        # Extract JSON from output
        import re
        match = re.search(r'\{.*\}', output)
        if match:
            return json.loads(match.group())
    except:
        pass
    return {'height': 0, 'currentBlockHash': 'unknown'}

# ==================== API ENDPOINTS ====================

@app.route('/api/status', methods=['GET'])
def get_status():
    """Get status of both chains"""
    hot_info = get_chain_info('hot')
    cold_info = get_chain_info('cold')
    return jsonify({
        'hot': hot_info,
        'cold': cold_info
    })

@app.route('/api/<chain>/info', methods=['GET'])
def get_chain_status(chain):
    """Get chain info"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400
    return jsonify(get_chain_info(chain))

# Function 1: Create Evidence
@app.route('/api/<chain>/evidence/create', methods=['POST'])
def create_evidence(chain):
    """Create new evidence"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    data = request.json
    required = ['caseID', 'evidenceID', 'cid', 'hash']
    if not all(k in data for k in required):
        return jsonify({'error': 'Missing required fields'}), 400

    args = [
        data['caseID'],
        data['evidenceID'],
        data['cid'],
        data['hash'],
        data.get('metadata', '{}')
    ]

    result = run_invoke(chain, 'CreateEvidence', args)
    return jsonify(result)

# Function 2: Transfer Custody
@app.route('/api/<chain>/evidence/transfer', methods=['POST'])
def transfer_custody(chain):
    """Transfer evidence custody"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    data = request.json
    required = ['caseID', 'evidenceID', 'newCustodian']
    if not all(k in data for k in required):
        return jsonify({'error': 'Missing required fields'}), 400

    args = [
        data['caseID'],
        data['evidenceID'],
        data['newCustodian'],
        data.get('reason', '')
    ]

    result = run_invoke(chain, 'TransferCustody', args)
    return jsonify(result)

# Function 3: Archive to Cold
@app.route('/api/<chain>/evidence/archive', methods=['POST'])
def archive_evidence(chain):
    """Archive evidence to cold storage"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    data = request.json
    required = ['caseID', 'evidenceID']
    if not all(k in data for k in required):
        return jsonify({'error': 'Missing required fields'}), 400

    args = [
        data['caseID'],
        data['evidenceID'],
        data.get('reason', '')
    ]

    result = run_invoke(chain, 'ArchiveToCold', args)
    return jsonify(result)

# Function 4: Reactivate from Cold
@app.route('/api/<chain>/evidence/reactivate', methods=['POST'])
def reactivate_evidence(chain):
    """Reactivate archived evidence"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    data = request.json
    required = ['caseID', 'evidenceID']
    if not all(k in data for k in required):
        return jsonify({'error': 'Missing required fields'}), 400

    args = [
        data['caseID'],
        data['evidenceID'],
        data.get('reason', '')
    ]

    result = run_invoke(chain, 'ReactivateFromCold', args)
    return jsonify(result)

# Function 5: Invalidate Evidence
@app.route('/api/<chain>/evidence/invalidate', methods=['POST'])
def invalidate_evidence(chain):
    """Invalidate evidence"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    data = request.json
    required = ['caseID', 'evidenceID', 'reason']
    if not all(k in data for k in required):
        return jsonify({'error': 'Missing required fields'}), 400

    args = [
        data['caseID'],
        data['evidenceID'],
        data['reason'],
        data.get('wrongTxID', '')
    ]

    result = run_invoke(chain, 'InvalidateEvidence', args)
    return jsonify(result)

# Function 6: Get Evidence Summary
@app.route('/api/<chain>/evidence/summary', methods=['GET'])
def get_evidence_summary(chain):
    """Get evidence summary"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    case_id = request.args.get('caseID')
    evidence_id = request.args.get('evidenceID')

    if not case_id or not evidence_id:
        return jsonify({'error': 'Missing caseID or evidenceID'}), 400

    result = run_query(chain, 'GetEvidenceSummary', [case_id, evidence_id])
    return jsonify(result)

# Function 7: Query Evidence by Case
@app.route('/api/<chain>/evidence/bycase', methods=['GET'])
def query_by_case(chain):
    """Query all evidence for a case"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    case_id = request.args.get('caseID')
    if not case_id:
        return jsonify({'error': 'Missing caseID'}), 400

    result = run_query(chain, 'QueryEvidencesByCase', [case_id])
    return jsonify(result)

# Function 8: Get Custody Chain
@app.route('/api/<chain>/evidence/custody', methods=['GET'])
def get_custody_chain(chain):
    """Get custody chain for evidence"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    case_id = request.args.get('caseID')
    evidence_id = request.args.get('evidenceID')

    if not case_id or not evidence_id:
        return jsonify({'error': 'Missing caseID or evidenceID'}), 400

    result = run_query(chain, 'GetCustodyChain', [case_id, evidence_id])
    return jsonify(result)

# Get full evidence details
@app.route('/api/<chain>/evidence/details', methods=['GET'])
def get_evidence_details(chain):
    """Get full evidence details"""
    if chain not in CHAINS:
        return jsonify({'error': 'Invalid chain'}), 400

    case_id = request.args.get('caseID')
    evidence_id = request.args.get('evidenceID')

    if not case_id or not evidence_id:
        return jsonify({'error': 'Missing caseID or evidenceID'}), 400

    result = run_query(chain, 'GetEvidence', [case_id, evidence_id])
    return jsonify(result)

if __name__ == '__main__':
    print("Starting Chain of Custody API Server...")
    print("API available at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
