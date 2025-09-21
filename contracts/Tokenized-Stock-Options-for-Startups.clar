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

(define-public (register-company (name (string-ascii 64)) (symbol (string-ascii 10)) (total-shares uint))
  (let
    (
      (company-id (+ (get-company-counter) u1))
      (current-block stacks-block-height)
    )
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
    )
    (asserts! (is-company-admin tx-sender company-id) err-owner-only)
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

