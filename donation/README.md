# ClarityCharity

ClarityCharity is a decentralized charity donation platform built on the Stacks blockchain using Clarity smart contracts. The platform enables transparent, secure, and efficient charitable giving with multiple distribution models and complete on-chain traceability.

## Overview

ClarityCharity addresses the challenges of traditional charitable giving by leveraging blockchain technology to create a transparent and efficient donation platform. The smart contract enables campaign creators to establish charitable campaigns with multiple causes, while donors can contribute to specific causes with full confidence that their funds will be distributed according to predefined rules.

## Features

- **Multiple Campaign Types**: Support for equal-split, weighted, and milestone-based distribution models
- **Transparent Donations**: All donations are recorded on the blockchain, ensuring complete transparency
- **Multiple Causes**: Each campaign can support up to 10 charitable causes
- **Campaign Lifecycle Management**: Complete features for creation, donation, closing, cancellation, and settlement
- **Direct Beneficiary Claims**: Beneficiaries can directly claim their allocated funds
- **Secure Fund Management**: Smart contract ensures funds are distributed according to predefined rules
- **Refund Capability**: Donors can receive refunds if a campaign is canceled

## Smart Contract Architecture

The smart contract is built using Clarity, a decidable smart contract language designed for the Stacks blockchain. The contract architecture includes:

- **Data Maps**: Store campaign details and donation information
- **Public Functions**: Interface for users to interact with the contract
- **Private Functions**: Internal logic for calculations and validations
- **Read-only Functions**: Query campaign and donation information

## Campaign Types

The contract supports three campaign types:

1. **Equal-Split**: Funds are distributed equally among selected causes
2. **Weighted**: Funds are distributed based on predefined weights for each cause
3. **Milestone-Based**: Funds are distributed based on milestone achievements

## Getting Started

### Prerequisites

- Stacks wallet (Hiro Wallet or similar)
- STX tokens for transactions
- Basic understanding of blockchain transactions

### Interacting with the Contract

1. **Create a Campaign**:
   - Define campaign description, charitable causes, close height, and campaign type
   - For weighted campaigns, provide distribution weights

2. **Make a Donation**:
   - Select a campaign and cause
   - Specify donation amount

3. **Close a Campaign**:
   - Campaign creator or contract owner can close a campaign after the close height

4. **Settle a Campaign**:
   - Contract owner selects the final causes that will receive funds

5. **Claim Funds**:
   - Beneficiaries can claim their allocated funds after settlement

## Contract Functions

### Public Functions

- `create-donation-campaign`: Create a new donation campaign
- `make-donation`: Make a donation to a specific cause in a campaign
- `close-donation-campaign`: Close a campaign after its close height
- `cancel-donation-campaign`: Cancel a campaign before its close height
- `claim-beneficiary-funds`: Claim funds as a beneficiary
- `settle-donation-campaign`: Select final causes for fund distribution

### Read-only Functions

- `get-donation-campaign`: Get campaign details
- `get-donation`: Get donation details
- `get-current-block-height`: Get current block height

## Error Handling

The contract includes comprehensive error handling with specific error codes for different scenarios:

- Authentication errors (unauthorized access)
- State errors (campaign closed, already settled)
- Validation errors (invalid cause, invalid amount)
- Execution errors (refund failed, insufficient funds)

## Security Considerations

- The contract uses principal-based authentication for sensitive operations
- Funds are held in the contract until explicitly claimed or refunded
- Validation checks prevent invalid operations
- Block height checks ensure operations occur at appropriate times

