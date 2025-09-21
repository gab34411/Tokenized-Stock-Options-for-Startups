# 🚀 Tokenized Stock Options for Startups

📈 **Democratizing Early-Stage Investment Through NFT-Based Equity Options**

## 📄 Overview

This smart contract revolutionizes startup equity distribution by creating NFTs that represent stock options with built-in vesting schedules. Each option NFT contains all the necessary metadata including company information, vesting parameters, strike prices, and exercise conditions.

### ✨ Key Features

- 🏢 **Company Registration**: Startups can register and manage their equity pools
- 💎 **NFT Stock Options**: Each option is a unique, transferable NFT
- ⏰ **Automated Vesting**: Block-height based vesting with cliff periods
- 🔐 **Access Control**: Multi-level admin permissions for company management
- 💱 **Exercise Mechanism**: Convert vested options into equity ownership
- 📊 **Transparent Tracking**: All option details and vesting progress on-chain

## 🛠️ Installation & Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js (for testing)

### Quick Start

```bash
# Clone the repository
git clone <your-repo-url>
cd Tokenized-Stock-Options-for-Startups

# Check contract syntax
clarinet check

# Run tests
npm install
npm test

# Start Clarinet console for interaction
clarinet console
```

## 🎯 Usage Examples

### 1. Register a Company

```clarity
;; Register TechCorp with 1M shares
(contract-call? .Tokenized-Stock-Options-for-Startups register-company "TechCorp" "TECH" u1000000)
;; Returns company-id: u1
```

### 2. Issue Stock Options

```clarity
;; Issue 1000 shares to employee with 4-year vesting, 1-year cliff
(contract-call? .Tokenized-Stock-Options-for-Startups issue-option 
  u1                    ;; company-id
  'SP1J2K...EMPLOYEE    ;; recipient
  u1000                 ;; shares
  u100                  ;; strike-price (in STX micros)
  u52560               ;; vesting-cliff (1 year in blocks)
  u210240)             ;; vesting-duration (4 years in blocks)
;; Returns token-id: u1
```

### 3. Check Vested Amount

```clarity
;; Check how many shares are currently vested
(contract-call? .Tokenized-Stock-Options-for-Startups get-vested-amount u1)
```

### 4. Exercise Options

```clarity
;; Exercise vested portion of options
(contract-call? .Tokenized-Stock-Options-for-Startups exercise-option u1)
;; Returns number of shares exercised
```

### 5. Transfer Options

```clarity
;; Transfer options to another address (if not yet exercised)
(contract-call? .Tokenized-Stock-Options-for-Startups transfer-option 
  u1                    ;; token-id
  tx-sender             ;; current owner
  'SP2K...NEW-OWNER)    ;; recipient
```

## 🔍 Function Reference

### Public Functions

#### `register-company`
**Parameters:**
- `name`: Company name (string-ascii 64)
- `symbol`: Company ticker symbol (string-ascii 10) 
- `total-shares`: Total share count (uint)

**Returns:** Company ID (uint)

#### `issue-option`
**Parameters:**
- `company-id`: Registered company ID (uint)
- `recipient`: Option holder address (principal)
- `shares`: Number of shares in option (uint)
- `strike-price`: Exercise price per share (uint)
- `vesting-cliff`: Cliff period in blocks (uint)
- `vesting-duration`: Total vesting period in blocks (uint)

**Returns:** Token ID (uint)

#### `exercise-option`
**Parameters:**
- `token-id`: Option NFT ID (uint)

**Returns:** Number of shares exercised (uint)

#### `transfer-option`
**Parameters:**
- `token-id`: Option NFT ID (uint)
- `sender`: Current owner (principal)
- `recipient`: New owner (principal)

**Returns:** Success (bool)

### Read-Only Functions

#### `get-company`
Returns company details by ID

#### `get-option-details`  
Returns complete option information

#### `get-vested-amount`
Calculates currently vested shares for an option

#### `get-owner`
Returns current owner of option NFT

#### `is-company-admin`
Checks admin permissions for company management

## 📊 Data Structures

### Company Record
```clarity
{
  name: (string-ascii 64),
  symbol: (string-ascii 10),
  total-shares: uint,
  admin: principal,
  created-at: uint
}
```

### Option Record
```clarity
{
  company-id: uint,
  holder: principal,
  shares: uint,
  strike-price: uint,
  vesting-start: uint,
  vesting-cliff: uint,
  vesting-duration: uint,
  exercised: bool,
  created-at: uint
}
```

## ⚡ Vesting Logic

The contract implements linear vesting with cliff periods:

- **Before Cliff**: 0 shares vested
- **After Cliff**: Linear vesting based on time elapsed
- **Full Vesting**: 100% of shares available after vesting duration

**Formula:**
```
vested_amount = (total_shares * (current_block - vesting_start)) / vesting_duration
```

## 🔒 Security Features

- **Owner Validation**: Only option holders can exercise their options
- **Admin Controls**: Company-specific admin permissions
- **Transfer Restrictions**: Cannot transfer exercised options
- **Vesting Enforcement**: Options cannot be exercised before vesting
- **Input Validation**: All parameters validated before execution

## 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test file
npm test -- --testNamePattern="Company Registration"
```

## 📈 Roadmap

- [ ] 🌐 Integration with external price oracles
- [ ] 💰 Support for multiple payment tokens
- [ ] 📋 Batch operations for large employee pools
- [ ] 📱 Web interface for easy management
- [ ] 🔄 Option buyback mechanisms
- [ ] 📊 Advanced analytics and reporting

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This contract is for educational and demonstration purposes. Always conduct thorough security audits before using in production environments. Equity distribution should comply with relevant securities regulations.

---

**Built with ❤️ for the decentralized startup ecosystem**
