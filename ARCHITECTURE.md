# Subscription Tier Management - Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SUBSCRIPTION TIER SYSTEM                      │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                      PROVIDER OPERATIONS                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  create-tier(name, price)                                        │
│  ├─ Validates: price > 0                                         │
│  ├─ Generates: unique tier-id per provider                       │
│  ├─ Stores: tier definition in subscription-tiers map            │
│  └─ Returns: tier-id                                             │
│                                                                   │
│  Example: (create-tier "Pro" u2500) → tier-id u2                │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    SUBSCRIBER OPERATIONS                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  change-subscription-tier(subscription-id, new-tier-id)          │
│  ├─ Validates: caller is subscriber                              │
│  ├─ Validates: subscription is active                            │
│  ├─ Validates: new tier ≠ current tier                           │
│  ├─ Validates: tier exists for provider                          │
│  ├─ Updates: subscription amount to new tier price               │
│  ├─ Records: tier change in subscription-tier-mapping            │
│  └─ Returns: new-price                                           │
│                                                                   │
│  Example: (change-subscription-tier 42 u2) → ok u2500           │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                      QUERY OPERATIONS                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  get-tier(provider, tier-id)                                     │
│  └─ Returns: {name, price, created-at} or none                   │
│                                                                   │
│  get-subscription-tier(subscription-id)                          │
│  └─ Returns: current tier-id for subscription                    │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                      DATA STRUCTURES                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  subscription-tiers                                              │
│  ├─ Key: {provider, tier-id}                                     │
│  └─ Value: {name, price, created-at}                             │
│                                                                   │
│  provider-tier-counter                                           │
│  ├─ Key: {provider}                                              │
│  └─ Value: {counter}                                             │
│                                                                   │
│  subscription-tier-mapping                                       │
│  ├─ Key: {subscription-id}                                       │
│  └─ Value: {tier-id}                                             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    WORKFLOW EXAMPLE                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Provider creates tiers:                                      │
│     (create-tier "Basic" u1000)    → tier-id u1                  │
│     (create-tier "Pro" u2500)      → tier-id u2                  │
│     (create-tier "Enterprise" u5000) → tier-id u3                │
│                                                                   │
│  2. Subscriber creates subscription:                             │
│     (create-subscription provider u1000 u144)                    │
│     → subscription-id u42                                        │
│     → tier-id u0 (default)                                       │
│                                                                   │
│  3. Subscriber upgrades to Pro:                                  │
│     (change-subscription-tier 42 u2)                             │
│     → Updates amount to u2500                                    │
│     → Records tier-id u2                                         │
│     → Returns ok u2500                                           │
│                                                                   │
│  4. Next payment uses new tier price:                            │
│     (process-payment 42)                                         │
│     → Deducts u2500 (not u1000)                                  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING                                 │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ERR_TIER_NOT_FOUND (u113)                                       │
│  └─ Tier doesn't exist for provider                              │
│                                                                   │
│  ERR_INVALID_TIER_PRICE (u115)                                   │
│  └─ Tier price must be > 0                                       │
│                                                                   │
│  ERR_SAME_TIER (u116)                                            │
│  └─ Cannot switch to current tier                                │
│                                                                   │
│  ERR_NOT_AUTHORIZED                                              │
│  └─ Only subscriber can change tier                              │
│                                                                   │
│  ERR_SUBSCRIPTION_EXPIRED                                        │
│  └─ Cannot change tier on inactive subscription                  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    INTEGRATION POINTS                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ✓ Works with: create-subscription                               │
│    └─ Initializes tier mapping                                   │
│                                                                   │
│  ✓ Works with: process-payment                                   │
│    └─ Uses current tier price                                    │
│                                                                   │
│  ✓ Works with: pause-subscription                                │
│    └─ Tier preserved during pause                                │
│                                                                   │
│  ✓ Works with: resume-subscription                               │
│    └─ Tier preserved during resume                               │
│                                                                   │
│  ✓ Works with: cancel-subscription                               │
│    └─ Tier mapping cleaned up                                    │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    SECURITY MODEL                                 │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Authorization:                                                  │
│  ├─ create-tier: Only caller (provider)                          │
│  └─ change-subscription-tier: Only subscriber                    │
│                                                                   │
│  Validation:                                                     │
│  ├─ Price: Must be positive                                      │
│  ├─ Tier: Must exist                                             │
│  ├─ Subscription: Must be active                                 │
│  └─ Tier: Must be different from current                         │
│                                                                   │
│  State Protection:                                               │
│  ├─ Atomic updates                                               │
│  ├─ No partial state changes                                     │
│  └─ Consistent data across maps                                  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
Provider                          Contract                      Subscriber
   │                                 │                              │
   ├─ create-tier("Pro", 2500) ─────>│                              │
   │                                 ├─ Validate price              │
   │                                 ├─ Generate tier-id            │
   │                                 ├─ Store in subscription-tiers  │
   │                                 ├─ Return tier-id u2           │
   │<─────────────────────────────────┤                              │
   │                                 │                              │
   │                                 │<─ change-subscription-tier ──┤
   │                                 │   (sub-id 42, tier-id u2)    │
   │                                 ├─ Validate subscriber         │
   │                                 ├─ Validate subscription       │
   │                                 ├─ Validate tier exists        │
   │                                 ├─ Update amount to 2500       │
   │                                 ├─ Record tier mapping         │
   │                                 ├─ Return ok 2500             │
   │                                 ├──────────────────────────────>│
   │                                 │                              │
   │                                 │<─ process-payment(42) ───────┤
   │                                 ├─ Get subscription            │
   │                                 ├─ Get current tier price      │
   │                                 ├─ Deduct 2500 from balance    │
   │                                 ├─ Add 2500 to provider        │
   │                                 ├─ Return ok 2500             │
   │<────────────────────────────────┤                              │
   │                                 │                              │
```

## State Transition Diagram

```
Subscription States with Tier Management:

                    ┌─────────────────┐
                    │   CREATED       │
                    │  (tier-id: u0)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   ACTIVE        │
                    │  (tier-id: u0)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ TIER CHANGED    │
                    │  (tier-id: u2)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   PAUSED        │
                    │  (tier-id: u2)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   RESUMED       │
                    │  (tier-id: u2)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   CANCELLED     │
                    │  (tier-id: u2)  │
                    └─────────────────┘

Tier changes can occur at any ACTIVE state
```

## Performance Characteristics

```
Operation                    Time Complexity    Space Complexity
─────────────────────────────────────────────────────────────────
create-tier                  O(1)               O(1)
change-subscription-tier     O(1)               O(1)
get-tier                     O(1)               O(1)
get-subscription-tier        O(1)               O(1)
process-payment (with tier)  O(1)               O(1)

Total Storage:
- subscription-tiers: O(P × T) where P=providers, T=tiers per provider
- provider-tier-counter: O(P)
- subscription-tier-mapping: O(S) where S=subscriptions
```

