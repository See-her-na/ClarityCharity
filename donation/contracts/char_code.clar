;; Charity Donation Campaign Contract

;; Error Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-DOES-NOT-EXIST (err u102))
(define-constant ERR-CAMPAIGN-CLOSED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-ALREADY-SETTLED (err u105))
(define-constant ERR-CAMPAIGN-NOT-CLOSABLE (err u106))
(define-constant ERR-CAMPAIGN-NOT-CANCELABLE (err u107))
(define-constant ERR-INVALID-CAUSE-COUNT (err u108))
(define-constant ERR-INVALID-CLOSE-HEIGHT (err u109))
(define-constant ERR-INVALID-CAMPAIGN-TYPE (err u110))
(define-constant ERR-MISSING-DISTRIBUTION-PLAN (err u111))
(define-constant ERR-INVALID-CAUSE (err u112))
(define-constant ERR-CAMPAIGN-EXPIRED (err u113))
(define-constant ERR-NO-SELECTED-CAUSES (err u114))
(define-constant ERR-TOO-MANY-CAUSES (err u115))
(define-constant ERR-INVALID-SELECTED-CAUSE (err u116))
(define-constant ERR-NOT-A-BENEFICIARY (err u117))
(define-constant ERR-REFUND-FAILED (err u118))
(define-constant ERR-REFUND-PROCESSING (err u119))
(define-constant ERR-INVALID-DESCRIPTION (err u120))
(define-constant ERR-INVALID-DONATION-AMOUNT (err u121))

;; Data variables
(define-data-var next-donation-campaign-id uint u0)

;; Campaign types
(define-data-var campaign-types (list 10 (string-ascii 20)) (list "equal-split" "weighted" "milestone-based"))

;; Define campaign structure
(define-map donation-campaigns
  { donation-campaign-id: uint }
  {
    campaign-creator: principal,
    campaign-description: (string-ascii 256),
    charitable-causes: (list 10 (string-ascii 64)),
    total-donated-amount: uint,
    is-campaign-open: bool,
    selected-causes: (list 5 uint),
    campaign-close-height: uint,
    campaign-type: (string-ascii 20),
    distribution-weights: (optional (list 10 uint))
  }
)

;; Define donation structure
(define-map donations
  { donation-campaign-id: uint, donor: principal }
  { chosen-cause: uint, donated-amount: uint }
)

;; Read-only functions

(define-read-only (get-donation-campaign (donation-campaign-id uint))
  (map-get? donation-campaigns { donation-campaign-id: donation-campaign-id })
)

(define-read-only (get-donation (donation-campaign-id uint) (donor principal))
  (map-get? donations { donation-campaign-id: donation-campaign-id, donor: donor })
)

(define-read-only (get-current-block-height)
  block-height
)

;; Private functions

(define-private (calculate-distribution (campaign { campaign-creator: principal, campaign-description: (string-ascii 256), charitable-causes: (list 10 (string-ascii 64)), total-donated-amount: uint, is-campaign-open: bool, selected-causes: (list 5 uint), campaign-close-height: uint, campaign-type: (string-ascii 20), distribution-weights: (optional (list 10 uint)) }) (donation { chosen-cause: uint, donated-amount: uint }) (selected-cause-ids (list 5 uint)))
  (let
    (
      (campaign-type (get campaign-type campaign))
      (total-campaign-donation (get total-donated-amount campaign))
      (donor-donation (get donated-amount donation))
    )
    (if (is-eq campaign-type "equal-split")
      ;; For equal-split, divide total pot by number of selected causes
      (/ total-campaign-donation (len selected-cause-ids))
      (if (is-eq campaign-type "weighted")
        ;; For weighted, distribution based on predefined weights
        (let
          (
            (weights-list (unwrap! (get distribution-weights campaign) u0))
            (chosen-weight (unwrap! (element-at weights-list (- (get chosen-cause donation) u1)) u0))
          )
          (/ (* donor-donation total-campaign-donation) chosen-weight)
        )
        ;; Milestone-based distribution
        (/ (* donor-donation total-campaign-donation) (len selected-cause-ids))
      )
    )
  )
)

(define-private (get-donation-amount-for-cause-and-campaign (cause uint) (donation-campaign-id uint))
  (let
    (
      (donation (get-donation donation-campaign-id tx-sender))
    )
    (if (is-some donation)
      (let
        ((donation-data (unwrap! donation u0)))
        (if (is-eq (get chosen-cause donation-data) cause)
          (get donated-amount donation-data)
          u0
        )
      )
      u0
    )
  )
)

(define-private (get-cause-total-donated-amount (cause uint))
  (get-donation-amount-for-cause-and-campaign cause (var-get next-donation-campaign-id))
)

(define-private (process-refunds (donation-campaign-id uint))
  (let
    ((donation (get-donation donation-campaign-id tx-sender)))
    (match donation
      donation-data (match (as-contract (stx-transfer? (get donated-amount donation-data) tx-sender tx-sender))
        success (begin
          (map-delete donations { donation-campaign-id: donation-campaign-id, donor: tx-sender })
          (ok true)
        )
        error ERR-REFUND-FAILED
      )
      ERR-REFUND-PROCESSING
    )
  )
)

(define-private (validate-causes-helper (causes (list 5 uint)) (max-cause uint))
  (let
    (
      (cause-1 (element-at causes u0))
      (cause-2 (element-at causes u1))
      (cause-3 (element-at causes u2))
      (cause-4 (element-at causes u3))
      (cause-5 (element-at causes u4))
    )
    (and
      ;; Check if first cause exists and is valid
      (match cause-1
        value (and (> value u0) (<= value max-cause))
        true)
      ;; For remaining causes, they're either valid or none
      (match cause-2
        value (and (> value u0) (<= value max-cause))
        true)
      (match cause-3
        value (and (> value u0) (<= value max-cause))
        true)
      (match cause-4
        value (and (> value u0) (<= value max-cause))
        true)
      (match cause-5
        value (and (> value u0) (<= value max-cause))
        true)
    )
  )
)

;; Public functions

(define-public (create-donation-campaign (campaign-description (string-ascii 256)) (charitable-causes (list 10 (string-ascii 64))) (campaign-close-height uint) (campaign-type (string-ascii 20)) (distribution-weights (optional (list 10 uint))))
  (let
    (
      (new-donation-campaign-id (var-get next-donation-campaign-id))
    )
    (asserts! (> (len campaign-description) u0) ERR-INVALID-DESCRIPTION)
    (asserts! (> (len charitable-causes) u1) ERR-INVALID-CAUSE-COUNT)
    (asserts! (> campaign-close-height block-height) ERR-INVALID-CLOSE-HEIGHT)
    (asserts! (is-some (index-of (var-get campaign-types) campaign-type)) ERR-INVALID-CAMPAIGN-TYPE)
    (asserts! (or (is-eq campaign-type "equal-split") (is-eq campaign-type "milestone-based") (is-some distribution-weights)) ERR-MISSING-DISTRIBUTION-PLAN)
    (map-set donation-campaigns
      { donation-campaign-id: new-donation-campaign-id }
      {
        campaign-creator: tx-sender,
        campaign-description: campaign-description,
        charitable-causes: charitable-causes,
        total-donated-amount: u0,
        is-campaign-open: true,
        selected-causes: (list),
        campaign-close-height: campaign-close-height,
        campaign-type: campaign-type,
        distribution-weights: distribution-weights
      }
    )
    (var-set next-donation-campaign-id (+ new-donation-campaign-id u1))
    (ok new-donation-campaign-id)
  )
)

(define-public (make-donation (donation-campaign-id uint) (chosen-cause uint) (donation-amount uint))
  (let
    (
      (campaign (unwrap! (get-donation-campaign donation-campaign-id) ERR-DOES-NOT-EXIST))
      (existing-donation (default-to { chosen-cause: u0, donated-amount: u0 } (get-donation donation-campaign-id tx-sender)))
    )
    (asserts! (> donation-amount u0) ERR-INVALID-DONATION-AMOUNT)
    (asserts! (get is-campaign-open campaign) ERR-CAMPAIGN-CLOSED)
    (asserts! (>= (len (get charitable-causes campaign)) chosen-cause) ERR-INVALID-CAUSE)
    (asserts! (< block-height (get campaign-close-height campaign)) ERR-CAMPAIGN-EXPIRED)
    (try! (stx-transfer? donation-amount tx-sender (as-contract tx-sender)))
    (map-set donations
      { donation-campaign-id: donation-campaign-id, donor: tx-sender }
      {
        chosen-cause: chosen-cause,
        donated-amount: (+ donation-amount (get donated-amount existing-donation))
      }
    )
    (map-set donation-campaigns
      { donation-campaign-id: donation-campaign-id }
      (merge campaign { total-donated-amount: (+ (get total-donated-amount campaign) donation-amount) })
    )
    (ok true)
  )
)

(define-public (close-donation-campaign (donation-campaign-id uint))
  (let
    (
      (campaign (unwrap! (get-donation-campaign donation-campaign-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (or (is-eq (get campaign-creator campaign) tx-sender) (is-eq contract-owner tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (get is-campaign-open campaign) ERR-CAMPAIGN-CLOSED)
    (asserts! (>= block-height (get campaign-close-height campaign)) ERR-CAMPAIGN-NOT-CLOSABLE)
    (map-set donation-campaigns
      { donation-campaign-id: donation-campaign-id }
      (merge campaign { is-campaign-open: false })
    )
    (ok true)
  )
)

(define-public (cancel-donation-campaign (donation-campaign-id uint))
  (let
    (
      (campaign (unwrap! (get-donation-campaign donation-campaign-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (is-eq (get campaign-creator campaign) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (get is-campaign-open campaign) ERR-CAMPAIGN-CLOSED)
    (asserts! (< block-height (get campaign-close-height campaign)) ERR-CAMPAIGN-NOT-CANCELABLE)
    
    ;; First set the campaign as closed
    (map-set donation-campaigns
      { donation-campaign-id: donation-campaign-id }
      (merge campaign { is-campaign-open: false })
    )
    
    ;; Then process refunds
    (process-refunds donation-campaign-id)
  )
)

(define-public (claim-beneficiary-funds (donation-campaign-id uint))
  (let
    (
      (campaign (unwrap! (get-donation-campaign donation-campaign-id) ERR-DOES-NOT-EXIST))
      (donation (unwrap! (get-donation donation-campaign-id tx-sender) ERR-DOES-NOT-EXIST))
      (selected-cause-ids (get selected-causes campaign))
    )
    (asserts! (is-some (index-of selected-cause-ids (get chosen-cause donation))) ERR-NOT-A-BENEFICIARY)
    (let
      (
        (distribution (calculate-distribution campaign donation selected-cause-ids))
      )
      (try! (as-contract (stx-transfer? distribution tx-sender tx-sender)))
      (map-delete donations { donation-campaign-id: donation-campaign-id, donor: tx-sender })
      (ok distribution)
    )
  )
)

(define-public (settle-donation-campaign (donation-campaign-id uint) (selected-cause-ids (list 5 uint)))
  (let
    (
      (campaign (unwrap! (get-donation-campaign donation-campaign-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (is-eq contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (get is-campaign-open campaign)) ERR-CAMPAIGN-CLOSED)
    (asserts! (is-eq (len (get selected-causes campaign)) u0) ERR-ALREADY-SETTLED)
    (asserts! (> (len selected-cause-ids) u0) ERR-NO-SELECTED-CAUSES)
    (asserts! (<= (len selected-cause-ids) u5) ERR-TOO-MANY-CAUSES)
    
    ;; Validate each selected cause
    (asserts! (validate-causes-helper selected-cause-ids (len (get charitable-causes campaign))) ERR-INVALID-SELECTED-CAUSE)
    
    (map-set donation-campaigns
      { donation-campaign-id: donation-campaign-id }
      (merge campaign { selected-causes: selected-cause-ids })
    )
    (ok true)
  )
)

;; Contract initialization
(begin
  (var-set next-donation-campaign-id u0)
)

;; Export the Component function (required for v0)
(define-public (Component)
  (ok true))