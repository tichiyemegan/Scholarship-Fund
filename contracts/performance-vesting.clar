;; Scholar Performance & Vesting Reward System
;; A sophisticated contract for performance-based scholarship distribution with vesting mechanics

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-not-found (err u401))
(define-constant err-unauthorized (err u402))
(define-constant err-insufficient-balance (err u403))
(define-constant err-invalid-parameters (err u404))
(define-constant err-performance-too-low (err u405))
(define-constant err-vesting-not-ready (err u406))
(define-constant err-already-exists (err u407))
(define-constant err-no-rewards-available (err u408))

;; Performance thresholds
(define-constant excellent-threshold u90)
(define-constant good-threshold u75)
(define-constant minimum-threshold u60)
(define-constant penalty-threshold u50)

;; Vesting periods (in blocks, approximately 1 month = 4320 blocks)
(define-constant monthly-vesting u4320)
(define-constant quarterly-vesting u12960)
(define-constant semester-vesting u25920)

;; Data Variables
(define-data-var total-vesting-funds uint u0)
(define-data-var active-vesting-accounts uint u0)
(define-data-var performance-evaluators-count uint u0)

;; Performance Evaluators Map
(define-map performance-evaluators principal bool)

;; Scholar Vesting Schedule
(define-map scholar-vesting-schedule
    principal
    {total-allocation: uint,
     released-amount: uint,
     locked-amount: uint,
     vesting-start: uint,
     vesting-duration: uint,
     performance-multiplier: uint,
     last-evaluation: uint,
     status: (string-ascii 20)})

;; Performance Metrics Tracking
(define-map scholar-performance-metrics
    principal
    {academic-score: uint,
     attendance-rate: uint,
     community-hours: uint,
     research-publications: uint,
     leadership-roles: uint,
     evaluation-date: uint,
     overall-rating: uint})

;; Performance History for Trend Analysis
(define-map performance-history
    {scholar: principal, evaluation-period: uint}
    {academic-score: uint,
     attendance-rate: uint,
     community-engagement: uint,
     improvement-factor: uint,
     bonus-earned: uint})

;; Vesting Milestone System
(define-map vesting-milestones
    {scholar: principal, milestone-id: uint}
    {milestone-type: (string-ascii 30),
     target-value: uint,
     achieved-value: uint,
     reward-percentage: uint,
     completion-date: uint,
     is-completed: bool})

;; Performance Penalties and Bonuses
(define-map performance-adjustments
    principal
    {penalty-amount: uint,
     bonus-amount: uint,
     adjustment-reason: (string-ascii 100),
     adjustment-date: uint,
     applied-by: principal})

;; Accelerated Vesting Eligibility
(define-map acceleration-eligibility
    principal
    {consecutive-excellent-evaluations: uint,
     total-bonus-earned: uint,
     acceleration-factor: uint,
     next-acceleration-check: uint})

;; Performance-Based Reward Pools
(define-map reward-pools
    uint
    {pool-name: (string-ascii 50),
     total-allocation: uint,
     available-funds: uint,
     eligibility-criteria: uint,
     distribution-period: uint,
     is-active: bool})

(define-data-var reward-pool-counter uint u0)

;; Scholar Performance Goals
(define-map scholar-goals
    {scholar: principal, goal-id: uint}
    {goal-description: (string-ascii 100),
     target-metric: uint,
     current-progress: uint,
     deadline: uint,
     reward-amount: uint,
     is-achieved: bool})

(define-data-var goal-counter uint u0)

;; Public Functions

;; Initialize scholar vesting schedule
(define-public (initialize-scholar-vesting 
    (scholar principal) 
    (total-allocation uint) 
    (vesting-duration uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> total-allocation u0) err-invalid-parameters)
        (asserts! (> vesting-duration u0) err-invalid-parameters)
        (asserts! (is-none (map-get? scholar-vesting-schedule scholar)) err-already-exists)
        
        ;; Transfer funds to contract
        (try! (stx-transfer? total-allocation tx-sender (as-contract tx-sender)))
        
        ;; Set up vesting schedule
        (map-set scholar-vesting-schedule scholar
            {total-allocation: total-allocation,
             released-amount: u0,
             locked-amount: total-allocation,
             vesting-start: block-height,
             vesting-duration: vesting-duration,
             performance-multiplier: u100,
             last-evaluation: block-height,
             status: "active"})
        
        ;; Initialize performance metrics
        (map-set scholar-performance-metrics scholar
            {academic-score: u0,
             attendance-rate: u0,
             community-hours: u0,
             research-publications: u0,
             leadership-roles: u0,
             evaluation-date: block-height,
             overall-rating: u0})
        
        ;; Initialize acceleration tracking
        (map-set acceleration-eligibility scholar
            {consecutive-excellent-evaluations: u0,
             total-bonus-earned: u0,
             acceleration-factor: u100,
             next-acceleration-check: (+ block-height quarterly-vesting)})
        
        (var-set total-vesting-funds (+ (var-get total-vesting-funds) total-allocation))
        (var-set active-vesting-accounts (+ (var-get active-vesting-accounts) u1))
        (ok true)))

;; Add performance evaluator
(define-public (add-performance-evaluator (evaluator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set performance-evaluators evaluator true)
        (var-set performance-evaluators-count (+ (var-get performance-evaluators-count) u1))
        (ok true)))

;; Update scholar performance metrics
(define-public (update-performance-metrics 
    (scholar principal) 
    (academic-score uint) 
    (attendance-rate uint) 
    (community-hours uint) 
    (research-publications uint) 
    (leadership-roles uint))
    (let ((is-evaluator (default-to false (map-get? performance-evaluators tx-sender)))
          (schedule (unwrap! (map-get? scholar-vesting-schedule scholar) err-not-found))
          (overall-rating (calculate-overall-rating academic-score attendance-rate community-hours research-publications leadership-roles)))
        
        (asserts! (or (is-eq tx-sender contract-owner) is-evaluator) err-unauthorized)
        (asserts! (is-eq (get status schedule) "active") err-unauthorized)
        
        ;; Store current performance in history
        (let ((evaluation-period (/ (- block-height (get vesting-start schedule)) monthly-vesting)))
            (map-set performance-history 
                {scholar: scholar, evaluation-period: evaluation-period}
                {academic-score: academic-score,
                 attendance-rate: attendance-rate,
                 community-engagement: community-hours,
                 improvement-factor: (calculate-improvement-factor scholar academic-score),
                 bonus-earned: (calculate-performance-bonus overall-rating)}))
        
        ;; Update current metrics
        (map-set scholar-performance-metrics scholar
            {academic-score: academic-score,
             attendance-rate: attendance-rate,
             community-hours: community-hours,
             research-publications: research-publications,
             leadership-roles: leadership-roles,
             evaluation-date: block-height,
             overall-rating: overall-rating})
        
        ;; Update performance multiplier based on rating
        (let ((new-multiplier (calculate-performance-multiplier overall-rating)))
            (map-set scholar-vesting-schedule scholar
                (merge schedule {performance-multiplier: new-multiplier,
                               last-evaluation: block-height})))
        
        ;; Check for acceleration eligibility
        (try! (check-acceleration-eligibility scholar overall-rating))
        
        (ok overall-rating)))

;; Calculate vested amount available for release
(define-public (calculate-vested-amount (scholar principal))
    (let ((schedule (unwrap! (map-get? scholar-vesting-schedule scholar) err-not-found))
          (metrics (unwrap! (map-get? scholar-performance-metrics scholar) err-not-found))
          (acceleration (unwrap! (map-get? acceleration-eligibility scholar) err-not-found))
          (time-elapsed (- block-height (get vesting-start schedule)))
          (adjusted-duration (/ (* (get vesting-duration schedule) u100) (get acceleration-factor acceleration)))
          (base-vested-ratio (if (>= time-elapsed adjusted-duration) 
                               u100 
                               (/ (* time-elapsed u100) adjusted-duration)))
          (performance-adjusted-ratio (/ (* base-vested-ratio (get performance-multiplier schedule)) u100))
          (vested-amount (/ (* (get total-allocation schedule) performance-adjusted-ratio) u100))
          (available-for-release (- vested-amount (get released-amount schedule))))
        
        (ok {vested-amount: vested-amount,
             available-for-release: available-for-release,
             performance-multiplier: (get performance-multiplier schedule),
             acceleration-factor: (get acceleration-factor acceleration)})))

;; Release vested funds to scholar
(define-public (release-vested-funds (scholar principal))
    (let ((schedule (unwrap! (map-get? scholar-vesting-schedule scholar) err-not-found))
          (metrics (unwrap! (map-get? scholar-performance-metrics scholar) err-not-found))
          (vesting-calc (unwrap! (calculate-vested-amount scholar) err-not-found)))
        
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status schedule) "active") err-unauthorized)
        (asserts! (>= (get overall-rating metrics) minimum-threshold) err-performance-too-low)
        (asserts! (> (get available-for-release vesting-calc) u0) err-no-rewards-available)
        
        ;; Transfer funds to scholar
        (try! (as-contract (stx-transfer? (get available-for-release vesting-calc) 
                                        (as-contract tx-sender) 
                                        scholar)))
        
        ;; Update schedule
        (map-set scholar-vesting-schedule scholar
            (merge schedule 
                {released-amount: (+ (get released-amount schedule) (get available-for-release vesting-calc)),
                 locked-amount: (- (get locked-amount schedule) (get available-for-release vesting-calc))}))
        
        (var-set total-vesting-funds (- (var-get total-vesting-funds) (get available-for-release vesting-calc)))
        (ok (get available-for-release vesting-calc))))

;; Create performance-based reward pool
(define-public (create-reward-pool 
    (pool-name (string-ascii 50)) 
    (allocation uint) 
    (eligibility-criteria uint) 
    (distribution-period uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> allocation u0) err-invalid-parameters)
        
        (try! (stx-transfer? allocation tx-sender (as-contract tx-sender)))
        
        (var-set reward-pool-counter (+ (var-get reward-pool-counter) u1))
        (map-set reward-pools (var-get reward-pool-counter)
            {pool-name: pool-name,
             total-allocation: allocation,
             available-funds: allocation,
             eligibility-criteria: eligibility-criteria,
             distribution-period: distribution-period,
             is-active: true})
        
        (ok (var-get reward-pool-counter))))

;; Distribute rewards from pool based on performance
(define-public (distribute-pool-rewards (pool-id uint) (scholar principal) (amount uint))
    (let ((pool (unwrap! (map-get? reward-pools pool-id) err-not-found))
          (metrics (unwrap! (map-get? scholar-performance-metrics scholar) err-not-found)))
        
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (get is-active pool) err-unauthorized)
        (asserts! (>= (get overall-rating metrics) (get eligibility-criteria pool)) err-performance-too-low)
        (asserts! (<= amount (get available-funds pool)) err-insufficient-balance)
        
        ;; Transfer reward to scholar
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) scholar)))
        
        ;; Update pool
        (map-set reward-pools pool-id
            (merge pool {available-funds: (- (get available-funds pool) amount)}))
        
        ;; Update scholar bonus tracking
        (let ((adjustment (default-to 
                {penalty-amount: u0, bonus-amount: u0, adjustment-reason: "", adjustment-date: u0, applied-by: contract-owner}
                (map-get? performance-adjustments scholar))))
            (map-set performance-adjustments scholar
                (merge adjustment {bonus-amount: (+ (get bonus-amount adjustment) amount),
                                 adjustment-reason: "Performance pool reward",
                                 adjustment-date: block-height,
                                 applied-by: tx-sender})))
        
        (ok amount)))

;; Set performance goals for scholar
(define-public (set-scholar-goal 
    (scholar principal) 
    (goal-description (string-ascii 100)) 
    (target-metric uint) 
    (deadline uint) 
    (reward-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> target-metric u0) err-invalid-parameters)
        (asserts! (> deadline block-height) err-invalid-parameters)
        
        (var-set goal-counter (+ (var-get goal-counter) u1))
        (map-set scholar-goals 
            {scholar: scholar, goal-id: (var-get goal-counter)}
            {goal-description: goal-description,
             target-metric: target-metric,
             current-progress: u0,
             deadline: deadline,
             reward-amount: reward-amount,
             is-achieved: false})
        
        (ok (var-get goal-counter))))

;; Update goal progress and check achievement
(define-public (update-goal-progress (scholar principal) (goal-id uint) (current-progress uint))
    (let ((goal (unwrap! (map-get? scholar-goals {scholar: scholar, goal-id: goal-id}) err-not-found)))
        
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get is-achieved goal)) err-already-exists)
        (asserts! (< block-height (get deadline goal)) err-invalid-parameters)
        
        (let ((is-achieved (>= current-progress (get target-metric goal))))
            (map-set scholar-goals 
                {scholar: scholar, goal-id: goal-id}
                (merge goal {current-progress: current-progress,
                           is-achieved: is-achieved}))
            
            ;; If goal achieved, transfer reward
            (if is-achieved
                (begin
                    (try! (as-contract (stx-transfer? (get reward-amount goal) 
                                                    (as-contract tx-sender) 
                                                    scholar)))
                    (ok {achieved: true, reward: (get reward-amount goal)}))
                (ok {achieved: false, reward: u0})))))

;; Helper function to calculate overall rating
(define-private (calculate-overall-rating 
    (academic uint) 
    (attendance uint) 
    (community uint) 
    (research uint) 
    (leadership uint))
    (let ((weighted-score (+ (* academic u40)  ;; 40% weight
                           (* attendance u25)  ;; 25% weight
                           (* community u15)   ;; 15% weight
                           (* research u10)    ;; 10% weight
                           (* leadership u10)))) ;; 10% weight
        (/ weighted-score u100)))

;; Helper function to calculate performance multiplier
(define-private (calculate-performance-multiplier (rating uint))
    (if (>= rating excellent-threshold) u150
        (if (>= rating good-threshold) u125
            (if (>= rating minimum-threshold) u100
                (if (>= rating penalty-threshold) u75
                    u50)))))

;; Helper function to calculate improvement factor
(define-private (calculate-improvement-factor (scholar principal) (current-score uint))
    (let ((last-period (- (/ (- block-height 
                              (get vesting-start (default-to 
                                  {total-allocation: u0, released-amount: u0, locked-amount: u0, 
                                   vesting-start: block-height, vesting-duration: u0, 
                                   performance-multiplier: u100, last-evaluation: block-height, status: "active"}
                                  (map-get? scholar-vesting-schedule scholar)))) 
                           monthly-vesting) u1))
          (previous-performance (map-get? performance-history {scholar: scholar, evaluation-period: last-period})))
        (match previous-performance
            some-perf (if (> current-score (get academic-score some-perf))
                        (+ u100 (- current-score (get academic-score some-perf)))
                        u100)
            u100)))

;; Helper function to calculate performance bonus
(define-private (calculate-performance-bonus (rating uint))
    (if (>= rating excellent-threshold) u50000
        (if (>= rating good-threshold) u25000
            u0)))

;; Helper function to check acceleration eligibility
(define-private (check-acceleration-eligibility (scholar principal) (rating uint))
    (let ((acceleration (unwrap! (map-get? acceleration-eligibility scholar) err-not-found)))
        (if (>= rating excellent-threshold)
            (let ((new-consecutive (+ (get consecutive-excellent-evaluations acceleration) u1)))
                (map-set acceleration-eligibility scholar
                    (merge acceleration 
                        {consecutive-excellent-evaluations: new-consecutive,
                         acceleration-factor: (if (>= new-consecutive u3) u150 u100),
                         next-acceleration-check: (+ block-height quarterly-vesting)}))
                (ok true))
            (begin
                (map-set acceleration-eligibility scholar
                    (merge acceleration {consecutive-excellent-evaluations: u0}))
                (ok false)))))

;; Read-only functions
(define-read-only (get-scholar-vesting-info (scholar principal))
    (map-get? scholar-vesting-schedule scholar))

(define-read-only (get-scholar-performance (scholar principal))
    (map-get? scholar-performance-metrics scholar))

(define-read-only (get-performance-history (scholar principal) (period uint))
    (map-get? performance-history {scholar: scholar, evaluation-period: period}))

(define-read-only (get-acceleration-status (scholar principal))
    (map-get? acceleration-eligibility scholar))

(define-read-only (get-scholar-goals (scholar principal) (goal-id uint))
    (map-get? scholar-goals {scholar: scholar, goal-id: goal-id}))

(define-read-only (get-reward-pool-info (pool-id uint))
    (map-get? reward-pools pool-id))

(define-read-only (get-contract-stats)
    (ok {total-vesting-funds: (var-get total-vesting-funds),
         active-accounts: (var-get active-vesting-accounts),
         evaluators-count: (var-get performance-evaluators-count),
         reward-pools-count: (var-get reward-pool-counter),
         goals-count: (var-get goal-counter)}))

(define-read-only (is-performance-evaluator (evaluator principal))
    (default-to false (map-get? performance-evaluators evaluator)))

