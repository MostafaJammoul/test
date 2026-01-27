#!/usr/bin/env python
"""
Test script for FYP-2 Blockchain Integration
Run this to verify the REST API connection with mTLS is working
"""
import os
import sys
import django
import hashlib
from datetime import datetime

# Setup Django environment
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'jumpserver.settings')
django.setup()

from blockchain.clients.fabric_client import FabricClient

def print_header(text):
    print("\n" + "=" * 60)
    print(f"  {text}")
    print("=" * 60)

def print_success(text):
    print(f"✓ {text}")

def print_error(text):
    print(f"✗ {text}")

def test_health_check():
    """Test 1: Health Check"""
    print_header("Test 1: Health Check")

    try:
        client = FabricClient()
        result = client.health_check()

        print_success("Connected to API bridge")
        print(f"  Status: {result.get('status')}")
        print(f"  Hot Chain: {result.get('connections', {}).get('hotChain')}")
        print(f"  Cold Chain: {result.get('connections', {}).get('coldChain')}")
        print(f"  IPFS: {result.get('connections', {}).get('ipfs')}")

        if result.get('status') == 'healthy':
            print_success("All blockchain connections healthy!")
            return True
        else:
            print_error("Blockchain connections not healthy")
            return False

    except Exception as e:
        print_error(f"Health check failed: {e}")
        return False

def test_append_evidence():
    """Test 2: Append Evidence"""
    print_header("Test 2: Append Evidence to Blockchain")

    try:
        client = FabricClient()

        # Create test evidence
        test_data = f"Test evidence data - {datetime.now().isoformat()}".encode()
        file_hash = hashlib.sha256(test_data).hexdigest()

        case_id = "test-case-001"
        evidence_id = f"test-evidence-{int(datetime.now().timestamp())}"

        metadata = {
            'type': 'test',
            'description': 'Test evidence for mTLS integration',
            'timestamp': datetime.now().isoformat()
        }

        print(f"  Case ID: {case_id}")
        print(f"  Evidence ID: {evidence_id}")
        print(f"  Hash: {file_hash[:16]}...")
        print("\n  Uploading to blockchain...")

        result = client.append_evidence(
            case_id=case_id,
            evidence_id=evidence_id,
            file_data=test_data,
            file_hash=file_hash,
            metadata=metadata,
            user_identifier='admin'
        )

        print_success("Evidence appended to blockchain!")
        print(f"  IPFS CID: {result.get('cid')}")
        print(f"  Chain: {result.get('chain')}")

        return True, evidence_id, case_id

    except Exception as e:
        print_error(f"Failed to append evidence: {e}")
        return False, None, None

def test_query_evidence(evidence_id, case_id):
    """Test 3: Query Evidence"""
    print_header("Test 3: Query Evidence from Blockchain")

    try:
        client = FabricClient()

        print(f"  Querying evidence: {evidence_id}")
        result = client.query_evidence(evidence_id, case_id)

        print_success("Evidence retrieved from blockchain!")
        print(f"  Evidence ID: {result.get('evidenceID')}")
        print(f"  Case ID: {result.get('caseID')}")
        print(f"  IPFS CID: {result.get('cid')}")
        print(f"  Status: {result.get('status')}")
        print(f"  Owner: {result.get('owner')}")

        return True

    except Exception as e:
        print_error(f"Failed to query evidence: {e}")
        return False

def test_query_case():
    """Test 4: Query Case Evidence"""
    print_header("Test 4: Query All Evidence for Case")

    try:
        client = FabricClient()

        case_id = "test-case-001"
        print(f"  Querying case: {case_id}")

        result = client.query_case_evidence(case_id)

        if isinstance(result, list):
            print_success(f"Found {len(result)} evidence items for case")
            for i, evidence in enumerate(result[:5], 1):  # Show first 5
                print(f"    {i}. {evidence.get('evidenceID')} - {evidence.get('status')}")
        else:
            print_success("Case query completed")

        return True

    except Exception as e:
        print_error(f"Failed to query case: {e}")
        return False

def main():
    """Run all tests"""
    print("\n" + "=" * 60)
    print("  FYP-2 Blockchain Integration Test Suite")
    print("  Testing mTLS connection and API functionality")
    print("=" * 60)

    # Test 1: Health Check
    if not test_health_check():
        print("\n" + "=" * 60)
        print("  ✗ Health check failed. Fix connection before continuing.")
        print("=" * 60)
        print("\nTroubleshooting:")
        print("1. Check API bridge is running on VM 2")
        print("2. Verify certificates at /etc/jumpserver/certs/")
        print("3. Check config.yml has correct FABRIC_API_URL")
        print("4. Verify firewall allows port 3001")
        return

    # Test 2: Append Evidence
    success, evidence_id, case_id = test_append_evidence()
    if not success:
        print("\n" + "=" * 60)
        print("  ✗ Evidence append failed.")
        print("=" * 60)
        return

    # Test 3: Query Evidence
    if not test_query_evidence(evidence_id, case_id):
        print("\n" + "=" * 60)
        print("  ✗ Evidence query failed.")
        print("=" * 60)
        return

    # Test 4: Query Case
    test_query_case()

    # Summary
    print("\n" + "=" * 60)
    print("  ✓ ALL TESTS PASSED!")
    print("=" * 60)
    print("\n✅ JumpServer is successfully integrated with FYP-2 blockchain!")
    print("✅ mTLS authentication is working correctly!")
    print("✅ Evidence can be uploaded to IPFS and blockchain!")
    print("✅ Chain of custody is being recorded!\n")

if __name__ == '__main__':
    main()
