// Chain of Custody Chaincode
// Digital Forensics Evidence Management System
// Implements the 8 core functions for managing evidence on Hot and Cold chains

package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing evidence chain of custody
type SmartContract struct {
	contractapi.Contract
}

// EvidenceStatus represents the current state of evidence
type EvidenceStatus string

const (
	StatusActive      EvidenceStatus = "ACTIVE"
	StatusArchived    EvidenceStatus = "ARCHIVED"
	StatusReactivated EvidenceStatus = "REACTIVATED"
	StatusInvalidated EvidenceStatus = "INVALIDATED"
)

// EventType represents types of custody events
type EventType string

const (
	EventCreate     EventType = "CREATE"
	EventTransfer   EventType = "TRANSFER"
	EventArchive    EventType = "ARCHIVE"
	EventReactivate EventType = "REACTIVATE"
	EventInvalidate EventType = "INVALIDATE"
)

// CustodyEvent represents a single event in the chain of custody
type CustodyEvent struct {
	Timestamp   string    `json:"timestamp"`
	EventType   EventType `json:"eventType"`
	Actor       string    `json:"actor"`
	OrgMSP      string    `json:"orgMSP"`
	Description string    `json:"description"`
	TxID        string    `json:"txID"`
}

// Evidence represents a piece of digital forensic evidence
type Evidence struct {
	CaseID       string         `json:"caseID"`
	EvidenceID   string         `json:"evidenceID"`
	CID          string         `json:"cid"`          // IPFS Content ID
	Hash         string         `json:"hash"`         // SHA-256 hash of the evidence
	Metadata     string         `json:"metadata"`     // JSON string with additional metadata
	Status       EvidenceStatus `json:"status"`
	Events       []CustodyEvent `json:"events"`
	CurrentOwner string         `json:"currentOwner"`
	OrgMSP       string         `json:"orgMSP"`
	CreatedAt    string         `json:"createdAt"`
	UpdatedAt    string         `json:"updatedAt"`
}

// EvidenceSummary is a lightweight version of Evidence for queries
type EvidenceSummary struct {
	CaseID       string         `json:"caseID"`
	EvidenceID   string         `json:"evidenceID"`
	Status       EvidenceStatus `json:"status"`
	CurrentOwner string         `json:"currentOwner"`
	OrgMSP       string         `json:"orgMSP"`
	EventCount   int            `json:"eventCount"`
	CreatedAt    string         `json:"createdAt"`
	UpdatedAt    string         `json:"updatedAt"`
}

// InvalidationRecord stores details about invalidated evidence
type InvalidationRecord struct {
	EvidenceID   string `json:"evidenceID"`
	CaseID       string `json:"caseID"`
	Reason       string `json:"reason"`
	WrongTxID    string `json:"wrongTxID"`
	InvalidatedAt string `json:"invalidatedAt"`
	InvalidatedBy string `json:"invalidatedBy"`
}

// Helper function to create composite key for evidence
func (s *SmartContract) createEvidenceKey(ctx contractapi.TransactionContextInterface, caseID, evidenceID string) string {
	return fmt.Sprintf("EVIDENCE_%s_%s", caseID, evidenceID)
}

// Helper function to get client identity information
func (s *SmartContract) getClientIdentity(ctx contractapi.TransactionContextInterface) (string, string, error) {
	// Get the client's MSP ID
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return "", "", fmt.Errorf("failed to get MSP ID: %v", err)
	}

	// Get the client's certificate CN (Common Name)
	cert, err := ctx.GetClientIdentity().GetX509Certificate()
	if err != nil {
		return "", "", fmt.Errorf("failed to get certificate: %v", err)
	}

	return cert.Subject.CommonName, mspID, nil
}

// Helper function to get current timestamp
func (s *SmartContract) getCurrentTimestamp(ctx contractapi.TransactionContextInterface) string {
	txTimestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return time.Now().UTC().Format(time.RFC3339)
	}
	return time.Unix(txTimestamp.Seconds, int64(txTimestamp.Nanos)).UTC().Format(time.RFC3339)
}

// ============================================================================
// Function 1: CreateEvidence
// Creates a new evidence record on the blockchain
// ============================================================================
func (s *SmartContract) CreateEvidence(ctx contractapi.TransactionContextInterface, caseID, evidenceID, cid, hash, metadata string) error {
	// Validate inputs
	if caseID == "" || evidenceID == "" || cid == "" || hash == "" {
		return fmt.Errorf("caseID, evidenceID, cid, and hash are required")
	}

	// Check if evidence already exists
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	existingEvidence, err := ctx.GetStub().GetState(key)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if existingEvidence != nil {
		return fmt.Errorf("evidence %s already exists for case %s", evidenceID, caseID)
	}

	// Get client identity
	actor, mspID, err := s.getClientIdentity(ctx)
	if err != nil {
		return err
	}

	timestamp := s.getCurrentTimestamp(ctx)
	txID := ctx.GetStub().GetTxID()

	// Create initial custody event
	createEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   EventCreate,
		Actor:       actor,
		OrgMSP:      mspID,
		Description: fmt.Sprintf("Evidence created for case %s", caseID),
		TxID:        txID,
	}

	// Create evidence record
	evidence := Evidence{
		CaseID:       caseID,
		EvidenceID:   evidenceID,
		CID:          cid,
		Hash:         hash,
		Metadata:     metadata,
		Status:       StatusActive,
		Events:       []CustodyEvent{createEvent},
		CurrentOwner: actor,
		OrgMSP:       mspID,
		CreatedAt:    timestamp,
		UpdatedAt:    timestamp,
	}

	// Store evidence
	evidenceJSON, err := json.Marshal(evidence)
	if err != nil {
		return fmt.Errorf("failed to marshal evidence: %v", err)
	}

	err = ctx.GetStub().PutState(key, evidenceJSON)
	if err != nil {
		return fmt.Errorf("failed to write to world state: %v", err)
	}

	// Emit event
	ctx.GetStub().SetEvent("EvidenceCreated", evidenceJSON)

	return nil
}

// ============================================================================
// Function 2: TransferCustody
// Transfers custody of evidence to a new custodian
// ============================================================================
func (s *SmartContract) TransferCustody(ctx contractapi.TransactionContextInterface, caseID, evidenceID, newCustodian, transferReason string) error {
	// Validate inputs
	if caseID == "" || evidenceID == "" || newCustodian == "" {
		return fmt.Errorf("caseID, evidenceID, and newCustodian are required")
	}

	// Get evidence
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if evidenceJSON == nil {
		return fmt.Errorf("evidence %s not found for case %s", evidenceID, caseID)
	}

	var evidence Evidence
	err = json.Unmarshal(evidenceJSON, &evidence)
	if err != nil {
		return fmt.Errorf("failed to unmarshal evidence: %v", err)
	}

	// Check evidence status
	if evidence.Status == StatusInvalidated {
		return fmt.Errorf("cannot transfer invalidated evidence")
	}
	if evidence.Status == StatusArchived {
		return fmt.Errorf("cannot transfer archived evidence - reactivate first")
	}

	// Get client identity
	actor, mspID, err := s.getClientIdentity(ctx)
	if err != nil {
		return err
	}

	timestamp := s.getCurrentTimestamp(ctx)
	txID := ctx.GetStub().GetTxID()

	// Create transfer event
	description := fmt.Sprintf("Custody transferred from %s to %s", evidence.CurrentOwner, newCustodian)
	if transferReason != "" {
		description += fmt.Sprintf(". Reason: %s", transferReason)
	}

	transferEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   EventTransfer,
		Actor:       actor,
		OrgMSP:      mspID,
		Description: description,
		TxID:        txID,
	}

	// Update evidence
	evidence.CurrentOwner = newCustodian
	evidence.Events = append(evidence.Events, transferEvent)
	evidence.UpdatedAt = timestamp

	// Store updated evidence
	updatedJSON, err := json.Marshal(evidence)
	if err != nil {
		return fmt.Errorf("failed to marshal evidence: %v", err)
	}

	err = ctx.GetStub().PutState(key, updatedJSON)
	if err != nil {
		return fmt.Errorf("failed to write to world state: %v", err)
	}

	// Emit event
	ctx.GetStub().SetEvent("CustodyTransferred", updatedJSON)

	return nil
}

// ============================================================================
// Function 3: ArchiveToCold
// Archives evidence from hot chain to cold chain
// ============================================================================
func (s *SmartContract) ArchiveToCold(ctx contractapi.TransactionContextInterface, caseID, evidenceID, archiveReason string) error {
	// Validate inputs
	if caseID == "" || evidenceID == "" {
		return fmt.Errorf("caseID and evidenceID are required")
	}

	// Get evidence
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if evidenceJSON == nil {
		return fmt.Errorf("evidence %s not found for case %s", evidenceID, caseID)
	}

	var evidence Evidence
	err = json.Unmarshal(evidenceJSON, &evidence)
	if err != nil {
		return fmt.Errorf("failed to unmarshal evidence: %v", err)
	}

	// Check evidence status
	if evidence.Status == StatusInvalidated {
		return fmt.Errorf("cannot archive invalidated evidence")
	}
	if evidence.Status == StatusArchived {
		return fmt.Errorf("evidence is already archived")
	}

	// Get client identity
	actor, mspID, err := s.getClientIdentity(ctx)
	if err != nil {
		return err
	}

	timestamp := s.getCurrentTimestamp(ctx)
	txID := ctx.GetStub().GetTxID()

	// Create archive event
	description := fmt.Sprintf("Evidence archived to cold storage")
	if archiveReason != "" {
		description += fmt.Sprintf(". Reason: %s", archiveReason)
	}

	archiveEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   EventArchive,
		Actor:       actor,
		OrgMSP:      mspID,
		Description: description,
		TxID:        txID,
	}

	// Update evidence
	evidence.Status = StatusArchived
	evidence.Events = append(evidence.Events, archiveEvent)
	evidence.UpdatedAt = timestamp

	// Store updated evidence
	updatedJSON, err := json.Marshal(evidence)
	if err != nil {
		return fmt.Errorf("failed to marshal evidence: %v", err)
	}

	err = ctx.GetStub().PutState(key, updatedJSON)
	if err != nil {
		return fmt.Errorf("failed to write to world state: %v", err)
	}

	// Emit event
	ctx.GetStub().SetEvent("EvidenceArchived", updatedJSON)

	return nil
}

// ============================================================================
// Function 4: ReactivateFromCold
// Reactivates archived evidence from cold chain
// ============================================================================
func (s *SmartContract) ReactivateFromCold(ctx contractapi.TransactionContextInterface, caseID, evidenceID, reactivationReason string) error {
	// Validate inputs
	if caseID == "" || evidenceID == "" {
		return fmt.Errorf("caseID and evidenceID are required")
	}

	// Get evidence
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if evidenceJSON == nil {
		return fmt.Errorf("evidence %s not found for case %s", evidenceID, caseID)
	}

	var evidence Evidence
	err = json.Unmarshal(evidenceJSON, &evidence)
	if err != nil {
		return fmt.Errorf("failed to unmarshal evidence: %v", err)
	}

	// Check evidence status
	if evidence.Status == StatusInvalidated {
		return fmt.Errorf("cannot reactivate invalidated evidence")
	}
	if evidence.Status != StatusArchived {
		return fmt.Errorf("evidence is not archived")
	}

	// Get client identity
	actor, mspID, err := s.getClientIdentity(ctx)
	if err != nil {
		return err
	}

	timestamp := s.getCurrentTimestamp(ctx)
	txID := ctx.GetStub().GetTxID()

	// Create reactivation event
	description := fmt.Sprintf("Evidence reactivated from cold storage")
	if reactivationReason != "" {
		description += fmt.Sprintf(". Reason: %s", reactivationReason)
	}

	reactivateEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   EventReactivate,
		Actor:       actor,
		OrgMSP:      mspID,
		Description: description,
		TxID:        txID,
	}

	// Update evidence
	evidence.Status = StatusReactivated
	evidence.Events = append(evidence.Events, reactivateEvent)
	evidence.UpdatedAt = timestamp

	// Store updated evidence
	updatedJSON, err := json.Marshal(evidence)
	if err != nil {
		return fmt.Errorf("failed to marshal evidence: %v", err)
	}

	err = ctx.GetStub().PutState(key, updatedJSON)
	if err != nil {
		return fmt.Errorf("failed to write to world state: %v", err)
	}

	// Emit event
	ctx.GetStub().SetEvent("EvidenceReactivated", updatedJSON)

	return nil
}

// ============================================================================
// Function 5: InvalidateEvidence
// Invalidates evidence due to tampering or procedural errors
// ============================================================================
func (s *SmartContract) InvalidateEvidence(ctx contractapi.TransactionContextInterface, caseID, evidenceID, reason, wrongTxID string) error {
	// Validate inputs
	if caseID == "" || evidenceID == "" || reason == "" {
		return fmt.Errorf("caseID, evidenceID, and reason are required")
	}

	// Get evidence
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if evidenceJSON == nil {
		return fmt.Errorf("evidence %s not found for case %s", evidenceID, caseID)
	}

	var evidence Evidence
	err = json.Unmarshal(evidenceJSON, &evidence)
	if err != nil {
		return fmt.Errorf("failed to unmarshal evidence: %v", err)
	}

	// Check if already invalidated
	if evidence.Status == StatusInvalidated {
		return fmt.Errorf("evidence is already invalidated")
	}

	// Get client identity
	actor, mspID, err := s.getClientIdentity(ctx)
	if err != nil {
		return err
	}

	timestamp := s.getCurrentTimestamp(ctx)
	txID := ctx.GetStub().GetTxID()

	// Create invalidation event
	description := fmt.Sprintf("Evidence invalidated. Reason: %s", reason)
	if wrongTxID != "" {
		description += fmt.Sprintf(". Related transaction: %s", wrongTxID)
	}

	invalidateEvent := CustodyEvent{
		Timestamp:   timestamp,
		EventType:   EventInvalidate,
		Actor:       actor,
		OrgMSP:      mspID,
		Description: description,
		TxID:        txID,
	}

	// Update evidence
	evidence.Status = StatusInvalidated
	evidence.Events = append(evidence.Events, invalidateEvent)
	evidence.UpdatedAt = timestamp

	// Store updated evidence
	updatedJSON, err := json.Marshal(evidence)
	if err != nil {
		return fmt.Errorf("failed to marshal evidence: %v", err)
	}

	err = ctx.GetStub().PutState(key, updatedJSON)
	if err != nil {
		return fmt.Errorf("failed to write to world state: %v", err)
	}

	// Store invalidation record for audit purposes
	invalidationRecord := InvalidationRecord{
		EvidenceID:    evidenceID,
		CaseID:        caseID,
		Reason:        reason,
		WrongTxID:     wrongTxID,
		InvalidatedAt: timestamp,
		InvalidatedBy: actor,
	}

	invalidationKey := fmt.Sprintf("INVALIDATION_%s_%s", caseID, evidenceID)
	invalidationJSON, err := json.Marshal(invalidationRecord)
	if err != nil {
		return fmt.Errorf("failed to marshal invalidation record: %v", err)
	}

	err = ctx.GetStub().PutState(invalidationKey, invalidationJSON)
	if err != nil {
		return fmt.Errorf("failed to write invalidation record: %v", err)
	}

	// Emit event
	ctx.GetStub().SetEvent("EvidenceInvalidated", updatedJSON)

	return nil
}

// ============================================================================
// Function 6: GetEvidenceSummary
// Returns a summary of the evidence
// ============================================================================
func (s *SmartContract) GetEvidenceSummary(ctx contractapi.TransactionContextInterface, caseID, evidenceID string) (*EvidenceSummary, error) {
	// Validate inputs
	if caseID == "" || evidenceID == "" {
		return nil, fmt.Errorf("caseID and evidenceID are required")
	}

	// Get evidence
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if evidenceJSON == nil {
		return nil, fmt.Errorf("evidence %s not found for case %s", evidenceID, caseID)
	}

	var evidence Evidence
	err = json.Unmarshal(evidenceJSON, &evidence)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal evidence: %v", err)
	}

	// Create summary
	summary := &EvidenceSummary{
		CaseID:       evidence.CaseID,
		EvidenceID:   evidence.EvidenceID,
		Status:       evidence.Status,
		CurrentOwner: evidence.CurrentOwner,
		OrgMSP:       evidence.OrgMSP,
		EventCount:   len(evidence.Events),
		CreatedAt:    evidence.CreatedAt,
		UpdatedAt:    evidence.UpdatedAt,
	}

	return summary, nil
}

// ============================================================================
// Function 7: QueryEvidencesByCase
// Returns all evidence for a specific case
// ============================================================================
func (s *SmartContract) QueryEvidencesByCase(ctx contractapi.TransactionContextInterface, caseID string) ([]*Evidence, error) {
	// Validate inputs
	if caseID == "" {
		return nil, fmt.Errorf("caseID is required")
	}

	// Create query string for CouchDB
	queryString := fmt.Sprintf(`{"selector":{"caseID":"%s"}}`, caseID)

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer resultsIterator.Close()

	var evidences []*Evidence
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate results: %v", err)
		}

		var evidence Evidence
		err = json.Unmarshal(queryResult.Value, &evidence)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshal evidence: %v", err)
		}
		evidences = append(evidences, &evidence)
	}

	return evidences, nil
}

// ============================================================================
// Function 8: GetCustodyChain
// Returns the complete chain of custody events for an evidence
// ============================================================================
func (s *SmartContract) GetCustodyChain(ctx contractapi.TransactionContextInterface, caseID, evidenceID string) ([]CustodyEvent, error) {
	// Validate inputs
	if caseID == "" || evidenceID == "" {
		return nil, fmt.Errorf("caseID and evidenceID are required")
	}

	// Get evidence
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if evidenceJSON == nil {
		return nil, fmt.Errorf("evidence %s not found for case %s", evidenceID, caseID)
	}

	var evidence Evidence
	err = json.Unmarshal(evidenceJSON, &evidence)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal evidence: %v", err)
	}

	return evidence.Events, nil
}

// ============================================================================
// Additional Helper Functions
// ============================================================================

// GetEvidence returns the full evidence record
func (s *SmartContract) GetEvidence(ctx contractapi.TransactionContextInterface, caseID, evidenceID string) (*Evidence, error) {
	// Validate inputs
	if caseID == "" || evidenceID == "" {
		return nil, fmt.Errorf("caseID and evidenceID are required")
	}

	// Get evidence
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if evidenceJSON == nil {
		return nil, fmt.Errorf("evidence %s not found for case %s", evidenceID, caseID)
	}

	var evidence Evidence
	err = json.Unmarshal(evidenceJSON, &evidence)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal evidence: %v", err)
	}

	return &evidence, nil
}

// EvidenceExists checks if evidence exists
func (s *SmartContract) EvidenceExists(ctx contractapi.TransactionContextInterface, caseID, evidenceID string) (bool, error) {
	key := s.createEvidenceKey(ctx, caseID, evidenceID)
	evidenceJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}
	return evidenceJSON != nil, nil
}

// QueryEvidencesByStatus returns all evidence with a specific status
func (s *SmartContract) QueryEvidencesByStatus(ctx contractapi.TransactionContextInterface, status string) ([]*Evidence, error) {
	// Validate status
	validStatuses := map[string]bool{
		string(StatusActive):      true,
		string(StatusArchived):    true,
		string(StatusReactivated): true,
		string(StatusInvalidated): true,
	}
	if !validStatuses[status] {
		return nil, fmt.Errorf("invalid status: %s", status)
	}

	// Create query string for CouchDB
	queryString := fmt.Sprintf(`{"selector":{"status":"%s"}}`, status)

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer resultsIterator.Close()

	var evidences []*Evidence
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate results: %v", err)
		}

		var evidence Evidence
		err = json.Unmarshal(queryResult.Value, &evidence)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshal evidence: %v", err)
		}
		evidences = append(evidences, &evidence)
	}

	return evidences, nil
}

// InitLedger initializes the ledger with sample data (for testing)
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	// This function can be used for testing purposes
	// In production, it should be empty or removed
	return nil
}

// main function moved to main.go for external chaincode support
