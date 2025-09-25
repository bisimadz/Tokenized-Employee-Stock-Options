(define-fungible-token company-equity)
(define-non-fungible-token stock-option-grant uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-grant-not-found (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-cliff (err u105))
(define-constant err-invalid-vesting (err u106))
(define-constant err-nothing-vested (err u107))
(define-constant err-already-claimed (err u108))
(define-constant err-not-vested (err u109))
(define-constant err-invalid-amount (err u110))
(define-constant err-employee-exists (err u111))
(define-constant err-company-not-found (err u112))
(define-constant err-exercise-expired (err u113))
(define-constant err-invalid-price (err u114))

(define-constant blocks-per-month u4320)
(define-constant blocks-per-year u52560)
(define-constant max-vesting-period u210240)
(define-constant max-cliff-period u52560)

(define-data-var grant-id-nonce uint u1)
(define-data-var total-shares-outstanding uint u0)
(define-data-var company-valuation uint u0)

(define-map stock-grants uint {
    employee: principal,
    total-amount: uint,
    vested-amount: uint,
    claimed-amount: uint,
    grant-date: uint,
    cliff-duration: uint,
    vesting-duration: uint,
    vesting-start: uint,
    exercise-price: uint,
    is-active: bool,
    is-terminated: bool
})

(define-map employee-grants principal {
    grant-ids: (list 20 uint),
    total-granted: uint,
    total-vested: uint,
    total-exercised: uint
})

(define-map company-info { dummy: bool } {
    name: (string-ascii 50),
    total-shares: uint,
    shares-allocated: uint,
    shares-available: uint,
    employee-count: uint
})

(define-map vesting-schedules uint {
    grant-id: uint,
    monthly-vesting: uint,
    acceleration-eligible: bool,
    performance-multiplier: uint
})

(define-map exercise-history uint {
    grant-id: uint,
    employee: principal,
    amount-exercised: uint,
    exercise-date: uint,
    price-paid: uint
})

(define-map employee-profiles principal {
    start-date: uint,
    department: (string-ascii 30),
    role: (string-ascii 50),
    performance-rating: uint,
    is-active: bool
})

(define-public (initialize-company
    (name (string-ascii 50))
    (total-shares uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> total-shares u0) err-invalid-amount)
    (map-set company-info { dummy: true } {
        name: name,
        total-shares: total-shares,
        shares-allocated: u0,
        shares-available: total-shares,
        employee-count: u0
    })
    (try! (ft-mint? company-equity total-shares contract-owner))
    (var-set total-shares-outstanding total-shares)
    (ok true)))

(define-public (grant-options
    (employee principal)
    (amount uint)
    (cliff-months uint)
    (vesting-months uint)
    (exercise-price uint))
  (let (
    (grant-id (var-get grant-id-nonce))
    (cliff-blocks (* cliff-months blocks-per-month))
    (vesting-blocks (* vesting-months blocks-per-month))
    (company (unwrap! (map-get? company-info { dummy: true }) err-company-not-found)))
    
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= cliff-blocks max-cliff-period) err-invalid-cliff)
    (asserts! (<= vesting-blocks max-vesting-period) err-invalid-vesting)
    (asserts! (>= vesting-blocks cliff-blocks) err-invalid-vesting)
    (asserts! (<= amount (get shares-available company)) err-insufficient-balance)
    
    (try! (nft-mint? stock-option-grant grant-id employee))
    
    (map-set stock-grants grant-id {
        employee: employee,
        total-amount: amount,
        vested-amount: u0,
        claimed-amount: u0,
        grant-date: stacks-block-height,
        cliff-duration: cliff-blocks,
        vesting-duration: vesting-blocks,
        vesting-start: (+ stacks-block-height cliff-blocks),
        exercise-price: exercise-price,
        is-active: true,
        is-terminated: false
    })
    
    (map-set vesting-schedules grant-id {
        grant-id: grant-id,
        monthly-vesting: (/ amount vesting-months),
        acceleration-eligible: false,
        performance-multiplier: u100
    })
    
    (let ((employee-data (default-to 
            { grant-ids: (list), total-granted: u0, total-vested: u0, total-exercised: u0 }
            (map-get? employee-grants employee))))
        (map-set employee-grants employee {
            grant-ids: (unwrap! (as-max-len? (append (get grant-ids employee-data) grant-id) u20) err-already-exists),
            total-granted: (+ (get total-granted employee-data) amount),
            total-vested: (get total-vested employee-data),
            total-exercised: (get total-exercised employee-data)
        }))
    
    (map-set company-info { dummy: true }
        (merge company {
            shares-allocated: (+ (get shares-allocated company) amount),
            shares-available: (- (get shares-available company) amount),
            employee-count: (+ (get employee-count company) u1)
        }))
    
    (var-set grant-id-nonce (+ grant-id u1))
    (ok grant-id)))

(define-public (calculate-vested (grant-id uint))
  (let (
    (grant (unwrap! (map-get? stock-grants grant-id) err-grant-not-found))
    (current-block stacks-block-height)
    (grant-start (get grant-date grant))
    (cliff-end (+ grant-start (get cliff-duration grant)))
    (vesting-end (+ grant-start (get vesting-duration grant))))
    
    (if (< current-block cliff-end)
        (ok u0)
        (if (>= current-block vesting-end)
            (ok (get total-amount grant))
            (let (
                (elapsed-blocks (- current-block cliff-end))
                (total-vesting-blocks (- vesting-end cliff-end))
                (vested-amount (/ (* (get total-amount grant) elapsed-blocks) total-vesting-blocks)))
                (ok vested-amount))))))

(define-public (claim-vested (grant-id uint))
  (let (
    (grant (unwrap! (map-get? stock-grants grant-id) err-grant-not-found))
    (vested-amount (unwrap! (calculate-vested grant-id) err-nothing-vested))
    (claimable (- vested-amount (get claimed-amount grant))))
    
    (asserts! (is-eq tx-sender (get employee grant)) err-not-authorized)
    (asserts! (get is-active grant) err-not-vested)
    (asserts! (> claimable u0) err-nothing-vested)
    
    (try! (ft-transfer? company-equity claimable contract-owner tx-sender))
    
    (map-set stock-grants grant-id
        (merge grant {
            vested-amount: vested-amount,
            claimed-amount: (+ (get claimed-amount grant) claimable)
        }))
    
    (let ((employee-data (unwrap! (map-get? employee-grants tx-sender) err-grant-not-found)))
        (map-set employee-grants tx-sender
            (merge employee-data {
                total-vested: (+ (get total-vested employee-data) claimable)
            })))
    
    (ok claimable)))

(define-public (exercise-options (grant-id uint) (amount uint))
  (let (
    (grant (unwrap! (map-get? stock-grants grant-id) err-grant-not-found))
    (vested-amount (unwrap! (calculate-vested grant-id) err-nothing-vested))
    (available (- vested-amount (get claimed-amount grant)))
    (exercise-cost (* amount (get exercise-price grant))))
    
    (asserts! (is-eq tx-sender (get employee grant)) err-not-authorized)
    (asserts! (get is-active grant) err-not-vested)
    (asserts! (<= amount available) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (stx-transfer? exercise-cost tx-sender contract-owner))
    (try! (ft-transfer? company-equity amount contract-owner tx-sender))
    
    (map-set stock-grants grant-id
        (merge grant {
            claimed-amount: (+ (get claimed-amount grant) amount)
        }))
    
    (map-set exercise-history (var-get grant-id-nonce) {
        grant-id: grant-id,
        employee: tx-sender,
        amount-exercised: amount,
        exercise-date: stacks-block-height,
        price-paid: exercise-cost
    })
    
    (let ((employee-data (unwrap! (map-get? employee-grants tx-sender) err-grant-not-found)))
        (map-set employee-grants tx-sender
            (merge employee-data {
                total-exercised: (+ (get total-exercised employee-data) amount)
            })))
    
    (ok amount)))

(define-public (terminate-grant (grant-id uint))
  (let ((grant (unwrap! (map-get? stock-grants grant-id) err-grant-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get is-active grant) err-already-claimed)
    
    (let (
        (vested-amount (unwrap! (calculate-vested grant-id) err-nothing-vested))
        (unvested (- (get total-amount grant) vested-amount))
        (company (unwrap! (map-get? company-info { dummy: true }) err-company-not-found)))
        
        (map-set stock-grants grant-id
            (merge grant {
                is-active: false,
                is-terminated: true,
                total-amount: vested-amount
            }))
        
        (map-set company-info { dummy: true }
            (merge company {
                shares-available: (+ (get shares-available company) unvested),
                shares-allocated: (- (get shares-allocated company) unvested)
            }))
        
        (ok unvested))))

(define-public (accelerate-vesting (grant-id uint))
  (let (
    (grant (unwrap! (map-get? stock-grants grant-id) err-grant-not-found))
    (schedule (unwrap! (map-get? vesting-schedules grant-id) err-grant-not-found)))
    
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get is-active grant) err-not-vested)
    
    (map-set stock-grants grant-id
        (merge grant {
            vesting-start: stacks-block-height,
            cliff-duration: u0
        }))
    
    (map-set vesting-schedules grant-id
        (merge schedule {
            acceleration-eligible: true
        }))
    
    (ok true)))

(define-public (update-valuation (new-valuation uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-valuation u0) err-invalid-amount)
    (var-set company-valuation new-valuation)
    (ok true)))

(define-public (add-employee-profile
    (employee principal)
    (department (string-ascii 30))
    (role (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? employee-profiles employee)) err-employee-exists)
    
    (map-set employee-profiles employee {
        start-date: stacks-block-height,
        department: department,
        role: role,
        performance-rating: u100,
        is-active: true
    })
    (ok true)))

(define-read-only (get-grant-details (grant-id uint))
  (map-get? stock-grants grant-id))

(define-read-only (get-employee-grants (employee principal))
  (map-get? employee-grants employee))

(define-read-only (get-company-info)
  (map-get? company-info { dummy: true }))

(define-read-only (get-vesting-schedule (grant-id uint))
  (map-get? vesting-schedules grant-id))

(define-read-only (get-employee-profile (employee principal))
  (map-get? employee-profiles employee))

(define-read-only (get-current-valuation)
  (ok (var-get company-valuation)))

(define-read-only (get-vested-amount (grant-id uint))
  (calculate-vested grant-id))

(define-read-only (get-claimable-amount (grant-id uint))
  (let ((grant-opt (map-get? stock-grants grant-id)))
    (if (is-some grant-opt)
      (let ((grant (unwrap-panic grant-opt)))
        (match (calculate-vested grant-id)
          vested (ok (- vested (get claimed-amount grant)))
          error (err err-grant-not-found)))
      (err err-grant-not-found))))

(define-read-only (get-total-shares)
  (ok (var-get total-shares-outstanding)))

