# 💳 Subscription Payments Smart Contract

A Clarity smart contract that enables recurring subscription payments on the Stacks blockchain. Perfect for SaaS services, memberships, and any recurring billing needs! 🚀

## 🌟 Features

- 💰 **Recurring Payments**: Set up automatic subscription billing
- ⏰ **Time-based Processing**: Uses `stacks-block-height` for precise payment scheduling
- 👥 **Multi-party Support**: Subscribers and providers with separate balances
- 🔒 **Secure Deposits**: Safe STX deposit and withdrawal system
- 📊 **Payment Tracking**: Complete history and status monitoring
- ⚡ **Batch Processing**: Process multiple payments efficiently
- 🛡️ **Emergency Controls**: Admin functions for security

## 🏗️ Contract Architecture

### Core Components

- **Subscriptions**: Link subscribers to providers with payment terms
- **User Balances**: Internal balance tracking for efficient payments
- **Payment Processing**: Automated recurring payment execution
- **Status Management**: Real-time subscription state monitoring

## 🚀 Quick Start

### 1. Deploy the Contract

```bash
clarinet deploy
```

### 2. Deposit Funds

```clarity
(contract-call? .subscription-payments deposit u1000000) ;; 1 STX in microstacks
```

### 3. Create a Subscription

```clarity
(contract-call? .subscription-payments 
  create-subscription 
  'SP1ABCD...PROVIDER  ;; Provider address
  u500000              ;; 0.5 STX per payment
  u144                 ;; Every 144 blocks (~24 hours)
)
```

### 4. Process Payments

```clarity
(contract-call? .subscription-payments process-payment u1) ;; subscription-id
```

## 📋 API Reference

### 💸 Payment Functions

#### `deposit(amount: uint)`
Deposit STX into your contract balance for subscription payments.

**Parameters:**
- `amount`: Amount in microstacks to deposit

**Returns:** `(ok amount)` on success

#### `withdraw(amount: uint)`
Withdraw STX from your contract balance.

**Parameters:**
- `amount`: Amount in microstacks to withdraw

**Returns:** `(ok amount)` on success

### 📅 Subscription Management

#### `create-subscription(provider: principal, amount: uint, interval: uint)`
Create a new recurring subscription.

**Parameters:**
- `provider`: Principal address of the service provider
- `amount`: Payment amount per billing cycle (microstacks)
- `interval`: Payment interval in blocks

**Returns:** `(ok subscription-id)` on success

#### `process-payment(subscription-id: uint)`
Process a payment for an active subscription (if due).

**Parameters:**
- `subscription-id`: Unique identifier for the subscription

**Returns:** `(ok amount)` - amount transferred

#### `cancel-subscription(subscription-id: uint)`
Cancel an active subscription (subscriber or provider only).

**Parameters:**
- `subscription-id`: Subscription to cancel

**Returns:** `(ok true)` on success

### 📊 Query Functions

#### `get-subscription(subscription-id: uint)`
Get complete subscription details.

#### `get-user-subscription(user: principal, provider: principal)`
Get subscription between specific user and provider.

#### `get-user-balance(user: principal)`
Get user's contract balance.

#### `is-payment-due(subscription-id: uint)`
Check if a subscription payment is due.

#### `get-subscription-status(subscription-id: uint)`
Get detailed subscription status including payment timing.

#### `get-provider-stats(provider: principal)`
Get provider statistics and balance.

### ⚡ Batch Operations

#### `batch-process-payments(subscription-ids: (list 20 uint))`
Process multiple subscription payments in one transaction.

**Parameters:**
- `subscription-ids`: List of up to 20 subscription IDs

**Returns:** List of payment results

## 🎯 Usage Examples

### Creating a Monthly SaaS Subscription

```clarity
;; 1. User deposits 12 STX for a year of service
(contract-call? .subscription-payments deposit u12000000)

;; 2. Create monthly subscription (1 STX per month)
(contract-call? .subscription-payments 
  create-subscription 
  'SP1SAAS...PROVIDER 
  u1000000     ;; 1 STX per payment
  u4320        ;; ~30 days in blocks
)
```

### Processing Payments

```clarity
;; Check if payment is due
(contract-call? .subscription-payments is-payment-due u1)

;; Process the payment
(contract-call? .subscription-payments process-payment u1)

;; Check updated status
(contract-call? .subscription-payments get-subscription-status u1)
```

### Provider Dashboard

```clarity
;; Get provider statistics
(contract-call? .subscription-payments get-provider-stats tx-sender)

;; Process multiple customer payments
(contract-call? .subscription-payments 
  batch-process-payments 
  (list u1 u2 u3 u4 u5)
)
```

## ⏰ Time Management

The contract uses Stacks block heights for scheduling:

- **Block Time**: ~10 minutes average
- **Daily Payments**: ~144 blocks
- **Weekly Payments**: ~1008 blocks  
- **Monthly Payments**: ~4320 blocks

## 🔒 Security Features

- ✅ Balance validation before payments
- ✅ Authorization checks for cancellations
- ✅ Subscription existence validation
- ✅ Payment timing enforcement
- ✅ Emergency admin controls

## 🚨 Error Codes

| Code | Meaning |
|------|---------|
| `u101` | Not authorized |
| `u102` | Subscription not found |
| `u103` | Subscription expired |
| `u104` | Insufficient balance |
| `u105` | Payment too early |
| `u106` | Subscription already exists |
| `u107` | Invalid amount |
| `u108` | Invalid interval |

## 🧪 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new functionality
4. Submit a pull request

## 📄 License

MIT License - feel free to use in your projects!

---

Built with ❤️ for the Stacks ecosystem 🟠
