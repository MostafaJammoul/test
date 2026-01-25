package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-protos-go/peer"
)

// EvidenceChaincode implements the Fabric chaincode interface
type EvidenceChaincode struct {
}

// EvidenceStatus represents the state of evidence in the system
type EvidenceStatus string

const (
	StatusActive       EvidenceStatus = "ACTIVE"
	StatusArchived     EvidenceStatus = "ARCHIVED"
	StatusReactivated  EvidenceStatus = "REACTIVATED"
	StatusInvalidated  EvidenceStatus = "INVALIDATED"
)

// CustodyEvent represents a single event in the custody chain
type CustodyEvent struct {
	Timestamp   string `json:"timestamp"`
	EventType   string `json:"eventType"`
	Actor       string `json:"actor"`
	OrgMSP      string `json:"orgMSP"`
	Description string `json:"description"`
	TxID        string `json:"txId"`
}

// Evidence represents the complete state of a piece of evidence
type Evidence struct {
	CaseID         string          `json:"caseId"`
	EvidenceID     string          `json:"evidenceId"`
	CID            string          `json:"cid"`            // IPFS Content Identifier
	Hash           string          `json:"hash"`           // SHA-256 hash of evidence file
	Metadata       string          `json:"metadata"`       // JSON metadata about evidence
	Status         EvidenceStatus  `json:"status"`
	Events         []CustodyEvent  `json:"events"`
	CreatedAt      string          `json:"createdAt"`
	UpdatedAt      string          `json:"updatedAt"`
	CurrentOwner   string          `json:"currentOwner"`   // Current custodian
	OwnerOrgMSP    string          `json:"ownerOrgMSP"`    // Organization of current owner
}

// Init initializes the chaincode
func (c *EvidenceChaincode) Init(stub shim.ChaincodeStubInterface) peer.Response {
	return shim.Success(nil)
}

// Invoke is the entry point for all chaincode invocations
func (c *EvidenceChaincode) Invoke(stub shim.ChaincodeStubInterface) peer.Response {
	function, args := stub.GetFunctionAndParameters()

	switch function {
	case "CreateEvidence":
		return c.CreateEvidence(stub, args)
	case "TransferCustody":
		return c.TransferCustody(stub, args)
	case "ArchiveToCold":
		return c.ArchiveToCold(stub, args)
	case "ReactivateFromCold":
		return c.ReactivateFromCold(stub, args)
	case "InvalidateEvidence":
		return c.InvalidateEvidence(stub, args)
	case "GetEvidenceSummary":
		return c.GetEvidenceSummary(stub, args)
	case "QueryEvidencesByCase":
		return c.QueryEvidencesByCase(stub, args)
	case "GetCustodyChain":
		return c.GetCustodyChain(stub, args)
	default:
		return shim.Error(fmt.Sprintf("Invalid function name: %s", function))
	}
}

// CreateEvidence creates a new evidence record on the blockchain
// Args: [caseID, evidenceID, cid, hash, metadata]
func (c *EvidenceChaincode) CreateEvidence(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 5 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID, evidenceID, cid, hash, metadata")
	}

	caseID := args[0]
	evidenceID := args[1]
	cid := args[2]
	hash := args[3]
	metadata := args[4]

	// Validate inputs
	if caseID == "" || evidenceID == "" || cid == "" || hash == "" {
		return shim.Error("caseID, evidenceID, cid, and hash cannot be empty")
	}

	// Validate hash format (64 character hex string for SHA-256)
	if len(hash) != 64 {
		return shim.Error("Invalid hash format. Expected SHA-256 (64 hex characters)")
	}
	if _, err := hex.DecodeString(hash); err != nil {
		return shim.Error("Invalid hash format. Must be hexadecimal")
	}

	// Construct composite key: caseID:evidenceID
	key := fmt.Sprintf("%s:%s", caseID, evidenceID)

	// Check if evidence already exists
	existingBytes, err := stub.GetState(key)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to check existing evidence: %s", err.Error()))
	}
	if existingBytes != nil {
		return shim.Error(fmt.Sprintf("Evidence already exists: %s", key))
	}

	// Get creator identity
	creator, err := stub.GetCreator()
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get creator: %s", err.Error()))
	}

	// Extract MSP ID and CN from creator
	mspID, err := c.getMSPID(stub)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get MSP ID: %s", err.Error()))
	}

	txID := stub.GetTxID()
	timestamp := time.Now().UTC().Format(time.RFC3339)

	// Create initial custody event
	initialEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   "CREATE",
		Actor:       string(creator),
		OrgMSP:      mspID,
		Description: "Evidence created and registered",
		TxID:        txID,
	}

	// Create evidence object
	evidence := Evidence{
		CaseID:       caseID,
		EvidenceID:   evidenceID,
		CID:          cid,
		Hash:         hash,
		Metadata:     metadata,
		Status:       StatusActive,
		Events:       []CustodyEvent{initialEvent},
		CreatedAt:    timestamp,
		UpdatedAt:    timestamp,
		CurrentOwner: string(creator),
		OwnerOrgMSP:  mspID,
	}

	// Marshal to JSON
	evidenceJSON, err := json.Marshal(evidence)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to marshal evidence: %s", err.Error()))
	}

	// Store on ledger
	if err := stub.PutState(key, evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to store evidence: %s", err.Error()))
	}

	// Emit event
	if err := stub.SetEvent("EvidenceCreated", evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to emit event: %s", err.Error()))
	}

	return shim.Success(evidenceJSON)
}

// TransferCustody transfers custody of evidence to a new custodian
// Args: [caseID, evidenceID, newCustodian, transferReason]
func (c *EvidenceChaincode) TransferCustody(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 4 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID, evidenceID, newCustodian, transferReason")
	}

	caseID := args[0]
	evidenceID := args[1]
	newCustodian := args[2]
	transferReason := args[3]

	key := fmt.Sprintf("%s:%s", caseID, evidenceID)

	// Get existing evidence
	evidenceBytes, err := stub.GetState(key)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get evidence: %s", err.Error()))
	}
	if evidenceBytes == nil {
		return shim.Error(fmt.Sprintf("Evidence not found: %s", key))
	}

	var evidence Evidence
	if err := json.Unmarshal(evidenceBytes, &evidence); err != nil {
		return shim.Error(fmt.Sprintf("Failed to unmarshal evidence: %s", err.Error()))
	}

	// Check if evidence is in active or reactivated state
	if evidence.Status != StatusActive && evidence.Status != StatusReactivated {
		return shim.Error(fmt.Sprintf("Cannot transfer custody. Evidence status is: %s", evidence.Status))
	}

	// Get current actor
	mspID, err := c.getMSPID(stub)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get MSP ID: %s", err.Error()))
	}

	creator, err := stub.GetCreator()
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get creator: %s", err.Error()))
	}

	timestamp := time.Now().UTC().Format(time.RFC3339)
	txID := stub.GetTxID()

	// Create custody transfer event
	transferEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   "TRANSFER",
		Actor:       string(creator),
		OrgMSP:      mspID,
		Description: fmt.Sprintf("Custody transferred to %s. Reason: %s", newCustodian, transferReason),
		TxID:        txID,
	}

	// Update evidence
	evidence.CurrentOwner = newCustodian
	evidence.OwnerOrgMSP = mspID
	evidence.UpdatedAt = timestamp
	evidence.Events = append(evidence.Events, transferEvent)

	// Store updated evidence
	evidenceJSON, err := json.Marshal(evidence)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to marshal evidence: %s", err.Error()))
	}

	if err := stub.PutState(key, evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to update evidence: %s", err.Error()))
	}

	// Emit event
	if err := stub.SetEvent("CustodyTransferred", evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to emit event: %s", err.Error()))
	}

	return shim.Success(evidenceJSON)
}

// ArchiveToCold archives evidence to the cold chain (called from hot chain only)
// Args: [caseID, evidenceID, archiveReason]
func (c *EvidenceChaincode) ArchiveToCold(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 3 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID, evidenceID, archiveReason")
	}

	caseID := args[0]
	evidenceID := args[1]
	archiveReason := args[2]

	key := fmt.Sprintf("%s:%s", caseID, evidenceID)

	// Get existing evidence
	evidenceBytes, err := stub.GetState(key)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get evidence: %s", err.Error()))
	}
	if evidenceBytes == nil {
		return shim.Error(fmt.Sprintf("Evidence not found: %s", key))
	}

	var evidence Evidence
	if err := json.Unmarshal(evidenceBytes, &evidence); err != nil {
		return shim.Error(fmt.Sprintf("Failed to unmarshal evidence: %s", err.Error()))
	}

	// Only active evidence can be archived
	if evidence.Status != StatusActive {
		return shim.Error(fmt.Sprintf("Cannot archive evidence. Current status: %s", evidence.Status))
	}

	// Get current actor
	mspID, err := c.getMSPID(stub)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get MSP ID: %s", err.Error()))
	}

	creator, err := stub.GetCreator()
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get creator: %s", err.Error()))
	}

	timestamp := time.Now().UTC().Format(time.RFC3339)
	txID := stub.GetTxID()

	// Create archive event
	archiveEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   "ARCHIVE",
		Actor:       string(creator),
		OrgMSP:      mspID,
		Description: fmt.Sprintf("Evidence archived to cold chain. Reason: %s", archiveReason),
		TxID:        txID,
	}

	// Update evidence status
	evidence.Status = StatusArchived
	evidence.UpdatedAt = timestamp
	evidence.Events = append(evidence.Events, archiveEvent)

	// Store updated evidence
	evidenceJSON, err := json.Marshal(evidence)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to marshal evidence: %s", err.Error()))
	}

	if err := stub.PutState(key, evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to update evidence: %s", err.Error()))
	}

	// Emit event
	if err := stub.SetEvent("EvidenceArchived", evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to emit event: %s", err.Error()))
	}

	return shim.Success(evidenceJSON)
}

// ReactivateFromCold reactivates archived evidence back to active status
// Args: [caseID, evidenceID, reactivationReason]
func (c *EvidenceChaincode) ReactivateFromCold(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 3 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID, evidenceID, reactivationReason")
	}

	caseID := args[0]
	evidenceID := args[1]
	reactivationReason := args[2]

	key := fmt.Sprintf("%s:%s", caseID, evidenceID)

	// Get existing evidence
	evidenceBytes, err := stub.GetState(key)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get evidence: %s", err.Error()))
	}
	if evidenceBytes == nil {
		return shim.Error(fmt.Sprintf("Evidence not found: %s", key))
	}

	var evidence Evidence
	if err := json.Unmarshal(evidenceBytes, &evidence); err != nil {
		return shim.Error(fmt.Sprintf("Failed to unmarshal evidence: %s", err.Error()))
	}

	// Only archived evidence can be reactivated
	if evidence.Status != StatusArchived {
		return shim.Error(fmt.Sprintf("Cannot reactivate evidence. Current status: %s", evidence.Status))
	}

	// Get current actor
	mspID, err := c.getMSPID(stub)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get MSP ID: %s", err.Error()))
	}

	creator, err := stub.GetCreator()
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get creator: %s", err.Error()))
	}

	timestamp := time.Now().UTC().Format(time.RFC3339)
	txID := stub.GetTxID()

	// Create reactivation event
	reactivationEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   "REACTIVATE",
		Actor:       string(creator),
		OrgMSP:      mspID,
		Description: fmt.Sprintf("Evidence reactivated from cold chain. Reason: %s", reactivationReason),
		TxID:        txID,
	}

	// Update evidence status
	evidence.Status = StatusReactivated
	evidence.UpdatedAt = timestamp
	evidence.Events = append(evidence.Events, reactivationEvent)

	// Store updated evidence
	evidenceJSON, err := json.Marshal(evidence)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to marshal evidence: %s", err.Error()))
	}

	if err := stub.PutState(key, evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to update evidence: %s", err.Error()))
	}

	// Emit event
	if err := stub.SetEvent("EvidenceReactivated", evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to emit event: %s", err.Error()))
	}

	return shim.Success(evidenceJSON)
}

// InvalidateEvidence marks evidence as invalidated due to tampering or error
// Args: [caseID, evidenceID, reason, wrongTxID]
func (c *EvidenceChaincode) InvalidateEvidence(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 4 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID, evidenceID, reason, wrongTxID")
	}

	caseID := args[0]
	evidenceID := args[1]
	reason := args[2]
	wrongTxID := args[3]

	key := fmt.Sprintf("%s:%s", caseID, evidenceID)

	// Get existing evidence
	evidenceBytes, err := stub.GetState(key)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get evidence: %s", err.Error()))
	}
	if evidenceBytes == nil {
		return shim.Error(fmt.Sprintf("Evidence not found: %s", key))
	}

	var evidence Evidence
	if err := json.Unmarshal(evidenceBytes, &evidence); err != nil {
		return shim.Error(fmt.Sprintf("Failed to unmarshal evidence: %s", err.Error()))
	}

	// Get current actor
	mspID, err := c.getMSPID(stub)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get MSP ID: %s", err.Error()))
	}

	creator, err := stub.GetCreator()
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get creator: %s", err.Error()))
	}

	timestamp := time.Now().UTC().Format(time.RFC3339)
	txID := stub.GetTxID()

	// Create invalidation event
	invalidationEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   "INVALIDATE",
		Actor:       string(creator),
		OrgMSP:      mspID,
		Description: fmt.Sprintf("Evidence invalidated. Reason: %s. Wrong TxID: %s", reason, wrongTxID),
		TxID:        txID,
	}

	// Update evidence status
	evidence.Status = StatusInvalidated
	evidence.UpdatedAt = timestamp
	evidence.Events = append(evidence.Events, invalidationEvent)

	// Store updated evidence
	evidenceJSON, err := json.Marshal(evidence)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to marshal evidence: %s", err.Error()))
	}

	if err := stub.PutState(key, evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to update evidence: %s", err.Error()))
	}

	// Emit event
	if err := stub.SetEvent("EvidenceInvalidated", evidenceJSON); err != nil {
		return shim.Error(fmt.Sprintf("Failed to emit event: %s", err.Error()))
	}

	return shim.Success(evidenceJSON)
}

// GetEvidenceSummary retrieves the complete evidence record
// Args: [caseID, evidenceID]
func (c *EvidenceChaincode) GetEvidenceSummary(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 2 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID, evidenceID")
	}

	caseID := args[0]
	evidenceID := args[1]

	key := fmt.Sprintf("%s:%s", caseID, evidenceID)

	evidenceBytes, err := stub.GetState(key)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get evidence: %s", err.Error()))
	}
	if evidenceBytes == nil {
		return shim.Error(fmt.Sprintf("Evidence not found: %s", key))
	}

	return shim.Success(evidenceBytes)
}

// QueryEvidencesByCase retrieves all evidence for a specific case
// Args: [caseID]
func (c *EvidenceChaincode) QueryEvidencesByCase(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 1 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID")
	}

	caseID := args[0]

	// Query using composite key prefix
	iterator, err := stub.GetStateByPartialCompositeKey("", []string{caseID})
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to query evidence: %s", err.Error()))
	}
	defer iterator.Close()

	var evidenceList []Evidence

	for iterator.HasNext() {
		queryResponse, err := iterator.Next()
		if err != nil {
			return shim.Error(fmt.Sprintf("Iterator error: %s", err.Error()))
		}

		var evidence Evidence
		if err := json.Unmarshal(queryResponse.Value, &evidence); err != nil {
			continue
		}

		evidenceList = append(evidenceList, evidence)
	}

	resultJSON, err := json.Marshal(evidenceList)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to marshal results: %s", err.Error()))
	}

	return shim.Success(resultJSON)
}

// GetCustodyChain retrieves the complete custody chain for evidence
// Args: [caseID, evidenceID]
func (c *EvidenceChaincode) GetCustodyChain(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 2 {
		return shim.Error("Incorrect number of arguments. Expecting: caseID, evidenceID")
	}

	caseID := args[0]
	evidenceID := args[1]

	key := fmt.Sprintf("%s:%s", caseID, evidenceID)

	evidenceBytes, err := stub.GetState(key)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to get evidence: %s", err.Error()))
	}
	if evidenceBytes == nil {
		return shim.Error(fmt.Sprintf("Evidence not found: %s", key))
	}

	var evidence Evidence
	if err := json.Unmarshal(evidenceBytes, &evidence); err != nil {
		return shim.Error(fmt.Sprintf("Failed to unmarshal evidence: %s", err.Error()))
	}

	// Return only the events (custody chain)
	eventsJSON, err := json.Marshal(evidence.Events)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to marshal events: %s", err.Error()))
	}

	return shim.Success(eventsJSON)
}

// Helper function to get MSP ID
func (c *EvidenceChaincode) getMSPID(stub shim.ChaincodeStubInterface) (string, error) {
	mspID, err := shim.GetMSPID()
	if err != nil {
		return "", fmt.Errorf("failed to get MSP ID: %s", err.Error())
	}
	return mspID, nil
}

// ComputeHash computes SHA-256 hash of data
func ComputeHash(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

// main function starts the chaincode
func main() {
	if err := shim.Start(new(EvidenceChaincode)); err != nil {
		fmt.Printf("Error starting Evidence chaincode: %s", err)
	}
}
