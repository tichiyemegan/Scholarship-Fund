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
