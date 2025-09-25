# 📊 Tokenized Employee Stock Options Contract

A comprehensive Clarity smart contract for managing employee stock options with automatic vesting schedules, cliff periods, and exercise mechanisms on the Stacks blockchain.

## 🎯 Overview

This contract provides a complete solution for companies to issue and manage tokenized employee stock options (ESOPs) with the following key features:

- **Automatic Vesting**: Time-based vesting with configurable cliff and vesting periods
- **NFT-based Grants**: Each stock option grant is represented as a unique NFT
- **Fungible Equity Tokens**: Company shares are represented as fungible tokens
- **Exercise Mechanism**: Employees can exercise vested options by paying the strike price
- **Termination Handling**: Unvested options are automatically returned to the company pool
- **Vesting Acceleration**: Support for accelerated vesting in special circumstances
- **Employee Profiles**: Track employee information and department details
- **Company Valuation**: Maintain and update company valuation for reference

## 🚀 Key Features

### Token Systems
- **Company Equity** (Fungible Token): Represents actual company shares
- **Stock Option Grants** (Non-Fungible Token): Unique identifiers for each grant

### Vesting Mechanics
- Configurable cliff periods (up to 12 months)
- Linear vesting after cliff period
- Maximum vesting period of 4 years
- Block-based time tracking using `stacks-block-height`

### Administrative Functions
- Grant issuance with customizable terms
- Grant termination with automatic unvested share recovery
- Vesting acceleration capabilities
- Company valuation updates
- Employee profile management

## 📝 Usage Guide

### 1. Initialize the Company

First, the contract owner must initialize the company with its name and total shares:

```clarity
(contract-call? .Tokenized-Employee-Stock-Options initialize-company 
    "Acme Corp" 
    u10000000)  ;; 10 million shares
```

### 2. Add Employee Profiles

Register employees before granting them options:

```clarity
(contract-call? .Tokenized-Employee-Stock-Options add-employee-profile
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
    "Engineering"
    "Senior Developer")
```

### 3. Grant Stock Options

Issue stock option grants to employees with specific vesting terms:

```clarity
(contract-call? .Tokenized-Employee-Stock-Options grant-options
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; employee principal
    u10000         ;; 10,000 shares
    u12            ;; 12-month cliff
    u48            ;; 48-month total vesting
    u100)          ;; exercise price of 100 microSTX per share
```

### 4. Check Vesting Status

Employees can check their vested amount at any time:

```clarity
(contract-call? .Tokenized-Employee-Stock-Options get-vested-amount u1)  ;; grant-id
```

### 5. Claim Vested Options

Employees claim their vested options (receive equity tokens):

```clarity
(contract-call? .Tokenized-Employee-Stock-Options claim-vested u1)  ;; grant-id
```

### 6. Exercise Options

Employees can exercise vested options by paying the strike price:

```clarity
(contract-call? .Tokenized-Employee-Stock-Options exercise-options 
    u1      ;; grant-id
    u5000)  ;; amount to exercise
```

### 7. Handle Terminations

When an employee leaves, terminate their grant to recover unvested shares:

```clarity
(contract-call? .Tokenized-Employee-Stock-Options terminate-grant u1)
```

### 8. Accelerate Vesting

In special cases (e.g., acquisition), accelerate vesting:

```clarity
(contract-call? .Tokenized-Employee-Stock-Options accelerate-vesting u1)
```

## 📊 Read-Only Functions

Query contract state with these read-only functions:

- `get-grant-details`: Full details of a specific grant
- `get-employee-grants`: All grants for a specific employee
- `get-company-info`: Company-wide statistics
- `get-vesting-schedule`: Vesting schedule details
- `get-employee-profile`: Employee profile information
- `get-current-valuation`: Current company valuation
- `get-vested-amount`: Calculate vested amount for a grant
- `get-claimable-amount`: Amount available to claim
- `get-total-shares`: Total shares outstanding

## 🔢 Constants & Configuration

### Time Constants
- `blocks-per-month`: 4,320 blocks (~30 days)
- `blocks-per-year`: 52,560 blocks (~365 days)
- `max-vesting-period`: 210,240 blocks (~4 years)
- `max-cliff-period`: 52,560 blocks (~1 year)

### Error Codes
- `u100`: Owner only operation
- `u101`: Not authorized
- `u102`: Grant not found
- `u103`: Insufficient balance
- `u104`: Already exists
- `u105`: Invalid cliff period
- `u106`: Invalid vesting period
- `u107`: Nothing vested
- `u108`: Already claimed
- `u109`: Not vested
- `u110`: Invalid amount
- `u111`: Employee already exists
- `u112`: Company not found
- `u113`: Exercise expired
- `u114`: Invalid price

## 🏗️ Contract Architecture

### Data Structures

**Stock Grants Map**: Core grant information including employee, amounts, vesting terms, and status

**Employee Grants Map**: Aggregated view of all grants per employee

**Company Info Map**: Global company statistics and share allocation

**Vesting Schedules Map**: Detailed vesting schedule parameters

**Exercise History Map**: Historical record of option exercises

**Employee Profiles Map**: Employee metadata and department information

## 🔐 Security Features

- Owner-only administrative functions
- Employee-only claim and exercise functions
- Validation of all vesting parameters
- Protection against double-claiming
- Automatic handling of terminated grants
- Block-height based time tracking for accuracy

## 💡 Example Scenarios

### Standard 4-Year Vesting with 1-Year Cliff
```clarity
;; Grant 40,000 options with standard Silicon Valley terms
(grant-options employee u40000 u12 u48 u250)
;; After 1 year: 10,000 options vest (25%)
;; Monthly thereafter: ~833 options vest
```

### Accelerated Vesting on Acquisition
```clarity
;; Original grant
(grant-options employee u100000 u6 u36 u500)
;; Company acquired after 18 months
(accelerate-vesting grant-id)
;; All remaining options become immediately vested
```

### Employee Termination
```clarity
;; Employee with 50,000 options, 20,000 vested
(terminate-grant grant-id)
;; 30,000 unvested options return to company pool
;; Employee keeps 20,000 vested options
```

## 🛠️ Development & Testing

### Prerequisites
- Clarinet CLI installed
- Stacks blockchain node (for deployment)

### Testing
```bash
# Run contract checks
clarinet check

# Run test suite
clarinet test

# Console testing
clarinet console
```

### Deployment
```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

## 📄 License

This smart contract is provided as-is for educational and development purposes. Ensure proper legal review before using in production.

## 🤝 Contributing

Contributions are welcome! Please ensure all changes maintain backward compatibility and include appropriate tests.

## ⚠️ Disclaimer

This contract handles valuable assets. Always perform thorough testing and auditing before mainnet deployment. Consider legal and tax implications of tokenized equity in your jurisdiction.

