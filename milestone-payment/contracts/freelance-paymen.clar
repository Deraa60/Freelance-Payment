;; Service Agreement Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant agreement-state-payment-pending u0)
(define-constant agreement-state-in-progress u1)
(define-constant agreement-state-completed u2)
(define-constant agreement-state-cancelled u3)
(define-constant agreement-state-disputed u4)

;; Error constants
(define-constant ERROR_ACCESS_DENIED (err u100))
(define-constant ERROR_INVALID_AGREEMENT_STATE (err u101))
(define-constant ERROR_PAYMENT_TOO_LOW (err u102))
(define-constant ERROR_DUPLICATE_AGREEMENT (err u103))
(define-constant ERROR_AGREEMENT_MISSING (err u104))
(define-constant ERROR_INVALID_MILESTONE_NUMBER (err u105))
(define-constant ERROR_INVALID_PARAMETERS (err u106))
(define-constant ERROR_INVALID_PROVIDER_ADDRESS (err u107))
(define-constant ERROR_INVALID_MILESTONE_STRUCTURE (err u108))

;; Data structures
(define-map agreement-records
    { agreement-id: uint }
    {
        provider-address: principal,
        customer-address: principal,
        total-price: uint,
        current-state: uint,
        start-block-height: uint,
        end-block-height: uint,
        dispute-deadline-block: uint,
        delivery-milestones: (list 5 {
            milestone-title: (string-utf8 100),
            milestone-cost: uint,
            milestone-status: bool
        })
    }
)

(define-map payment-escrow-records
    { agreement-id: uint }
    { locked-amount: uint }
)

(define-map dispute-records
    { agreement-id: uint }
    {
        dispute-description: (string-utf8 200),
        dispute-creator: principal,
        resolution-details: (optional (string-utf8 200))
    }
)

;; Read-only functions
(define-read-only (get-agreement-record (agreement-id uint))
    (map-get? agreement-records { agreement-id: agreement-id })
)

(define-read-only (get-escrow-balance (agreement-id uint))
    (default-to { locked-amount: u0 }
        (map-get? payment-escrow-records { agreement-id: agreement-id })
    )
)

(define-read-only (get-dispute-record (agreement-id uint))
    (map-get? dispute-records { agreement-id: agreement-id })
)

;; Private functions
(define-private (verify-authorized-party (agreement-id uint))
    (let ((agreement-data (unwrap! (get-agreement-record agreement-id) false)))
        (or
            (is-eq tx-sender contract-owner)
            (is-eq tx-sender (get provider-address agreement-data))
            (is-eq tx-sender (get customer-address agreement-data))
        )
    )
)

(define-private (is-milestone-complete? (milestone {
    milestone-title: (string-utf8 100),
    milestone-cost: uint,
    milestone-status: bool
}))
    (get milestone-status milestone))

(define-private (verify-all-milestones-delivered (delivery-milestones (list 5 {
        milestone-title: (string-utf8 100),
        milestone-cost: uint,
        milestone-status: bool
    })))
    (and
        (is-milestone-complete? (unwrap-panic (element-at delivery-milestones u0)))
        (is-milestone-complete? (unwrap-panic (element-at delivery-milestones u1)))
        (is-milestone-complete? (unwrap-panic (element-at delivery-milestones u2)))
        (is-milestone-complete? (unwrap-panic (element-at delivery-milestones u3)))
        (is-milestone-complete? (unwrap-panic (element-at delivery-milestones u4)))
    )
)

(define-private (validate-provider-eligibility (provider-candidate principal))
    (and 
        (not (is-eq provider-candidate tx-sender))
        (not (is-eq provider-candidate contract-owner))
        (not (is-eq provider-candidate (as-contract tx-sender)))
    )
)

(define-private (validate-milestone-structure (milestones (list 5 {
        milestone-title: (string-utf8 100),
        milestone-cost: uint,
        milestone-status: bool
    })) 
    (total-price uint))
    (let ((total-milestone-costs (+ 
            (get milestone-cost (unwrap-panic (element-at milestones u0)))
            (get milestone-cost (unwrap-panic (element-at milestones u1)))
            (get milestone-cost (unwrap-panic (element-at milestones u2)))
            (get milestone-cost (unwrap-panic (element-at milestones u3)))
            (get milestone-cost (unwrap-panic (element-at milestones u4)))
        )))
        (and 
            (is-eq total-milestone-costs total-price)
            (> (len (get milestone-title (unwrap-panic (element-at milestones u0)))) u0)
            (> (len (get milestone-title (unwrap-panic (element-at milestones u1)))) u0)
            (> (len (get milestone-title (unwrap-panic (element-at milestones u2)))) u0)
            (> (len (get milestone-title (unwrap-panic (element-at milestones u3)))) u0)
            (> (len (get milestone-title (unwrap-panic (element-at milestones u4)))) u0)
        )
    )
)

(define-private (update-milestone-completion-status 
    (milestone {
        milestone-title: (string-utf8 100),
        milestone-cost: uint,
        milestone-status: bool
    })
    (target-milestone-index uint)
    (current-index uint))
    {
        milestone-title: (get milestone-title milestone),
        milestone-cost: (get milestone-cost milestone),
        milestone-status: (if (is-eq current-index target-milestone-index) 
                               true 
                               (get milestone-status milestone))
    }
)

;; Public functions
(define-public (create-agreement (agreement-id uint) 
                               (provider-address principal)
                               (total-price uint)
                               (duration-blocks uint)
                               (delivery-milestones (list 5 {
                                   milestone-title: (string-utf8 100),
                                   milestone-cost: uint,
                                   milestone-status: bool
                               })))
    (let ((current-block block-height))
        (asserts! (is-none (get-agreement-record agreement-id)) ERROR_DUPLICATE_AGREEMENT)
        (asserts! (> total-price u0) ERROR_PAYMENT_TOO_LOW)
        (asserts! (> duration-blocks u0) ERROR_INVALID_PARAMETERS)
        (asserts! (validate-provider-eligibility provider-address) ERROR_INVALID_PROVIDER_ADDRESS)
        (asserts! (validate-milestone-structure delivery-milestones total-price) ERROR_INVALID_MILESTONE_STRUCTURE)
        
        (map-set agreement-records
            { agreement-id: agreement-id }
            {
                provider-address: provider-address,
                customer-address: tx-sender,
                total-price: total-price,
                current-state: agreement-state-payment-pending,
                start-block-height: current-block,
                end-block-height: (+ current-block duration-blocks),
                dispute-deadline-block: (+ (+ current-block duration-blocks) u144),
                delivery-milestones: delivery-milestones
            }
        )
        
        (map-set payment-escrow-records
            { agreement-id: agreement-id }
            { locked-amount: u0 }
        )
        
        (ok true)
    )
)

(define-public (submit-payment (agreement-id uint) (payment-amount uint))
    (let ((agreement-data (unwrap! (get-agreement-record agreement-id) ERROR_AGREEMENT_MISSING))
          (current-balance (get locked-amount (get-escrow-balance agreement-id))))
        
        (asserts! (is-eq tx-sender (get customer-address agreement-data)) ERROR_ACCESS_DENIED)
        (asserts! (is-eq (get current-state agreement-data) agreement-state-payment-pending) ERROR_INVALID_AGREEMENT_STATE)
        (asserts! (> payment-amount u0) ERROR_INVALID_PARAMETERS)
        
        (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
        
        (let ((new-balance (+ current-balance payment-amount)))
            (map-set payment-escrow-records
                { agreement-id: agreement-id }
                { locked-amount: new-balance }
            )
            
            (if (>= new-balance (get total-price agreement-data))
                (map-set agreement-records
                    { agreement-id: agreement-id }
                    (merge agreement-data { current-state: agreement-state-in-progress })
                )
                true
            )
            
            (ok true)
        )
    )
)

(define-public (complete-milestone (agreement-id uint) (milestone-index uint))
    (let ((agreement-data (unwrap! (get-agreement-record agreement-id) ERROR_AGREEMENT_MISSING)))
        (asserts! (is-eq tx-sender (get provider-address agreement-data)) ERROR_ACCESS_DENIED)
        (asserts! (is-eq (get current-state agreement-data) agreement-state-in-progress) ERROR_INVALID_AGREEMENT_STATE)
        (asserts! (< milestone-index (len (get delivery-milestones agreement-data))) ERROR_INVALID_MILESTONE_NUMBER)
        
        (let ((milestones (get delivery-milestones agreement-data))
              (updated-milestones 
                (list 
                    (update-milestone-completion-status (unwrap-panic (element-at milestones u0)) milestone-index u0)
                    (update-milestone-completion-status (unwrap-panic (element-at milestones u1)) milestone-index u1)
                    (update-milestone-completion-status (unwrap-panic (element-at milestones u2)) milestone-index u2)
                    (update-milestone-completion-status (unwrap-panic (element-at milestones u3)) milestone-index u3)
                    (update-milestone-completion-status (unwrap-panic (element-at milestones u4)) milestone-index u4)
                )))
            
            (map-set agreement-records
                { agreement-id: agreement-id }
                (merge agreement-data { delivery-milestones: updated-milestones })
            )
            
            (if (verify-all-milestones-delivered updated-milestones)
                (map-set agreement-records
                    { agreement-id: agreement-id }
                    (merge agreement-data { 
                        current-state: agreement-state-completed,
                        delivery-milestones: updated-milestones 
                    })
                )
                true
            )
            
            (ok true)
        )
    )
)

(define-public (release-payment (agreement-id uint))
    (let ((agreement-data (unwrap! (get-agreement-record agreement-id) ERROR_AGREEMENT_MISSING))
          (escrow-data (get-escrow-balance agreement-id)))
        
        (asserts! (is-eq tx-sender (get customer-address agreement-data)) ERROR_ACCESS_DENIED)
        (asserts! (is-eq (get current-state agreement-data) agreement-state-completed) ERROR_INVALID_AGREEMENT_STATE)
        
        (try! (as-contract (stx-transfer? 
            (get locked-amount escrow-data)
            (as-contract tx-sender)
            (get provider-address agreement-data)
        )))
        
        (map-set payment-escrow-records
            { agreement-id: agreement-id }
            { locked-amount: u0 }
        )
        
        (ok true)
    )
)

(define-public (file-dispute (agreement-id uint) (dispute-description (string-utf8 200)))
    (let ((agreement-data (unwrap! (get-agreement-record agreement-id) ERROR_AGREEMENT_MISSING)))
        (asserts! (verify-authorized-party agreement-id) ERROR_ACCESS_DENIED)
        (asserts! (< block-height (get dispute-deadline-block agreement-data)) ERROR_INVALID_AGREEMENT_STATE)
        (asserts! (> (len dispute-description) u0) ERROR_INVALID_PARAMETERS)
        
        (map-set dispute-records
            { agreement-id: agreement-id }
            {
                dispute-description: dispute-description,
                dispute-creator: tx-sender,
                resolution-details: none
            }
        )
        
        (map-set agreement-records
            { agreement-id: agreement-id }
            (merge agreement-data { current-state: agreement-state-disputed })
        )
        
        (ok true)
    )
)

(define-public (resolve-dispute (agreement-id uint) 
                              (resolution-text (string-utf8 200))
                              (customer-refund-percent uint))
    (let ((agreement-data (unwrap! (get-agreement-record agreement-id) ERROR_AGREEMENT_MISSING))
          (escrow-data (get-escrow-balance agreement-id)))
        
        (asserts! (is-eq tx-sender contract-owner) ERROR_ACCESS_DENIED)
        (asserts! (is-eq (get current-state agreement-data) agreement-state-disputed) ERROR_INVALID_AGREEMENT_STATE)
        (asserts! (<= customer-refund-percent u100) ERROR_INVALID_PARAMETERS)
        (asserts! (> (len resolution-text) u0) ERROR_INVALID_PARAMETERS)
        
        (let ((refund-amount (/ (* (get locked-amount escrow-data) customer-refund-percent) u100))
              (provider-amount (- (get locked-amount escrow-data) refund-amount)))
            
            ;; Process customer refund
            (if (> refund-amount u0)
                (try! (as-contract (stx-transfer? 
                    refund-amount
                    (as-contract tx-sender)
                    (get customer-address agreement-data)
                )))
                true
            )
            
            ;; Process provider payment
            (if (> provider-amount u0)
                (try! (as-contract (stx-transfer? 
                    provider-amount
                    (as-contract tx-sender)
                    (get provider-address agreement-data)
                )))
                true
            )
            
            ;; Update dispute resolution
            (let ((dispute-data (unwrap! (get-dispute-record agreement-id) ERROR_AGREEMENT_MISSING)))
                (map-set dispute-records
                    { agreement-id: agreement-id }
                    (merge dispute-data { resolution-details: (some resolution-text) })
                )
            )
            
            ;; Clear escrow and update status
            (map-set payment-escrow-records
                { agreement-id: agreement-id }
                { locked-amount: u0 }
            )
            
            (map-set agreement-records
                { agreement-id: agreement-id }
                (merge agreement-data { current-state: agreement-state-completed })
            )
            
            (ok true)
        )
    )
)

(define-public (cancel-agreement (agreement-id uint))
    (let ((agreement-data (unwrap! (get-agreement-record agreement-id) ERROR_AGREEMENT_MISSING))
          (escrow-data (get-escrow-balance agreement-id)))
        
        (asserts! (verify-authorized-party agreement-id) ERROR_ACCESS_DENIED)
        (asserts! (is-eq (get current-state agreement-data) agreement-state-payment-pending) ERROR_INVALID_AGREEMENT_STATE)
        
        ;; Return escrowed funds to customer
        (if (> (get locked-amount escrow-data) u0)
            (try! (as-contract (stx-transfer? 
                (get locked-amount escrow-data)
                (as-contract tx-sender)
                (get customer-address agreement-data)
            )))
            true
        )
        
        (map-set payment-escrow-records
            { agreement-id: agreement-id }
            { locked-amount: u0 }
        )
        
        (map-set agreement-records
            { agreement-id: agreement-id }
            (merge agreement-data { current-state: agreement-state-cancelled })
        )
        
        (ok true)
    )
)