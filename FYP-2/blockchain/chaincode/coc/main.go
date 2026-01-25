// Chain of Custody Chaincode - External Service Mode
// Digital Forensics Evidence Management System

package main

import (
	"fmt"
	"os"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating chaincode: %v\n", err)
		os.Exit(1)
	}

	// Check if running as external service
	ccid := os.Getenv("CHAINCODE_ID")
	ccaddr := os.Getenv("CHAINCODE_SERVER_ADDRESS")

	if ccid != "" && ccaddr != "" {
		// Running as external chaincode service
		server := &shim.ChaincodeServer{
			CCID:    ccid,
			Address: ccaddr,
			CC:      chaincode,
			TLSProps: shim.TLSProperties{
				Disabled: true,
			},
		}

		fmt.Printf("Starting chaincode server with CCID: %s at address: %s\n", ccid, ccaddr)
		if err := server.Start(); err != nil {
			fmt.Printf("Error starting chaincode server: %v\n", err)
			os.Exit(1)
		}
	} else {
		// Running in traditional mode (peer-launched)
		if err := chaincode.Start(); err != nil {
			fmt.Printf("Error starting chaincode: %v\n", err)
			os.Exit(1)
		}
	}
}
