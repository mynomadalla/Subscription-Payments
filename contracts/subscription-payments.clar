(define-constant ERR_NOT_AUTHORIZED (err u101))
(define-constant ERR_SUBSCRIPTION_NOT_FOUND (err u102))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_PAYMENT_TOO_EARLY (err u105))
(define-constant ERR_SUBSCRIPTION_ALREADY_EXISTS (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_INVALID_INTERVAL (err u108))
(define-constant ERR_SUBSCRIPTION_PAUSED (err u109))
(define-constant ERR_SUBSCRIPTION_NOT_PAUSED (err u110))
(define-constant ERR_IN_GRACE_PERIOD (err u111))
(define-constant ERR_GRACE_PERIOD_EXPIRED (err u112))
(define-constant ERR_TIER_NOT_FOUND (err u113))
(define-constant ERR_TIER_ALREADY_EXISTS (err u114))
(define-constant ERR_INVALID_TIER_PRICE (err u115))
(define-constant ERR_SAME_TIER (err u116))

(define-data-var contract-owner principal tx-sender)
(define-data-var subscription-counter uint u0)
(define-data-var default-grace-period uint u432)

(define-map subscriptions
  { subscription-id: uint }
  {
    provider: principal,
    subscriber: principal,
    amount: uint,
    interval: uint,
    created-at: uint,
    last-payment: uint,
    next-payment: uint,
    is-active: bool,
    total-payments: uint,
    is-paused: bool,
    paused-at: uint,
    total-pause-time: uint,
    in-grace-period: bool,
    grace-period-start: uint,
    grace-period-end: uint,
    failed-payment-attempts: uint
  }
)

(define-map user-subscriptions
  { user: principal, provider: principal }
  { subscription-id: uint }
)

(define-map provider-subscriptions
  { provider: principal }
  { subscription-ids: (list 100 uint) }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map subscription-tiers
  { provider: principal, tier-id: uint }
  {
    name: (string-ascii 50),
    price: uint,
    created-at: uint
  }
)

(define-map provider-tier-counter
  { provider: principal }
  { counter: uint }
)

(define-map subscription-tier-mapping
  { subscription-id: uint }
  { tier-id: uint }
)

(define-private (get-next-subscription-id)
  (begin
    (var-set subscription-counter (+ (var-get subscription-counter) u1))
    (var-get subscription-counter)
  )
)

(define-private (get-next-tier-id (provider principal))
  (let ((current-counter (default-to u0 (get counter (map-get? provider-tier-counter { provider: provider })))))
    (let ((next-id (+ current-counter u1)))
      (map-set provider-tier-counter { provider: provider } { counter: next-id })
      next-id
    )
  )
)

(define-read-only (get-subscription (subscription-id uint))
  (map-get? subscriptions { subscription-id: subscription-id })
)

(define-read-only (get-user-subscription (user principal) (provider principal))
  (match (map-get? user-subscriptions { user: user, provider: provider })
    entry (get-subscription (get subscription-id entry))
    none
  )
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-block-height)
  stacks-block-height
)

(define-read-only (get-tier (provider principal) (tier-id uint))
  (map-get? subscription-tiers { provider: provider, tier-id: tier-id })
)

(define-read-only (get-subscription-tier (subscription-id uint))
  (match (map-get? subscription-tier-mapping { subscription-id: subscription-id })
    tier-mapping (get tier-id tier-mapping)
    u0
  )
)

(define-read-only (is-payment-due (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription 
      (and 
        (get is-active subscription)
        (not (get is-paused subscription))
        (>= stacks-block-height (get next-payment subscription))
      )
    false
  )
)

(define-read-only (is-subscription-paused (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription (get is-paused subscription)
    false
  )
)

(define-public (deposit (amount uint))
  (let ((current-balance (get-user-balance tx-sender)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances 
      { user: tx-sender }
      { balance: (+ current-balance amount) }
    )
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (let ((current-balance (get-user-balance tx-sender)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set user-balances
      { user: tx-sender }
      { balance: (- current-balance amount) }
    )
    (ok amount)
  )
)

(define-public (create-tier (tier-name (string-ascii 50)) (tier-price uint))
  (let ((tier-id (get-next-tier-id tx-sender)))
    (asserts! (> tier-price u0) ERR_INVALID_TIER_PRICE)
    (map-set subscription-tiers
      { provider: tx-sender, tier-id: tier-id }
      {
        name: tier-name,
        price: tier-price,
        created-at: stacks-block-height
      }
    )
    (ok tier-id)
  )
)

(define-public (change-subscription-tier (subscription-id uint) (new-tier-id uint))
  (match (get-subscription subscription-id)
    subscription
      (let (
        (provider (get provider subscription))
        (subscriber (get subscriber subscription))
        (current-amount (get amount subscription))
        (current-tier-id (get-subscription-tier subscription-id))
      )
        (asserts! (is-eq tx-sender subscriber) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active subscription) ERR_SUBSCRIPTION_EXPIRED)
        (asserts! (not (is-eq current-tier-id new-tier-id)) ERR_SAME_TIER)

        (match (get-tier provider new-tier-id)
          new-tier
            (let ((new-price (get price new-tier)))
              (map-set subscriptions
                { subscription-id: subscription-id }
                (merge subscription { amount: new-price })
              )
              (map-set subscription-tier-mapping
                { subscription-id: subscription-id }
                { tier-id: new-tier-id }
              )
              (ok new-price)
            )
          ERR_TIER_NOT_FOUND
        )
      )
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-public (create-subscription (provider principal) (amount uint) (interval uint))
  (let (
    (subscription-id (get-next-subscription-id))
    (current-time stacks-block-height)
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> interval u0) ERR_INVALID_INTERVAL)
    (asserts! (is-none (map-get? user-subscriptions { user: tx-sender, provider: provider }))
              ERR_SUBSCRIPTION_ALREADY_EXISTS)

    (map-set subscriptions
      { subscription-id: subscription-id }
      {
        provider: provider,
        subscriber: tx-sender,
        amount: amount,
        interval: interval,
        created-at: current-time,
        last-payment: u0,
        next-payment: (+ current-time interval),
        is-active: true,
        total-payments: u0,
        is-paused: false,
        paused-at: u0,
        total-pause-time: u0,
        in-grace-period: false,
        grace-period-start: u0,
        grace-period-end: u0,
        failed-payment-attempts: u0
      }
    )

    (map-set user-subscriptions
      { user: tx-sender, provider: provider }
      { subscription-id: subscription-id }
    )

    (let ((current-provider-subs (default-to (list)
            (get subscription-ids (map-get? provider-subscriptions { provider: provider })))))
      (map-set provider-subscriptions
        { provider: provider }
        { subscription-ids: (unwrap! (as-max-len? (append current-provider-subs subscription-id) u100)
                                    ERR_SUBSCRIPTION_ALREADY_EXISTS) }
      )
    )

    (map-set subscription-tier-mapping
      { subscription-id: subscription-id }
      { tier-id: u0 }
    )

    (ok subscription-id)
  )
)

(define-public (process-payment (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (let (
        (subscriber (get subscriber subscription))
        (provider (get provider subscription))
        (amount (get amount subscription))
        (interval (get interval subscription))
        (subscriber-balance (get-user-balance subscriber))
        (provider-balance (get-user-balance provider))
        (grace-period (var-get default-grace-period))
      )
        (asserts! (get is-active subscription) ERR_SUBSCRIPTION_EXPIRED)
        (asserts! (not (get is-paused subscription)) ERR_SUBSCRIPTION_PAUSED)
        (asserts! (>= stacks-block-height (get next-payment subscription)) ERR_PAYMENT_TOO_EARLY)
        
        (if (>= subscriber-balance amount)
          (begin
            (map-set user-balances
              { user: subscriber }
              { balance: (- subscriber-balance amount) }
            )
            
            (map-set user-balances
              { user: provider }
              { balance: (+ provider-balance amount) }
            )
            
            (map-set subscriptions
              { subscription-id: subscription-id }
              (merge subscription {
                last-payment: stacks-block-height,
                next-payment: (+ stacks-block-height interval),
                total-payments: (+ (get total-payments subscription) u1),
                in-grace-period: false,
                grace-period-start: u0,
                grace-period-end: u0,
                failed-payment-attempts: u0
              })
            )
            
            (ok amount)
          )
          (begin
            (map-set subscriptions
              { subscription-id: subscription-id }
              (merge subscription {
                in-grace-period: true,
                grace-period-start: stacks-block-height,
                grace-period-end: (+ stacks-block-height grace-period),
                failed-payment-attempts: (+ (get failed-payment-attempts subscription) u1)
              })
            )
            
            ERR_INSUFFICIENT_BALANCE
          )
        )
      )
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-public (cancel-subscription (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (begin
        (asserts! (or (is-eq tx-sender (get subscriber subscription))
                     (is-eq tx-sender (get provider subscription)))
                 ERR_NOT_AUTHORIZED)
        
        (map-set subscriptions
          { subscription-id: subscription-id }
          (merge subscription { is-active: false })
        )
        
        (ok true)
      )
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-public (pause-subscription (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (begin
        (asserts! (is-eq tx-sender (get subscriber subscription)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active subscription) ERR_SUBSCRIPTION_EXPIRED)
        (asserts! (not (get is-paused subscription)) ERR_SUBSCRIPTION_PAUSED)
        
        (map-set subscriptions
          { subscription-id: subscription-id }
          (merge subscription {
            is-paused: true,
            paused-at: stacks-block-height
          })
        )
        
        (ok true)
      )
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-public (resume-subscription (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (let (
        (pause-duration (- stacks-block-height (get paused-at subscription)))
        (new-total-pause (+ (get total-pause-time subscription) pause-duration))
        (adjusted-next-payment (+ (get next-payment subscription) pause-duration))
      )
        (asserts! (is-eq tx-sender (get subscriber subscription)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active subscription) ERR_SUBSCRIPTION_EXPIRED)
        (asserts! (get is-paused subscription) ERR_SUBSCRIPTION_NOT_PAUSED)
        
        (map-set subscriptions
          { subscription-id: subscription-id }
          (merge subscription {
            is-paused: false,
            paused-at: u0,
            total-pause-time: new-total-pause,
            next-payment: adjusted-next-payment
          })
        )
        
        (ok true)
      )
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-public (retry-payment (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (let (
        (subscriber (get subscriber subscription))
        (provider (get provider subscription))
        (amount (get amount subscription))
        (interval (get interval subscription))
        (subscriber-balance (get-user-balance subscriber))
        (provider-balance (get-user-balance provider))
      )
        (asserts! (get is-active subscription) ERR_SUBSCRIPTION_EXPIRED)
        (asserts! (get in-grace-period subscription) ERR_NOT_AUTHORIZED)
        (asserts! (<= stacks-block-height (get grace-period-end subscription)) ERR_GRACE_PERIOD_EXPIRED)
        (asserts! (>= subscriber-balance amount) ERR_INSUFFICIENT_BALANCE)
        
        (map-set user-balances
          { user: subscriber }
          { balance: (- subscriber-balance amount) }
        )
        
        (map-set user-balances
          { user: provider }
          { balance: (+ provider-balance amount) }
        )
        
        (map-set subscriptions
          { subscription-id: subscription-id }
          (merge subscription {
            last-payment: stacks-block-height,
            next-payment: (+ stacks-block-height interval),
            total-payments: (+ (get total-payments subscription) u1),
            in-grace-period: false,
            grace-period-start: u0,
            grace-period-end: u0,
            failed-payment-attempts: u0
          })
        )
        
        (ok amount)
      )
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-public (expire-subscription (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (begin
        (asserts! (get in-grace-period subscription) ERR_NOT_AUTHORIZED)
        (asserts! (> stacks-block-height (get grace-period-end subscription)) ERR_IN_GRACE_PERIOD)
        
        (map-set subscriptions
          { subscription-id: subscription-id }
          (merge subscription {
            is-active: false,
            in-grace-period: false
          })
        )
        
        (ok true)
      )
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-read-only (is-in-grace-period (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription 
      (and 
        (get in-grace-period subscription)
        (<= stacks-block-height (get grace-period-end subscription))
      )
    false
  )
)

(define-read-only (get-grace-period-remaining (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (if (is-in-grace-period subscription-id)
        (- (get grace-period-end subscription) stacks-block-height)
        u0
      )
    u0
  )
)

(define-public (set-grace-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (var-set default-grace-period new-period)
    (ok new-period)
  )
)

(define-public (batch-process-payments (subscription-ids (list 20 uint)))
  (let ((results (map process-payment subscription-ids)))
    (ok results)
  )
)

(define-read-only (get-subscription-status (subscription-id uint))
  (match (get-subscription subscription-id)
    subscription
      (ok {
        is-active: (get is-active subscription),
        is-paused: (get is-paused subscription),
        in-grace-period: (is-in-grace-period subscription-id),
        payment-due: (is-payment-due subscription-id),
        next-payment: (get next-payment subscription),
        total-payments: (get total-payments subscription),
        total-pause-time: (get total-pause-time subscription),
        failed-payment-attempts: (get failed-payment-attempts subscription),
        grace-period-remaining: (get-grace-period-remaining subscription-id),
        time-until-next: (if (>= stacks-block-height (get next-payment subscription))
                           u0
                           (- (get next-payment subscription) stacks-block-height))
      })
    ERR_SUBSCRIPTION_NOT_FOUND
  )
)

(define-read-only (get-provider-stats (provider principal))
  (let ((subscription-list (default-to (list) 
          (get subscription-ids (map-get? provider-subscriptions { provider: provider })))))
    (ok {
      total-subscriptions: (len subscription-list),
      provider-balance: (get-user-balance provider)
    })
  )
)

(define-public (emergency-cancel-all (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (let ((subscription-list (default-to (list) 
            (get subscription-ids (map-get? provider-subscriptions { provider: provider })))))
      (map cancel-subscription subscription-list)
      (ok true)
    )
  )
)
