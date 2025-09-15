;; Alumni Impact Tracker & Network System
;; Tracks scholarship program effectiveness and connects alumni for mentorship

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u600))
(define-constant ERR-INVALID-DATA (err u601))
(define-constant ERR-NOT-FOUND (err u602))
(define-constant ERR-ALREADY-EXISTS (err u603))
(define-constant ERR-INSUFFICIENT-FUNDS (err u604))

;; Impact tracking constants
(define-constant EMPLOYMENT-BONUS u100)
(define-constant LEADERSHIP-BONUS u150)
(define-constant COMMUNITY-BONUS u75)
(define-constant GIVING-BACK-MULTIPLIER u200)

;; Alumni career outcome tracking
(define-map alumni-careers
    principal
    {
        graduation-year: uint,
        field-of-study: (string-ascii 30),
        current-employer: (string-ascii 50),
        job-title: (string-ascii 40),
        annual-salary: uint,
        employment-status: (string-ascii 20), ;; "employed", "entrepreneur", "graduate-school"
        career-progression: uint, ;; Score based on advancement
        last-updated: uint
    }
)

;; Long-term impact metrics
(define-map alumni-impact-metrics
    principal
    {
        total-giving-back: uint,
        mentorship-hours: uint,
        community-projects: uint,
        leadership-positions: uint,
        awards-received: uint,
        impact-score: uint,
        impact-tier: (string-ascii 15) ;; "bronze", "silver", "gold", "platinum"
    }
)

;; Mentorship connections
(define-map mentorship-connections
    {mentor: principal, mentee: principal}
    {
        start-date: uint,
        field-match: (string-ascii 30),
        meeting-frequency: uint,
        connection-status: (string-ascii 15), ;; "active", "completed", "paused"
        success-rating: uint
    }
)

;; Alumni network events
(define-map network-events
    uint
    {
        event-title: (string-ascii 50),
        event-type: (string-ascii 20), ;; "networking", "mentorship", "workshop"
        organizer: principal,
        participant-count: uint,
        date: uint,
        impact-rating: uint
    }
)

;; Giving back tracking
(define-map alumni-contributions
    principal
    {
        total-monetary: uint,
        total-volunteer-hours: uint,
        scholarships-sponsored: uint,
        last-contribution: uint,
        lifetime-value: uint
    }
)

;; Data variables
(define-data-var total-alumni-count uint u0)
(define-data-var average-career-progression uint u0)
(define-data-var total-alumni-contributions uint u0)
(define-data-var event-counter uint u0)

;; Read-only functions
(define-read-only (get-alumni-career (alumni principal))
    (map-get? alumni-careers alumni)
)

(define-read-only (get-alumni-impact (alumni principal))
    (map-get? alumni-impact-metrics alumni)
)

(define-read-only (get-mentorship-status (mentor principal) (mentee principal))
    (map-get? mentorship-connections {mentor: mentor, mentee: mentee})
)

(define-read-only (get-alumni-contributions (alumni principal))
    (map-get? alumni-contributions alumni)
)

(define-read-only (get-network-event (event-id uint))
    (map-get? network-events event-id)
)

;; Register alumni with career information
(define-public (register-alumni-career
    (alumni principal)
    (graduation-year uint)
    (field-of-study (string-ascii 30))
    (employer (string-ascii 50))
    (job-title (string-ascii 40))
    (salary uint)
    (status (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> graduation-year u2000) ERR-INVALID-DATA)
        (asserts! (> salary u0) ERR-INVALID-DATA)
        
        (map-set alumni-careers alumni {
            graduation-year: graduation-year,
            field-of-study: field-of-study,
            current-employer: employer,
            job-title: job-title,
            annual-salary: salary,
            employment-status: status,
            career-progression: (calculate-career-progression-score salary status),
            last-updated: block-height
        })
        
        (map-set alumni-impact-metrics alumni {
            total-giving-back: u0,
            mentorship-hours: u0,
            community-projects: u0,
            leadership-positions: u0,
            awards-received: u0,
            impact-score: EMPLOYMENT-BONUS,
            impact-tier: "bronze"
        })
        
        (var-set total-alumni-count (+ (var-get total-alumni-count) u1))
        (ok true)
    )
)

;; Update career progression
(define-public (update-career-info
    (alumni principal)
    (new-employer (string-ascii 50))
    (new-title (string-ascii 40))
    (new-salary uint)
    (new-status (string-ascii 20)))
    (let ((current-career (unwrap! (map-get? alumni-careers alumni) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> new-salary u0) ERR-INVALID-DATA)
        
        (map-set alumni-careers alumni 
            (merge current-career {
                current-employer: new-employer,
                job-title: new-title,
                annual-salary: new-salary,
                employment-status: new-status,
                career-progression: (calculate-career-progression-score new-salary new-status),
                last-updated: block-height
            })
        )
        (ok true)
    )
)

;; Record alumni giving back to the scholarship fund
(define-public (record-alumni-contribution
    (alumni principal)
    (monetary-amount uint)
    (volunteer-hours uint)
    (scholarships-sponsored uint))
    (let ((current-contributions (default-to 
            {total-monetary: u0, total-volunteer-hours: u0, scholarships-sponsored: u0, 
             last-contribution: u0, lifetime-value: u0}
            (map-get? alumni-contributions alumni)))
          (current-impact (unwrap! (map-get? alumni-impact-metrics alumni) ERR-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Update contribution tracking
        (map-set alumni-contributions alumni {
            total-monetary: (+ (get total-monetary current-contributions) monetary-amount),
            total-volunteer-hours: (+ (get total-volunteer-hours current-contributions) volunteer-hours),
            scholarships-sponsored: (+ (get scholarships-sponsored current-contributions) scholarships-sponsored),
            last-contribution: block-height,
            lifetime-value: (calculate-lifetime-value 
                (+ (get total-monetary current-contributions) monetary-amount)
                (+ (get total-volunteer-hours current-contributions) volunteer-hours))
        })
        
        ;; Update impact metrics
        (let ((giving-back-bonus (* monetary-amount GIVING-BACK-MULTIPLIER))
              (new-impact-score (+ (get impact-score current-impact) giving-back-bonus)))
            (map-set alumni-impact-metrics alumni
                (merge current-impact {
                    total-giving-back: (+ (get total-giving-back current-impact) monetary-amount),
                    impact-score: new-impact-score,
                    impact-tier: (calculate-impact-tier new-impact-score)
                })
            )
        )
        
        (var-set total-alumni-contributions (+ (var-get total-alumni-contributions) monetary-amount))
        (ok true)
    )
)

;; Create mentorship connection
(define-public (create-mentorship-connection
    (mentor principal)
    (mentee principal)
    (field-match (string-ascii 30))
    (meeting-frequency uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? mentorship-connections {mentor: mentor, mentee: mentee})) ERR-ALREADY-EXISTS)
        (asserts! (> meeting-frequency u0) ERR-INVALID-DATA)
        
        (map-set mentorship-connections {mentor: mentor, mentee: mentee} {
            start-date: block-height,
            field-match: field-match,
            meeting-frequency: meeting-frequency,
            connection-status: "active",
            success-rating: u0
        })
        (ok true)
    )
)

;; Update mentorship progress
(define-public (update-mentorship-progress
    (mentor principal)
    (mentee principal)
    (hours-logged uint)
    (success-rating uint)
    (status (string-ascii 15)))
    (let ((connection (unwrap! (map-get? mentorship-connections {mentor: mentor, mentee: mentee}) ERR-NOT-FOUND))
          (mentor-impact (unwrap! (map-get? alumni-impact-metrics mentor) ERR-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= success-rating u100) ERR-INVALID-DATA)
        
        ;; Update connection status
        (map-set mentorship-connections {mentor: mentor, mentee: mentee}
            (merge connection {
                connection-status: status,
                success-rating: success-rating
            })
        )
        
        ;; Update mentor's impact metrics
        (map-set alumni-impact-metrics mentor
            (merge mentor-impact {
                mentorship-hours: (+ (get mentorship-hours mentor-impact) hours-logged),
                impact-score: (+ (get impact-score mentor-impact) (/ hours-logged u2))
            })
        )
        
        (ok true)
    )
)

;; Organize alumni network event
(define-public (organize-network-event
    (title (string-ascii 50))
    (event-type (string-ascii 20))
    (organizer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set event-counter (+ (var-get event-counter) u1))
        
        (map-set network-events (var-get event-counter) {
            event-title: title,
            event-type: event-type,
            organizer: organizer,
            participant-count: u0,
            date: block-height,
            impact-rating: u0
        })
        
        (ok (var-get event-counter))
    )
)

;; Track event participation and impact
(define-public (update-event-impact
    (event-id uint)
    (participant-count uint)
    (impact-rating uint))
    (let ((event (unwrap! (map-get? network-events event-id) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= impact-rating u100) ERR-INVALID-DATA)
        
        (map-set network-events event-id
            (merge event {
                participant-count: participant-count,
                impact-rating: impact-rating
            })
        )
        (ok true)
    )
)

;; Generate program impact report
(define-read-only (generate-impact-report)
    (ok {
        total-alumni: (var-get total-alumni-count),
        average-career-progression: (var-get average-career-progression),
        total-alumni-giving: (var-get total-alumni-contributions),
        total-events: (var-get event-counter),
        program-effectiveness: (calculate-program-effectiveness)
    })
)

;; Helper function to calculate career progression score
(define-private (calculate-career-progression-score (salary uint) (status (string-ascii 20)))
    (let ((base-score (/ salary u10000))) ;; Base score from salary
        (if (is-eq status "entrepreneur") (+ base-score u50)
            (if (is-eq status "graduate-school") (+ base-score u30)
                (if (is-eq status "employed") (+ base-score u20)
                    base-score)))
    )
)

;; Helper function to calculate impact tier
(define-private (calculate-impact-tier (score uint))
    (if (>= score u1000) "platinum"
        (if (>= score u500) "gold"
            (if (>= score u200) "silver" "bronze")))
)

;; Helper function to calculate lifetime value
(define-private (calculate-lifetime-value (monetary uint) (volunteer-hours uint))
    (+ monetary (* volunteer-hours u50)) ;; $50 value per volunteer hour
)

;; Helper function to calculate program effectiveness
(define-private (calculate-program-effectiveness)
    (let ((alumni-count (var-get total-alumni-count)))
        (if (> alumni-count u0)
            (+ (/ (var-get total-alumni-contributions) alumni-count)
               (/ (var-get average-career-progression) u10))
            u0)
    )
)
