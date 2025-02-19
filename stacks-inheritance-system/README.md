# Digital Asset Will Smart Contract

## Overview
This smart contract implements a digital asset will system on the Stacks blockchain. It allows users to create digital wills for transferring their blockchain assets (STX tokens, fungible tokens, and non-fungible tokens) to designated beneficiaries after a specified period of inactivity.

## Key Features
- **Asset Distribution**: Specify multiple beneficiaries with percentage-based allocation
- **Multi-Executor Support**: Designate up to 3 secondary executors who can trigger will execution
- **Dormancy Detection**: Automatic execution eligibility after a customizable inactivity period
- **Asset Variety**: Support for STX tokens, SIP-010 fungible tokens, and SIP-009 non-fungible tokens
- **Activity Proof**: Record owner activity to prevent premature execution
- **Complete Event Logging**: Track all will-related actions with timestamps and details
- **Security Measures**: Comprehensive validation and authorization checks

## Contract Architecture

### Data Structures
- `digital-asset-wills`: Maps user principals to their will configuration
- `will-events`: Records all will-related events with timestamps and details

### Main Functions

#### For Will Owners
- `create-digital-will`: Create a new digital will with beneficiaries, executors, and assets
- `update-dormancy-period`: Modify the required inactivity period
- `update-secondary-executors`: Change the authorized executors list
- `record-owner-activity`: Update activity timestamp to prevent execution
- `revoke-digital-will`: Deactivate a will entirely

#### For Executors
- `execute-will-transfer`: Execute a will after dormancy period, transferring assets to beneficiaries

#### Read-Only Functions
- `get-will-details`: Retrieve complete will configuration
- `get-will-event`: Access specific event details
- `check-will-execution-status`: Check if a will is eligible for execution

### Security Features
- Duplicate executor detection
- Beneficiary share validation (must total ≤100%)
- Proper asset validation
- Prevention of self-execution
- Status checks to prevent double-execution

## Error Codes
| Code | Description |
|------|-------------|
| u100 | Executor not authorized |
| u101 | Will already exists |
| u102 | Will does not exist |
| u103 | Invalid beneficiary details |
| u104 | Will transfer already completed |
| u105 | Will not active |
| u106 | Unauthorized executor |
| u107 | Invalid time period |
| u108 | Asset transfer failed |
| u109 | Invalid asset details |
| u110 | Duplicate executor found |
| u111 | Asset amount zero |
| u112 | Invalid beneficiary allocation |
| u113 | Testator self-execution |

## Usage Example

### Creating a Digital Will
```clarity
(contract-call? .digital-asset-will create-digital-will
    ;; List of heirs with percentages
    (list 
        {heir: 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5, share-percentage: u60}
        {heir: 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG, share-percentage: u40}
    )
    ;; Secondary executors
    (list 
        'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC
        'ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND
    )
    ;; Dormancy period (in seconds)
    u31536000 ;; 1 year
    ;; STX assets
    (list 
        {token-quantity: u1000000000} ;; 1000 STX
    )
    ;; Fungible token assets
    (list 
        {token-smart-contract: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-xyz, token-quantity: u5000}
    )
    ;; Non-fungible token assets
    (list 
        {nft-smart-contract: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.nft-abc, nft-identifier: u721}
    )
)
```

### Checking Will Status
```clarity
(contract-call? .digital-asset-will check-will-execution-status 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Recording Activity
```clarity
(contract-call? .digital-asset-will record-owner-activity)
```