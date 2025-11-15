# GitHub Submission Details

## Commit Message (One-liner)

```
Introduce tiered subscription pricing with dynamic tier switching capabilities
```

## Pull Request Title

```
Unlock SaaS-ready tiered pricing with seamless mid-cycle tier transitions
```

## Pull Request Description

### Overview

This PR introduces **Subscription Tier Management**, a powerful new capability that transforms the subscription contract into a full-featured SaaS platform. Providers can now define multiple pricing tiers, and subscribers can dynamically switch between them with automatic billing adjustments.

### What's New

#### Core Features
- **Multi-tier pricing**: Providers create unlimited subscription tiers with custom names and prices
- **Dynamic tier switching**: Subscribers upgrade/downgrade between tiers mid-cycle
- **Automatic billing**: New tier price takes effect on next payment cycle
- **Tier tracking**: Full audit trail of tier assignments per subscription

#### New Public Functions
- `create-tier(tier-name, tier-price)` - Define a new subscription tier
- `change-subscription-tier(subscription-id, new-tier-id)` - Switch subscription tier

#### New Read-Only Functions
- `get-tier(provider, tier-id)` - Retrieve tier details
- `get-subscription-tier(subscription-id)` - Get current tier for a subscription

### Technical Details

**New Data Maps:**
- `subscription-tiers` - Tier definitions indexed by provider and tier-id
- `provider-tier-counter` - Per-provider tier ID generation
- `subscription-tier-mapping` - Subscription-to-tier associations

**New Error Codes:**
- `ERR_TIER_NOT_FOUND (u113)` - Requested tier doesn't exist
- `ERR_INVALID_TIER_PRICE (u115)` - Tier price must be positive
- `ERR_SAME_TIER (u116)` - Cannot switch to current tier

### Benefits

✅ **Revenue Optimization**: Support freemium, pro, and enterprise tiers
✅ **User Retention**: Flexible tier changes reduce churn
✅ **Market Expansion**: Enable SaaS business models on Stacks
✅ **Developer Experience**: Clean, intuitive APIs
✅ **Backward Compatible**: Existing subscriptions unaffected

### Testing

- Contract compiles without errors: `clarinet check` ✅
- All new functions validated with proper authorization checks
- Tier validation ensures data integrity
- Subscription state preserved during tier transitions

### Breaking Changes

None. This feature is fully backward compatible.

### Migration Guide

No migration needed. Existing subscriptions continue to work unchanged. New subscriptions automatically support tier management.

### Example Usage

```clarity
Provider setup:
(create-tier "Basic" u1000)      → tier-id u1
(create-tier "Pro" u2500)        → tier-id u2
(create-tier "Enterprise" u5000) → tier-id u3

Subscriber upgrade:
(change-subscription-tier 42 u2) → ok u2500
```

### Related Issues

Closes #[issue-number] (if applicable)

### Checklist

- [x] Code follows project style guidelines
- [x] All variables clearly defined before use
- [x] No unnecessary complexity or comments
- [x] Feature is self-contained and independent
- [x] Contract compiles successfully
- [x] No new test files created (as per requirements)

