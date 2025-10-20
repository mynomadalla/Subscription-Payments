# Subscription Tier Management Feature

## Feature Overview

**Subscription Tier Management with Dynamic Pricing** enables providers to create multiple subscription tiers with different pricing levels. Subscribers can seamlessly upgrade or downgrade between tiers, with the system automatically adjusting payment amounts for the next billing cycle.

## Value Proposition

- **Provider Revenue**: Unlock tiered pricing models (Basic, Pro, Enterprise) to capture different market segments
- **Subscriber Flexibility**: Allow mid-cycle tier changes without friction or complex prorating logic
- **SaaS Enablement**: Support modern subscription business models with multiple service levels
- **Developer Experience**: Simple, intuitive APIs for tier creation and management

## Implementation Details

### New Error Constants

```clarity
(define-constant ERR_TIER_NOT_FOUND (err u113))
(define-constant ERR_TIER_ALREADY_EXISTS (err u114))
(define-constant ERR_INVALID_TIER_PRICE (err u115))
(define-constant ERR_SAME_TIER (err u116))
```

### New Data Structures

**subscription-tiers**: Stores tier definitions per provider
- Key: { provider, tier-id }
- Value: { name, price, created-at }

**provider-tier-counter**: Tracks tier ID generation per provider
- Key: { provider }
- Value: { counter }

**subscription-tier-mapping**: Links subscriptions to their current tier
- Key: { subscription-id }
- Value: { tier-id }

### New Functions

#### create-tier (Public)
Creates a new subscription tier for the caller (provider).

**Parameters:**
- tier-name: (string-ascii 50) - Display name for the tier
- tier-price: uint - Price in microSTX

**Returns:** ok tier-id on success

**Validations:**
- tier-price must be greater than 0

#### change-subscription-tier (Public)
Allows a subscriber to change their subscription to a different tier.

**Parameters:**
- subscription-id: uint - The subscription to modify
- new-tier-id: uint - The target tier ID

**Returns:** ok new-price on success

**Validations:**
- Caller must be the subscriber
- Subscription must be active
- New tier must be different from current tier
- Tier must exist for the provider

**Behavior:**
- Updates subscription amount to new tier price
- Records tier change in subscription-tier-mapping
- Takes effect on next payment cycle

#### get-tier (Read-Only)
Retrieves tier details.

**Parameters:**
- provider: principal
- tier-id: uint

**Returns:** Tier data or none

#### get-subscription-tier (Read-Only)
Gets the current tier ID for a subscription.

**Parameters:**
- subscription-id: uint

**Returns:** tier-id (u0 if not set)

### Integration Points

**create-subscription** updated to:
- Initialize subscription-tier-mapping with tier-id u0 for new subscriptions

## Compilation Status

✅ Contract compiles successfully with `clarinet check`
✅ No compilation errors
✅ 12 pre-existing warnings (unrelated to new feature)

## Usage Example

```clarity
Provider creates Basic tier:
(create-tier "Basic" u1000)
→ Returns tier-id u1

Provider creates Pro tier:
(create-tier "Pro" u2500)
→ Returns tier-id u2

Subscriber upgrades from Basic to Pro:
(change-subscription-tier subscription-id u2)
→ Returns ok u2500 (new price)
```

## Feature Characteristics

- **Self-contained**: No dependencies on other features
- **Backward compatible**: Existing subscriptions work unchanged
- **Extensible**: Supports unlimited tiers per provider
- **Secure**: Authorization checks ensure only subscribers can change their tier
- **Efficient**: O(1) lookups for tier and subscription data

