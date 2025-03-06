;; Charity Donation Platform V2
;; Enhanced Donation Tracking with Multiple Causes

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u2))
(define-constant ERR-CAMPAIGN-CLOSED (err u3))
(define-constant ERR-INVALID-DONATION (err u4))
(define-constant ERR-CAUSE-LIMIT-EXCEEDED (err u5))

;; Define support distribution methods
(define-constant DISTRIBUTION-METHODS 
  (list 
    "equal-split" 
    "proportional" 
    "creator-choice"
  )
)

;; Storage for multi-cause donation campaigns
(define-map donation-campaigns
  { campaign-id: uint }
  {
    creator: principal,
    campaign-name: (string-ascii 100),
    causes: (list 5 { 
      name: (string-ascii 100), 
      goal-amount: uint 
    }),
    distribution-method: (string-ascii 20),
    current-amounts: (list 5 uint),
    is-active: bool,
    total-goal: uint
  }
)

;; Track donations per cause
(define-map cause-donations
  { campaign-id: uint, cause-index: uint }
  { 
    donors: (list 10 principal),
    donation-amounts: (list 10 uint)
  }
)

;; Track next campaign ID
(define-data-var next-campaign-id uint u0)

;; Read-only function to get campaign details
(define-read-only (get-campaign (campaign-id uint))
  (map-get? donation-campaigns { campaign-id: campaign-id })
)

;; Create a new multi-cause donation campaign
(define-public (create-campaign 
  (campaign-name (string-ascii 100))
  (causes (list 5 { 
    name: (string-ascii 100), 
    goal-amount: uint 
  }))
  (distribution-method (string-ascii 20))
)
  (let 
    (
      (campaign-id (var-get next-campaign-id))
      (total-goal (fold + (map .get-goal-amount causes) u0))
    )
    ;; Validate distribution method
    (asserts! 
      (is-some (index-of DISTRIBUTION-METHODS distribution-method)) 
      ERR-INVALID-DONATION
    )
    
    (map-set donation-campaigns 
      { campaign-id: campaign-id }
      {
        creator: tx-sender,
        campaign-name: campaign-name,
        causes: causes,
        distribution-method: distribution-method,
        current-amounts: (list u0 u0 u0 u0 u0),
        is-active: true,
        total-goal: total-goal
      }
    )
    
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

;; Helper function to get goal amount
(define-read-only (get-goal-amount (cause { name: (string-ascii 100), goal-amount: uint }))
  (get goal-amount cause)
)

;; Donate to a specific campaign and cause
(define-public (donate 
  (campaign-id uint) 
  (cause-index uint)
  (amount uint)
)
  (let 
    (
      (campaign (unwrap! 
        (get-campaign campaign-id) 
        ERR-CAMPAIGN-NOT-FOUND
      ))
      (current-amounts (get current-amounts campaign))
    )
    ;; Validate campaign is active
    (asserts! (get is-active campaign) ERR-CAMPAIGN-CLOSED)
    
    ;; Transfer donation
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update campaign and cause amounts
    (map-set donation-campaigns 
      { campaign-id: campaign-id }
      (merge campaign { 
        current-amounts: (unwrap! 
          (replace-at current-amounts cause-index 
            (+ (unwrap! (element-at current-amounts cause-index) u0) amount)
          ) 
          ERR-CAUSE-LIMIT-EXCEEDED
        )
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