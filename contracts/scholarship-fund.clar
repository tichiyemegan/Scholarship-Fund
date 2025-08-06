;; scholarship-fund
;; A transparent scholarship fund smart contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))

;; Data Variables
(define-data-var total-funds uint u0)
(define-map committee-members principal bool)
(define-map multisig-proposals
    uint
    {proposer: principal,
     scholar: principal,
     amount: uint,
     approvals: uint,
     required-approvals: uint,
     deadline: uint,
     status: (string-ascii 20)})

(define-map proposal-votes
    {proposal-id: uint, voter: principal}
    bool)

(define-data-var committee-size uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var approval-threshold uint u3)
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


(define-map funding-goals 
    uint 
    {target-amount: uint,
     current-amount: uint,
     deadline: uint})

(define-public (create-funding-goal (goal-id uint) (target uint) (duration uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set funding-goals goal-id
            {target-amount: target,
             current-amount: u0,
             deadline: (+ block-height duration)})
        (ok true)))

(define-read-only (check-goal-progress (goal-id uint))
    (map-get? funding-goals goal-id))


(define-map donor-levels
    principal
    {level: (string-ascii 20),
     total-donated: uint})

(define-public (update-donor-level (donor principal) (amount uint))
    (let ((current-total (get-donor-contribution donor)))
        (map-set donor-levels donor
            {level: (if (>= amount u1000000) "Platinum"
                    (if (>= amount u500000) "Gold"
                    (if (>= amount u100000) "Silver" "Bronze"))),
             total-donated: (+ current-total amount)})
        (ok true)))


(define-map emergency-contacts
    principal  ;; scholar
    {contact: principal,
     relationship: (string-ascii 20)})

(define-public (set-emergency-contact (scholar principal) (contact principal) (relationship (string-ascii 20)))
    (begin
        (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender scholar)) err-owner-only)
        (map-set emergency-contacts scholar
            {contact: contact,
             relationship: relationship})
        (ok true)))


(define-map payment-schedules
    principal
    {total-amount: uint,
     installments: uint,
     amount-per-installment: uint,
     next-payment: uint})

(define-public (setup-payment-schedule (scholar principal) (total uint) (num-installments uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set payment-schedules scholar
            {total-amount: total,
             installments: num-installments,
             amount-per-installment: (/ total num-installments),
             next-payment: block-height})
        (ok true)))


(define-map scholar-feedback
    principal
    {rating: uint,
     comment: (string-ascii 100),
     timestamp: uint})

(define-public (submit-feedback (rating uint) (comment (string-ascii 100)))
    (begin
        (asserts! (is-some (map-get? scholars tx-sender)) (err u105))
        (map-set scholar-feedback tx-sender
            {rating: rating,
             comment: comment,
             timestamp: block-height})
        (ok true)))


(define-map milestone-rewards
    uint
    {reward-amount: uint,
     description: (string-ascii 50)})

(define-public (set-milestone-reward (milestone-id uint) (amount uint) (description (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set milestone-rewards milestone-id
            {reward-amount: amount,
             description: description})
        (ok true)))

(define-public (claim-milestone-reward (scholar principal) (milestone-id uint))
    (let ((reward (unwrap! (map-get? milestone-rewards milestone-id) (err u106))))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (as-contract (stx-transfer? (get reward-amount reward) 
                                        (as-contract tx-sender) 
                                        scholar)))
        (ok true)))



(define-map application-deadlines 
    uint 
    {deadline: uint, 
     is-active: bool})

(define-data-var current-application-round uint u1)

(define-public (set-application-deadline (deadline uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set application-deadlines (var-get current-application-round) 
            {deadline: deadline, 
             is-active: true})
        (ok true)))

(define-public (close-application-round)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set application-deadlines (var-get current-application-round) 
            {deadline: (default-to u0 
                (get deadline (map-get? application-deadlines (var-get current-application-round)))), 
             is-active: false})
        (var-set current-application-round (+ (var-get current-application-round) u1))
        (ok true)))

(define-read-only (get-current-application-deadline)
    (map-get? application-deadlines (var-get current-application-round)))


(define-map budget-allocations
    uint
    {year: uint,
     total-budget: uint,
     allocated: uint,
     remaining: uint})

(define-data-var current-budget-year uint u2023)

(define-public (set-annual-budget (year uint) (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set budget-allocations year
            {year: year,
             total-budget: amount,
             allocated: u0,
             remaining: amount})
        (var-set current-budget-year year)
        (ok true)))

(define-public (update-budget-allocation (amount uint))
    (let ((current-allocation (default-to 
            {year: (var-get current-budget-year), 
             total-budget: u0, 
             allocated: u0, 
             remaining: u0}
            (map-get? budget-allocations (var-get current-budget-year)))))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= amount (get remaining current-allocation)) err-insufficient-funds)
        (map-set budget-allocations (var-get current-budget-year)
            {year: (get year current-allocation),
             total-budget: (get total-budget current-allocation),
             allocated: (+ (get allocated current-allocation) amount),
             remaining: (- (get remaining current-allocation) amount)})
        (ok true)))

(define-read-only (get-current-budget)
    (map-get? budget-allocations (var-get current-budget-year)))



(define-map scholar-achievements
    {scholar: principal, achievement-id: uint}
    {title: (string-ascii 50),
     description: (string-ascii 100),
     date-earned: uint,
     reward-amount: uint})

(define-public (record-achievement (scholar principal) (achievement-id uint) (title (string-ascii 50)) (description (string-ascii 100)) (reward uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set scholar-achievements 
            {scholar: scholar, achievement-id: achievement-id}
            {title: title,
             description: description,
             date-earned: block-height,
             reward-amount: reward})
        (ok true)))

(define-read-only (get-scholar-achievement (scholar principal) (achievement-id uint))
    (map-get? scholar-achievements {scholar: scholar, achievement-id: achievement-id}))

(define-read-only (has-achievement (scholar principal) (achievement-id uint))
    (is-some (map-get? scholar-achievements {scholar: scholar, achievement-id: achievement-id})))


(define-map donor-recognition
    principal
    {total-donated: uint,
     recognition-level: (string-ascii 20),
     benefits: (string-ascii 100),
     last-donation: uint})

(define-constant bronze-threshold u50000)
(define-constant silver-threshold u100000)
(define-constant gold-threshold u500000)
(define-constant platinum-threshold u1000000)

(define-public (update-donor-recognition (donor principal) (amount uint))
   (let ((current-data (default-to 
           {total-donated: u0, 
            recognition-level: "None", 
            benefits: "None", 
            last-donation: u0} 
           (map-get? donor-recognition donor)))
         (new-total (+ (get total-donated current-data) amount)))
       (asserts! (is-eq tx-sender contract-owner) err-owner-only)
       (map-set donor-recognition donor
           {total-donated: new-total,
            recognition-level: (if (>= new-total platinum-threshold) 
                               "Platinum"
                               (if (>= new-total gold-threshold)
                                   "Gold"
                                   (if (>= new-total silver-threshold)
                                       "Silver"
                                       (if (>= new-total bronze-threshold)
                                           "Bronze"
                                           "Supporter")))),
            benefits: (if (>= new-total platinum-threshold)
                       "Annual event, named scholarship, voting rights"
                       (if (>= new-total gold-threshold)
                           "Annual event, committee membership"
                           (if (>= new-total silver-threshold)
                               "Recognition certificate, newsletter feature"
                               (if (>= new-total bronze-threshold)
                                   "Recognition certificate"
                                   "Thank you letter")))),
            last-donation: block-height})
       (ok true)))
(define-read-only (get-donor-recognition (donor principal))
    (map-get? donor-recognition donor))





(define-map matching-programs
    uint
    {sponsor: principal,
     match-ratio: uint,
     max-match: uint,
     remaining-funds: uint,
     is-active: bool})

(define-data-var matching-program-count uint u0)

(define-public (create-matching-program (match-ratio uint) (max-match uint))
    (begin
        (asserts! (>= (stx-get-balance tx-sender) max-match) err-insufficient-funds)
        (try! (stx-transfer? max-match tx-sender (as-contract tx-sender)))
        (var-set matching-program-count (+ (var-get matching-program-count) u1))
        (map-set matching-programs (var-get matching-program-count)
            {sponsor: tx-sender,
             match-ratio: match-ratio,
             max-match: max-match,
             remaining-funds: max-match,
             is-active: true})
        (ok (var-get matching-program-count))))

(define-public (donate-with-matching (amount uint) (program-id uint))
    (let ((program (unwrap! (map-get? matching-programs program-id) (err u107)))
          (match-amount (if (< (/ (* amount (get match-ratio program)) u100) 
                              (get remaining-funds program))
                          (/ (* amount (get match-ratio program)) u100)
                          (get remaining-funds program))))
        (asserts! (get is-active program) (err u108))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set matching-programs program-id
            {sponsor: (get sponsor program),
             match-ratio: (get match-ratio program),
             max-match: (get max-match program),
             remaining-funds: (- (get remaining-funds program) match-amount),
             is-active: (> (- (get remaining-funds program) match-amount) u0)})
        (var-set total-funds (+ (var-get total-funds) (+ amount match-amount)))
        (map-set donors tx-sender (+ (default-to u0 (map-get? donors tx-sender)) amount))
        (ok {donation: amount, match: match-amount, total: (+ amount match-amount)})))




(define-map scholar-graduation
    principal
    {graduation-date: uint,
     degree: (string-ascii 50),
     institution: (string-ascii 50),
     is-alumni: bool})

(define-map alumni-contributions
    principal
    {total-contributed: uint,
     mentorship-hours: uint,
     last-contribution: uint})

(define-public (record-graduation (scholar principal) (degree (string-ascii 50)) (institution (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set scholar-graduation scholar
            {graduation-date: block-height,
             degree: degree,
             institution: institution,
             is-alumni: true})
        (map-set alumni-contributions scholar
            {total-contributed: u0,
             mentorship-hours: u0,
             last-contribution: u0})
        (ok true)))

(define-public (record-alumni-contribution (alumni principal) (amount uint) (mentorship-hours uint))
    (let ((current-data (default-to 
            {total-contributed: u0, mentorship-hours: u0, last-contribution: u0} 
            (map-get? alumni-contributions alumni))))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set alumni-contributions alumni
            {total-contributed: (+ (get total-contributed current-data) amount),
             mentorship-hours: (+ (get mentorship-hours current-data) mentorship-hours),
             last-contribution: block-height})
        (ok true)))

(define-read-only (get-alumni-status (scholar principal))
    (map-get? scholar-graduation scholar))

(define-read-only (get-alumni-contributions (alumni principal))
    (map-get? alumni-contributions alumni))



(define-map eligibility-criteria
    uint
    {name: (string-ascii 50),
     min-academic-score: uint,
     max-family-income: uint,
     required-field-of-study: (string-ascii 50),
     is-active: bool})

(define-data-var criteria-count uint u0)

(define-public (create-eligibility-criteria 
    (name (string-ascii 50)) 
    (min-score uint) 
    (max-income uint) 
    (field-of-study (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set criteria-count (+ (var-get criteria-count) u1))
        (map-set eligibility-criteria (var-get criteria-count)
            {name: name,
             min-academic-score: min-score,
             max-family-income: max-income,
             required-field-of-study: field-of-study,
             is-active: true})
        (ok (var-get criteria-count))))

(define-map applicant-eligibility
    {applicant: principal, criteria-id: uint}
    {is-eligible: bool,
     verification-date: uint,
     verified-by: principal})

(define-public (verify-eligibility (applicant principal) (criteria-id uint) (is-eligible bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set applicant-eligibility 
            {applicant: applicant, criteria-id: criteria-id}
            {is-eligible: is-eligible,
             verification-date: block-height,
             verified-by: tx-sender})
        (ok true)))

(define-read-only (get-eligibility-criteria (criteria-id uint))
    (map-get? eligibility-criteria criteria-id))

(define-read-only (check-applicant-eligibility (applicant principal) (criteria-id uint))
    (map-get? applicant-eligibility {applicant: applicant, criteria-id: criteria-id}))








(define-map impact-metrics
    principal
    {employment-status: (string-ascii 20),
     salary-range: uint,
     industry: (string-ascii 50),
     impact-score: uint})

(define-map community-contributions
    principal
    {volunteer-hours: uint,
     projects-completed: uint,
     people-impacted: uint})

(define-public (update-scholar-impact 
    (scholar principal) 
    (status (string-ascii 20)) 
    (salary uint) 
    (industry (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set impact-metrics scholar
            {employment-status: status,
             salary-range: salary,
             industry: industry,
             impact-score: (+ salary u100)})
        (ok true)))

(define-public (record-community-impact 
    (scholar principal) 
    (hours uint) 
    (projects uint) 
    (people uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set community-contributions scholar
            {volunteer-hours: hours,
             projects-completed: projects,
             people-impacted: people})
        (ok true)))

(define-read-only (get-scholar-impact (scholar principal))
    (map-get? impact-metrics scholar))

(define-read-only (get-community-impact (scholar principal))
    (map-get? community-contributions scholar))



(define-map distribution-parameters
    uint
    {base-amount: uint,
     market-multiplier: uint,
     applicant-divisor: uint,
     min-amount: uint,
     max-amount: uint})

(define-data-var current-distribution-id uint u1)
(define-data-var total-qualified-applicants uint u0)

(define-public (set-distribution-parameters 
    (base uint) 
    (multiplier uint) 
    (divisor uint) 
    (min uint) 
    (max uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set distribution-parameters (var-get current-distribution-id)
            {base-amount: base,
             market-multiplier: multiplier,
             applicant-divisor: divisor,
             min-amount: min,
             max-amount: max})
        (ok true)))

(define-read-only (calculate-dynamic-amount)
    (let ((params (unwrap! (map-get? distribution-parameters (var-get current-distribution-id)) (err u200)))
          (raw-amount (/ (* (get base-amount params) (get market-multiplier params))
                        (* (get applicant-divisor params) (var-get total-qualified-applicants)))))
        (ok (if (< raw-amount (get min-amount params))
            (get min-amount params)
            (if (> raw-amount (get max-amount params))
                (get max-amount params)
                raw-amount)))))

(define-map auto-distribution-rules
    uint
    {min-score: uint,
     max-awards: uint,
     award-amount: uint,
     is-active: bool,
     distribution-date: uint})

(define-map auto-distribution-queue
    {rule-id: uint, applicant: principal}
    {queue-position: uint,
     qualification-score: uint,
     auto-approved: bool})

(define-data-var auto-rule-count uint u0)
(define-data-var current-distribution-batch uint u0)

(define-public (create-auto-distribution-rule 
    (min-score uint) 
    (max-awards uint) 
    (award-amount uint) 
    (distribution-date uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= award-amount (var-get total-funds)) err-insufficient-funds)
        (var-set auto-rule-count (+ (var-get auto-rule-count) u1))
        (map-set auto-distribution-rules (var-get auto-rule-count)
            {min-score: min-score,
             max-awards: max-awards,
             award-amount: award-amount,
             is-active: true,
             distribution-date: distribution-date})
        (ok (var-get auto-rule-count))))

(define-public (queue-for-auto-distribution (rule-id uint))
    (let ((rule (unwrap! (map-get? auto-distribution-rules rule-id) (err u200)))
          (application (unwrap! (map-get? scholarship-applications tx-sender) (err u201))))
        (asserts! (get is-active rule) (err u202))
        (asserts! (>= (get academic-score application) (get min-score rule)) (err u203))
        (asserts! (>= block-height (get distribution-date rule)) (err u204))
        (map-set auto-distribution-queue 
            {rule-id: rule-id, applicant: tx-sender}
            {queue-position: u0,
             qualification-score: (get academic-score application),
             auto-approved: false})
        (ok true)))

(define-public (process-auto-distribution (rule-id uint))
    (let ((rule (unwrap! (map-get? auto-distribution-rules rule-id) (err u200))))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (get is-active rule) (err u202))
        (asserts! (>= block-height (get distribution-date rule)) (err u204))
        (asserts! (<= (get award-amount rule) (var-get total-funds)) err-insufficient-funds)
        (var-set current-distribution-batch (+ (var-get current-distribution-batch) u1))
        (ok true)))

(define-public (execute-auto-award (rule-id uint) (recipient principal))
    (let ((rule (unwrap! (map-get? auto-distribution-rules rule-id) (err u200)))
          (queue-entry (unwrap! (map-get? auto-distribution-queue {rule-id: rule-id, applicant: recipient}) (err u205))))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get auto-approved queue-entry)) (err u206))
        (asserts! (<= (get award-amount rule) (var-get total-funds)) err-insufficient-funds)
        (try! (as-contract (stx-transfer? (get award-amount rule) (as-contract tx-sender) recipient)))
        (map-set scholars recipient 
            {amount: (get award-amount rule), 
             status: "auto-awarded"})
        (map-set auto-distribution-queue 
            {rule-id: rule-id, applicant: recipient}
            {queue-position: (get queue-position queue-entry),
             qualification-score: (get qualification-score queue-entry),
             auto-approved: true})
        (var-set total-funds (- (var-get total-funds) (get award-amount rule)))
        (ok (get award-amount rule))))

(define-public (deactivate-auto-rule (rule-id uint))
    (let ((rule (unwrap! (map-get? auto-distribution-rules rule-id) (err u200))))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set auto-distribution-rules rule-id
            {min-score: (get min-score rule),
             max-awards: (get max-awards rule),
             award-amount: (get award-amount rule),
             is-active: false,
             distribution-date: (get distribution-date rule)})
        (ok true)))

(define-read-only (get-auto-distribution-rule (rule-id uint))
    (map-get? auto-distribution-rules rule-id))

(define-read-only (get-queue-status (rule-id uint) (applicant principal))
    (map-get? auto-distribution-queue {rule-id: rule-id, applicant: applicant}))

(define-read-only (check-auto-eligibility (rule-id uint) (applicant principal))
    (let ((rule (map-get? auto-distribution-rules rule-id))
          (application (map-get? scholarship-applications applicant)))
        (match rule
            some-rule (match application
                some-app (ok {eligible: (and 
                    (get is-active some-rule)
                    (>= (get academic-score some-app) (get min-score some-rule))
                    (>= block-height (get distribution-date some-rule))),
                    score: (get academic-score some-app),
                    required-score: (get min-score some-rule)})
                (err u201))
            (err u200))))




(define-public (add-committee-member (member principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (default-to false (map-get? committee-members member))) (err u300))
        (map-set committee-members member true)
        (var-set committee-size (+ (var-get committee-size) u1))
        (ok true)))

(define-public (remove-committee-member (member principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (default-to false (map-get? committee-members member)) (err u301))
        (map-set committee-members member false)
        (var-set committee-size (- (var-get committee-size) u1))
        (ok true)))

(define-public (set-approval-threshold (threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= threshold (var-get committee-size)) (err u302))
        (var-set approval-threshold threshold)
        (ok true)))

(define-public (propose-multisig-scholarship (scholar principal) (amount uint) (deadline-blocks uint))
    (begin
        (asserts! (default-to false (map-get? committee-members tx-sender)) (err u303))
        (asserts! (<= amount (var-get total-funds)) err-insufficient-funds)
        (var-set proposal-counter (+ (var-get proposal-counter) u1))
        (map-set multisig-proposals (var-get proposal-counter)
            {proposer: tx-sender,
             scholar: scholar,
             amount: amount,
             approvals: u1,
             required-approvals: (var-get approval-threshold),
             deadline: (+ block-height deadline-blocks),
             status: "pending"})
        (map-set proposal-votes 
            {proposal-id: (var-get proposal-counter), voter: tx-sender} 
            true)
        (ok (var-get proposal-counter))))

(define-public (vote-on-proposal (proposal-id uint) (approve bool))
    (let ((proposal (unwrap! (map-get? multisig-proposals proposal-id) (err u304)))
          (has-voted (default-to false (map-get? proposal-votes {proposal-id: proposal-id, voter: tx-sender}))))
        (asserts! (default-to false (map-get? committee-members tx-sender)) (err u303))
        (asserts! (not has-voted) (err u305))
        (asserts! (is-eq (get status proposal) "pending") (err u306))
        (asserts! (< block-height (get deadline proposal)) (err u307))
        (if approve
            (begin
                (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender} true)
                (map-set multisig-proposals proposal-id
                    {proposer: (get proposer proposal),
                     scholar: (get scholar proposal),
                     amount: (get amount proposal),
                     approvals: (+ (get approvals proposal) u1),
                     required-approvals: (get required-approvals proposal),
                     deadline: (get deadline proposal),
                     status: (if (>= (+ (get approvals proposal) u1) (get required-approvals proposal))
                                "approved"
                                "pending")})
                (ok true))
            (begin
                (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender} false)
                (ok false)))))

(define-public (execute-multisig-scholarship (proposal-id uint))
    (let ((proposal (unwrap! (map-get? multisig-proposals proposal-id) (err u304))))
        (asserts! (is-eq (get status proposal) "approved") (err u308))
        (asserts! (<= (get amount proposal) (var-get total-funds)) err-insufficient-funds)
        (try! (as-contract (stx-transfer? (get amount proposal) (as-contract tx-sender) (get scholar proposal))))
        (map-set scholars (get scholar proposal) 
            {amount: (get amount proposal), 
             status: "multisig-awarded"})
        (map-set multisig-proposals proposal-id
            {proposer: (get proposer proposal),
             scholar: (get scholar proposal),
             amount: (get amount proposal),
             approvals: (get approvals proposal),
             required-approvals: (get required-approvals proposal),
             deadline: (get deadline proposal),
             status: "executed"})
        (var-set total-funds (- (var-get total-funds) (get amount proposal)))
        (ok (get amount proposal))))

(define-public (cancel-expired-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? multisig-proposals proposal-id) (err u304))))
        (asserts! (>= block-height (get deadline proposal)) (err u309))
        (asserts! (is-eq (get status proposal) "pending") (err u310))
        (map-set multisig-proposals proposal-id
            {proposer: (get proposer proposal),
             scholar: (get scholar proposal),
             amount: (get amount proposal),
             approvals: (get approvals proposal),
             required-approvals: (get required-approvals proposal),
             deadline: (get deadline proposal),
             status: "expired"})
        (ok true)))

(define-read-only (get-committee-status (member principal))
    (default-to false (map-get? committee-members member)))

(define-read-only (get-proposal-details (proposal-id uint))
    (map-get? multisig-proposals proposal-id))

(define-read-only (get-vote-status (proposal-id uint) (voter principal))
    (map-get? proposal-votes {proposal-id: proposal-id, voter: voter}))

(define-read-only (get-committee-info)
    (ok {committee-size: (var-get committee-size),
         approval-threshold: (var-get approval-threshold),
         total-proposals: (var-get proposal-counter)}))