;; scholarship-fund
;; A transparent scholarship fund smart contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))

;; Data Variables
(define-data-var total-funds uint u0)

;; Data Maps
(define-map donors principal uint)
(define-map scholars 
    principal 
    {amount: uint, status: (string-ascii 20)})

;; Public Functions
(define-public (donate-funds (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set donors tx-sender amount)
        (var-set total-funds (+ (var-get total-funds) amount))
        (ok amount)))

(define-public (award-scholarship (scholar principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= amount (var-get total-funds)) err-insufficient-funds)
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) scholar)))
        (map-set scholars scholar {amount: amount, status: "awarded"})
        (var-set total-funds (- (var-get total-funds) amount))
        (ok amount)))

;; Read-only Functions
(define-read-only (get-total-funds)
    (var-get total-funds))

(define-read-only (get-donor-contribution (donor principal))
    (default-to u0 (map-get? donors donor)))

(define-read-only (get-scholar-info (scholar principal))
    (map-get? scholars scholar))


;; Add new data map for applications
(define-map scholarship-applications 
    principal 
    {applicant-name: (string-ascii 50), 
     academic-score: uint,
     status: (string-ascii 20)})

(define-public (submit-application (name (string-ascii 50)) (score uint))
    (begin
        (map-set scholarship-applications tx-sender 
            {applicant-name: name,
             academic-score: score,
             status: "pending"})
        (ok true)))


(define-data-var emergency-mode bool false)

(define-public (toggle-emergency-mode)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-mode (not (var-get emergency-mode)))
        (ok true)))

(define-public (recover-funds)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (var-get emergency-mode) (err u102))
        (as-contract (stx-transfer? (var-get total-funds) (as-contract tx-sender) contract-owner))))


(define-map scholar-milestones
    principal 
    {milestones-completed: uint,
     total-milestones: uint,
     last-update: uint})

(define-public (update-scholar-milestone (scholar principal) (milestone-count uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set scholar-milestones scholar
            {milestones-completed: milestone-count,
             total-milestones: u4,
             last-update: block-height})
        (ok true)))


(define-constant scholarship-duration u52560) ;; roughly 1 year in blocks

(define-map scholarship-expiry principal uint)

(define-public (set-scholarship-expiry (scholar principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set scholarship-expiry scholar (+ block-height scholarship-duration))
        (ok true)))


(define-map voting-power principal uint)
(define-map proposals 
    uint 
    {description: (string-ascii 50),
     votes: uint,
     status: (string-ascii 20)})

(define-public (create-proposal (id uint) (description (string-ascii 50)))
    (begin
        (asserts! (>= (default-to u0 (map-get? donors tx-sender)) u100) (err u103))
        (map-set proposals id 
            {description: description,
             votes: u0,
             status: "active"})
        (ok true)))

(define-map scholar-reports
    principal
    {academic-score: uint,
     attendance: uint,
     report-date: uint})

(define-public (submit-performance-report (scholar principal) (score uint) (attendance uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set scholar-reports scholar
            {academic-score: score,
             attendance: attendance,
             report-date: block-height})
        (ok true)))



;; Add tier definitions
(define-map scholarship-tiers 
    uint 
    {tier-name: (string-ascii 20),
     amount: uint,
     requirements: uint})

;; Function to create tiers
(define-public (create-scholarship-tier (tier-id uint) (name (string-ascii 20)) (amount uint) (min-score uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set scholarship-tiers tier-id 
            {tier-name: name,
             amount: amount,
             requirements: min-score})
        (ok true)))


;; Add referral tracking
(define-map referrals 
    principal 
    {referrer: principal,
     bonus-earned: uint})

(define-public (refer-donor (new-donor principal))
    (begin
        (map-set referrals new-donor 
            {referrer: tx-sender,
             bonus-earned: u0})
        (ok true)))



(define-map mentors
    principal
    {expertise: (string-ascii 50),
     availability: bool})

(define-map mentor-assignments
    principal  ;; scholar
    principal) ;; mentor

(define-public (register-as-mentor (expertise (string-ascii 50)))
    (begin
        (map-set mentors tx-sender 
            {expertise: expertise,
             availability: true})
        (ok true)))



(define-data-var total-scholars-funded uint u0)
(define-data-var average-scholarship-amount uint u0)

(define-public (update-analytics (new-amount uint))
    (begin
        (var-set total-scholars-funded (+ (var-get total-scholars-funded) u1))
        (var-set average-scholarship-amount 
            (/ (+ (var-get average-scholarship-amount) new-amount) u2))
        (ok true)))


(define-map scholarship-renewals
    principal
    {renewal-count: uint,
     last-renewal: uint,
     status: (string-ascii 20)})

(define-public (request-renewal (scholar principal))
    (begin
        (asserts! (is-eq tx-sender scholar) err-owner-only)
        (map-set scholarship-renewals scholar
            {renewal-count: u1,
             last-renewal: block-height,
             status: "pending"})
        (ok true)))



(define-map donor-voting-weight
    principal
    {base-weight: uint,
     bonus-weight: uint})

(define-public (calculate-voting-weight (donor principal))
    (let ((donation-amount (default-to u0 (map-get? donors donor))))
        (map-set donor-voting-weight donor
            {base-weight: (/ donation-amount u100),
             bonus-weight: u0})
        (ok true)))
