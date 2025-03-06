;; Charity Donation Platform V1
;; Basic Donation Tracking Contract

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u2))
(define-constant ERR-CAMPAIGN-CLOSED (err u3))
(define-constant ERR-INVALID-DONATION (err u4))

;; Storage for donation campaigns
(define-map donation-campaigns
  { campaign-id: uint }
  {
    creator: principal,
    cause: (string-ascii 100),
    goal-amount: uint,
    current-amount: uint,
    is-active: bool
  }
)

;; Track next campaign ID
(define-data-var next-campaign-id uint u0)

;; Read-only function to get campaign details
(define-read-only (get-campaign (campaign-id uint))
  (map-get? donation-campaigns { campaign-id: campaign-id })
)

;; Create a new donation campaign
(define-public (create-campaign 
  (cause (string-ascii 100)) 
  (goal-amount uint)
)
  (let 
    (
      (campaign-id (var-get next-campaign-id))
    )
    (map-set donation-campaigns 
      { campaign-id: campaign-id }
      {
        creator: tx-sender,
        cause: cause,
        goal-amount: goal-amount,
        current-amount: u0,
        is-active: true
      }
    )
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

;; Donate to a specific campaign
(define-public (donate 
  (campaign-id uint) 
  (amount uint)
)
  (let 
    (
      (campaign (unwrap! 
        (get-campaign campaign-id) 
        ERR-CAMPAIGN-NOT-FOUND
      ))
    )
    ;; Validate campaign is active
    (asserts! (get is-active campaign) ERR-CAMPAIGN-CLOSED)
    
    ;; Transfer donation
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update campaign amount
    (map-set donation-campaigns 
      { campaign-id: campaign-id }
      (merge campaign { 
        current-amount: (+ (get current-amount campaign) amount) 
      })
    )
    
    (ok true)
  )
)

;; Close a campaign (only by creator)
(define-public (close-campaign (campaign-id uint))
  (let 
    (
      (campaign (unwrap! 
        (get-campaign campaign-id) 
        ERR-CAMPAIGN-NOT-FOUND
      ))
    )
    ;; Ensure only creator can close
    (asserts! (is-eq tx-sender (get creator campaign)) ERR-UNAUTHORIZED)
    
    (map-set donation-campaigns 
      { campaign-id: campaign-id }
      (merge campaign { is-active: false })
    )
    
    (ok true)
  )
)

;; Initialize contract
(begin
  (var-set next-campaign-id u0)
)