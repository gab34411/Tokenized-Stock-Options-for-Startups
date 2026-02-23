(define-non-fungible-token stock-option uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-company (err u102))
(define-constant err-already-vested (err u103))
(define-constant err-not-vested (err u104))
(define-constant err-already-exercised (err u105))
(define-constant err-invalid-token (err u106))
(define-constant err-transfer-not-allowed (err u107))
(define-constant err-pool-exhausted (err u108))
(define-constant err-invalid-pool-size (err u109))
(define-constant err-already-accelerated (err u110))
(define-constant err-invalid-percentage (err u111))
(define-constant err-already-forfeited (err u112))

(define-data-var last-token-id uint u0)

(define-map companies
  { company-id: uint }
  {
    name: (string-ascii 64),
    symbol: (string-ascii 10),
    total-shares: uint,
    admin: principal,
    created-at: uint
  }
)

(define-map company-counter { dummy: bool } { value: uint })

(define-map option-pools
  { company-id: uint }
  {
    total-allocation: uint,
    allocated: uint,
    reserved: uint,
    last-updated: uint
  })

(define-map option-details
  { token-id: uint }
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
)

(define-map company-admins
  { admin: principal, company-id: uint }
  { authorized: bool }
)

(define-map vested-amounts
  { token-id: uint }
  { amount: uint }
)

(define-map company-valuations
  { company-id: uint, timestamp: uint }
  {
    share-price: uint,
    total-valuation: uint,
    updated-by: principal,
    volatility: uint
  }
)

(define-map current-market-prices
  { company-id: uint }
  {
    current-price: uint,
    last-updated: uint,
    updated-by: principal
  }
)

(define-map option-fair-values
  { token-id: uint }
  {
    black-scholes-value: uint,
    intrinsic-value: uint,
    time-value: uint,
    calculated-at: uint
  }
)

(define-map vesting-accelerations
  { token-id: uint }
  {
    acceleration-percentage: uint,
    reason: (string-ascii 64),
    accelerated-by: principal,
    accelerated-at: uint
  }
)

(define-map option-forfeitures
  { token-id: uint }
  {
    forfeited-shares: uint,
    reclaimed-shares: uint,
    reason: (string-ascii 64),
    forfeited-by: principal,
    forfeited-at: uint
  }
)

(define-public (register-company (name (string-ascii 64)) (symbol (string-ascii 10)) (total-shares uint) (option-pool-allocation uint))
  (let
    (
      (company-id (+ (get-company-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (<= option-pool-allocation total-shares) err-invalid-pool-size)
    (map-set company-counter { dummy: true } { value: company-id })
    (map-set companies
      { company-id: company-id }
      {
        name: name,
        symbol: symbol,
        total-shares: total-shares,
        admin: tx-sender,
        created-at: current-block
      }
    )
    (map-set company-admins
      { admin: tx-sender, company-id: company-id }
      { authorized: true }
    )
    (map-set option-pools
      { company-id: company-id }
      {
        total-allocation: option-pool-allocation,
        allocated: u0,
        reserved: u0,
        last-updated: current-block
      }
    )
    (ok company-id)
  )
)

(define-public (issue-option 
  (company-id uint)
  (recipient principal)
  (shares uint)
  (strike-price uint)
  (vesting-cliff uint)
  (vesting-duration uint)
  )
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (current-block stacks-block-height)
      (company (unwrap! (map-get? companies { company-id: company-id }) err-invalid-company))
      (pool (unwrap! (map-get? option-pools { company-id: company-id }) err-invalid-company))
      (new-allocated (+ (get allocated pool) shares))
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (asserts! (<= new-allocated (get total-allocation pool)) err-pool-exhausted)
    (try! (nft-mint? stock-option token-id recipient))
    (var-set last-token-id token-id)
    (map-set option-details
      { token-id: token-id }
      {
        company-id: company-id,
        holder: recipient,
        shares: shares,
        strike-price: strike-price,
        vesting-start: current-block,
        vesting-cliff: vesting-cliff,
        vesting-duration: vesting-duration,
        exercised: false,
        created-at: current-block
      }
    )
    (map-set option-pools
      { company-id: company-id }
      (merge pool { allocated: new-allocated, last-updated: current-block })
    )
    (ok token-id)
  )
)

(define-public (transfer-option (token-id uint) (sender principal) (recipient principal))
  (let
    (
      (option (unwrap! (map-get? option-details { token-id: token-id }) err-invalid-token))
    )
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (asserts! (is-eq (get holder option) sender) err-not-token-owner)
    (asserts! (not (get exercised option)) err-already-exercised)
    (try! (nft-transfer? stock-option token-id sender recipient))
    (map-set option-details
      { token-id: token-id }
      (merge option { holder: recipient })
    )
    (ok true)
  )
)

(define-public (exercise-option (token-id uint))
  (let
    (
      (option (unwrap! (map-get? option-details { token-id: token-id }) err-invalid-token))
      (vested-amount (get-vested-amount token-id))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get holder option)) err-not-token-owner)
    (asserts! (> vested-amount u0) err-not-vested)
    (asserts! (not (get exercised option)) err-already-exercised)
    (map-set option-details
      { token-id: token-id }
      (merge option { exercised: true })
    )
    (map-set vested-amounts
      { token-id: token-id }
      { amount: vested-amount }
    )
    (ok vested-amount)
  )
)

(define-public (add-company-admin (company-id uint) (admin principal))
  (begin
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (map-set company-admins
      { admin: admin, company-id: company-id }
      { authorized: true }
    )
    (ok true)
  )
)

(define-public (remove-company-admin (company-id uint) (admin principal))
  (begin
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (map-delete company-admins { admin: admin, company-id: company-id })
    (ok true)
  )
)

(define-public (update-market-price (company-id uint) (new-price uint) (volatility uint))
  (let
    (
      (current-block stacks-block-height)
      (company (unwrap! (map-get? companies { company-id: company-id }) err-invalid-company))
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (map-set current-market-prices
      { company-id: company-id }
      {
        current-price: new-price,
        last-updated: current-block,
        updated-by: tx-sender
      }
    )
    (map-set company-valuations
      { company-id: company-id, timestamp: current-block }
      {
        share-price: new-price,
        total-valuation: (* new-price (get total-shares company)),
        updated-by: tx-sender,
        volatility: volatility
      }
    )
    (ok true)
  )
)

(define-public (calculate-option-fair-value (token-id uint))
  (let
    (
      (option (unwrap! (map-get? option-details { token-id: token-id }) err-invalid-token))
      (market-price-data (unwrap! (map-get? current-market-prices { company-id: (get company-id option) }) err-invalid-company))
      (current-price (get current-price market-price-data))
      (strike-price (get strike-price option))
      (current-block stacks-block-height)
      (intrinsic (if (> current-price strike-price) (- current-price strike-price) u0))
      (time-to-expiry (if (> (+ (get vesting-start option) (get vesting-duration option)) current-block)
                        (- (+ (get vesting-start option) (get vesting-duration option)) current-block)
                        u1))
      (time-value (/ (* intrinsic time-to-expiry) u100))
      (fair-value (+ intrinsic time-value))
    )
    (map-set option-fair-values
      { token-id: token-id }
      {
        black-scholes-value: fair-value,
        intrinsic-value: intrinsic,
        time-value: time-value,
        calculated-at: current-block
      }
    )
    (ok fair-value)
  )
)

(define-public (accelerate-vesting (token-id uint) (acceleration-percentage uint) (reason (string-ascii 64)))
  (let
    (
      (option (unwrap! (map-get? option-details { token-id: token-id }) err-invalid-token))
      (company-id (get company-id option))
      (current-block stacks-block-height)
      (existing-acceleration (map-get? vesting-accelerations { token-id: token-id }))
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (asserts! (is-none existing-acceleration) err-already-accelerated)
    (asserts! (and (> acceleration-percentage u0) (<= acceleration-percentage u100)) err-invalid-percentage)
    (asserts! (not (get exercised option)) err-already-exercised)
    (map-set vesting-accelerations
      { token-id: token-id }
      {
        acceleration-percentage: acceleration-percentage,
        reason: reason,
        accelerated-by: tx-sender,
        accelerated-at: current-block
      }
    )
    (ok true)
  )
)

(define-read-only (get-vesting-acceleration (token-id uint))
  (map-get? vesting-accelerations { token-id: token-id })
)

(define-read-only (get-accelerated-vested-amount (token-id uint))
  (let
    (
      (base-vested (get-vested-amount token-id))
      (option (unwrap! (map-get? option-details { token-id: token-id }) u0))
      (total-shares (get shares option))
      (acceleration (map-get? vesting-accelerations { token-id: token-id }))
    )
    (match acceleration
      accel
        (let
          (
            (acceleration-pct (get acceleration-percentage accel))
            (accelerated-shares (/ (* total-shares acceleration-pct) u100))
            (combined (+ base-vested accelerated-shares))
          )
          (if (> combined total-shares)
            total-shares
            combined
          )
        )
      base-vested
    )
  )
)

(define-read-only (get-company-counter)
  (default-to u0 (get value (map-get? company-counter { dummy: true })))
)

(define-read-only (get-company (company-id uint))
  (map-get? companies { company-id: company-id })
)

(define-read-only (get-option-details (token-id uint))
  (map-get? option-details { token-id: token-id })
)

(define-read-only (get-vested-amount (token-id uint))
  (let
    (
      (option (unwrap! (map-get? option-details { token-id: token-id }) u0))
      (current-block stacks-block-height)
      (vesting-start (get vesting-start option))
      (vesting-cliff (get vesting-cliff option))
      (vesting-duration (get vesting-duration option))
      (total-shares (get shares option))
      (cliff-block (+ vesting-start vesting-cliff))
      (full-vesting-block (+ vesting-start vesting-duration))
    )
    (if (< current-block cliff-block)
      u0
      (if (>= current-block full-vesting-block)
        total-shares
        (/ (* total-shares (- current-block vesting-start)) vesting-duration)
      )
    )
  )
)

(define-read-only (is-company-admin (admin principal) (company-id uint))
  (default-to false (get authorized (map-get? company-admins { admin: admin, company-id: company-id })))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stock-option token-id))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://tokenized-equity.com/metadata/{id}.json"))
)

(define-read-only (get-total-supply)
  (ok (var-get last-token-id))
)

(define-read-only (get-market-price (company-id uint))
  (map-get? current-market-prices { company-id: company-id })
)

(define-read-only (get-company-valuation (company-id uint) (timestamp uint))
  (map-get? company-valuations { company-id: company-id, timestamp: timestamp })
)

(define-read-only (get-option-fair-value (token-id uint))
  (map-get? option-fair-values { token-id: token-id })
)

(define-read-only (get-option-pool (company-id uint))
  (map-get? option-pools { company-id: company-id })
)

(define-public (reserve-option-shares (company-id uint) (shares uint))
  (let
    (
      (current-block stacks-block-height)
      (pool (unwrap! (map-get? option-pools { company-id: company-id }) err-invalid-company))
      (total-committed (+ (get allocated pool) (get reserved pool) shares))
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (asserts! (<= total-committed (get total-allocation pool)) err-pool-exhausted)
    (map-set option-pools
      { company-id: company-id }
      (merge pool { reserved: (+ (get reserved pool) shares), last-updated: current-block })
    )
    (ok true)
  )
)

(define-public (release-option-reserve (company-id uint) (shares uint))
  (let
    (
      (current-block stacks-block-height)
      (pool (unwrap! (map-get? option-pools { company-id: company-id }) err-invalid-company))
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (asserts! (>= (get reserved pool) shares) err-invalid-pool-size)
    (map-set option-pools
      { company-id: company-id }
      (merge pool { reserved: (- (get reserved pool) shares), last-updated: current-block })
    )
    (ok true)
  )
)

(define-public (update-option-pool-allocation (company-id uint) (new-allocation uint))
  (let
    (
      (current-block stacks-block-height)
      (pool (unwrap! (map-get? option-pools { company-id: company-id }) err-invalid-company))
      (company (unwrap! (map-get? companies { company-id: company-id }) err-invalid-company))
      (current-usage (+ (get allocated pool) (get reserved pool)))
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (asserts! (>= new-allocation current-usage) err-invalid-pool-size)
    (asserts! (<= new-allocation (get total-shares company)) err-invalid-pool-size)
    (map-set option-pools
      { company-id: company-id }
      (merge pool { total-allocation: new-allocation, last-updated: current-block })
    )
    (ok true)
  )
)

(define-public (forfeit-option (token-id uint) (reason (string-ascii 64)))
  (let
    (
      (option (unwrap! (map-get? option-details { token-id: token-id }) err-invalid-token))
      (company-id (get company-id option))
      (current-block stacks-block-height)
      (pool (unwrap! (map-get? option-pools { company-id: company-id }) err-invalid-company))
      (total-shares (get shares option))
      (vested (get-accelerated-vested-amount token-id))
      (unvested (- total-shares vested))
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
    (asserts! (not (get exercised option)) err-already-exercised)
    (asserts! (is-none (map-get? option-forfeitures { token-id: token-id })) err-already-forfeited)
    (map-set option-details
      { token-id: token-id }
      (merge option { exercised: true, shares: vested })
    )
    (map-set option-pools
      { company-id: company-id }
      (merge pool {
        allocated: (- (get allocated pool) unvested),
        last-updated: current-block
      })
    )
    (map-set option-forfeitures
      { token-id: token-id }
      {
        forfeited-shares: total-shares,
        reclaimed-shares: unvested,
        reason: reason,
        forfeited-by: tx-sender,
        forfeited-at: current-block
      }
    )
    (ok { vested: vested, forfeited: unvested })
  )
)

(define-read-only (get-option-forfeiture (token-id uint))
  (map-get? option-forfeitures { token-id: token-id })
)

(define-read-only (is-option-forfeited (token-id uint))
  (is-some (map-get? option-forfeitures { token-id: token-id }))
)

(define-read-only (get-option-intrinsic-value (token-id uint))
  (let
    (
      (option (unwrap! (map-get? option-details { token-id: token-id }) u0))
      (market-price-data (map-get? current-market-prices { company-id: (get company-id option) }))
    )
    (match market-price-data
      price-data
        (let
          (
            (current-price (get current-price price-data))
            (strike-price (get strike-price option))
          )
          (if (> current-price strike-price)
            (- current-price strike-price)
            u0
          )
        )
      u0
    )
  )
)

(define-read-only (get-portfolio-value (holder principal))
  (let
    (
      (token-count (var-get last-token-id))
    )
    (fold calculate-holder-portfolio-value
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
      { holder: holder, total-value: u0, current-token: u1 }
    )
  )
)

(define-private (calculate-holder-portfolio-value 
  (token-id uint)
  (acc { holder: principal, total-value: uint, current-token: uint })
  )
  (let
    (
      (option-data (map-get? option-details { token-id: (get current-token acc) }))
      (next-token (+ (get current-token acc) u1))
    )
    (match option-data
      option
        (if (is-eq (get holder option) (get holder acc))
          {
            holder: (get holder acc),
            total-value: (+ (get total-value acc) (get-option-intrinsic-value (get current-token acc))),
            current-token: next-token
          }
          {
            holder: (get holder acc),
            total-value: (get total-value acc),
            current-token: next-token
          }
        )
      {
        holder: (get holder acc),
        total-value: (get total-value acc),
        current-token: next-token
      }
    )
  )
)

