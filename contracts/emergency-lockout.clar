;; Emergency Lockout Service Contract
;; Coordinates 24/7 locksmith services for emergencies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-ALREADY-EXISTS (err u401))
(define-constant ERR-NOT-FOUND (err u402))
(define-constant ERR-INVALID-INPUT (err u403))
(define-constant ERR-SERVICE-UNAVAILABLE (err u404))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u405))
(define-constant ERR-REQUEST-EXPIRED (err u406))

;; Service types
(define-constant SERVICE-RESIDENTIAL-LOCKOUT u1)
(define-constant SERVICE-COMMERCIAL-LOCKOUT u2)
(define-constant SERVICE-AUTOMOTIVE-LOCKOUT u3)
(define-constant SERVICE-SAFE-LOCKOUT u4)

;; Request status
(define-constant STATUS-PENDING u1)
(define-constant STATUS-ASSIGNED u2)
(define-constant STATUS-IN-PROGRESS u3)
(define-constant STATUS-COMPLETED u4)
(define-constant STATUS-CANCELLED u5)

;; Priority levels
(define-constant PRIORITY-LOW u1)
(define-constant PRIORITY-MEDIUM u2)
(define-constant PRIORITY-HIGH u3)
(define-constant PRIORITY-EMERGENCY u4)

;; Data Variables
(define-data-var base-service-fee uint u500000) ;; 0.5 STX
(define-data-var emergency-surcharge uint u250000) ;; 0.25 STX additional
(define-data-var max-response-time uint u3600) ;; 1 hour in seconds
(define-data-var service-radius uint u50) ;; 50 km radius

;; Data Maps
(define-map service-providers
  { provider: principal }
  {
    name: (string-ascii 100),
    phone: (string-ascii 20),
    service-area: (string-ascii 200),
    available: bool,
    current-location: (string-ascii 200),
    rating: uint,
    total-jobs: uint,
    response-time-avg: uint
  }
)

(define-map emergency-requests
  { request-id: uint }
  {
    customer: principal,
    service-type: uint,
    priority: uint,
    location: (string-ascii 200),
    description: (string-ascii 300),
    contact-info: (string-ascii 100),
    timestamp: uint,
    status: uint,
    assigned-provider: (optional principal),
    estimated-arrival: (optional uint),
    completion-time: (optional uint)
  }
)

(define-map service-history
  { provider: principal, request-id: uint }
  {
    service-type: uint,
    start-time: uint,
    completion-time: uint,
    customer-rating: uint,
    payment-amount: uint,
    notes: (string-ascii 300)
  }
)

(define-data-var next-request-id uint u1)

;; Public Functions

;; Register as emergency service provider
(define-public (register-service-provider
  (name (string-ascii 100))
  (phone (string-ascii 20))
  (service-area (string-ascii 200))
  (current-location (string-ascii 200))
)
  (let (
    (provider tx-sender)
  )
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len phone) u0) ERR-INVALID-INPUT)
    (asserts! (> (len service-area) u0) ERR-INVALID-INPUT)
    (asserts! (> (len current-location) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? service-providers { provider: provider })) ERR-ALREADY-EXISTS)

    (map-set service-providers
      { provider: provider }
      {
        name: name,
        phone: phone,
        service-area: service-area,
        available: true,
        current-location: current-location,
        rating: u5,
        total-jobs: u0,
        response-time-avg: u0
      }
    )

    (ok true)
  )
)

;; Request emergency lockout service
(define-public (request-emergency-service
  (service-type uint)
  (priority uint)
  (location (string-ascii 200))
  (description (string-ascii 300))
  (contact-info (string-ascii 100))
)
  (let (
    (customer tx-sender)
    (request-id (var-get next-request-id))
    (current-time block-height)
    (service-fee (if (is-eq priority PRIORITY-EMERGENCY)
                    (+ (var-get base-service-fee) (var-get emergency-surcharge))
                    (var-get base-service-fee)))
  )
    (asserts! (and (>= service-type u1) (<= service-type u4)) ERR-INVALID-INPUT)
    (asserts! (and (>= priority u1) (<= priority u4)) ERR-INVALID-INPUT)
    (asserts! (> (len location) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> (len contact-info) u0) ERR-INVALID-INPUT)
    (asserts! (>= (stx-get-balance tx-sender) service-fee) ERR-INSUFFICIENT-PAYMENT)

    (try! (stx-transfer? service-fee tx-sender CONTRACT-OWNER))

    (map-set emergency-requests
      { request-id: request-id }
      {
        customer: customer,
        service-type: service-type,
        priority: priority,
        location: location,
        description: description,
        contact-info: contact-info,
        timestamp: current-time,
        status: STATUS-PENDING,
        assigned-provider: none,
        estimated-arrival: none,
        completion-time: none
      }
    )

    (var-set next-request-id (+ request-id u1))

    (ok request-id)
  )
)

;; Accept emergency service request
(define-public (accept-service-request (request-id uint) (estimated-arrival-minutes uint))
  (let (
    (provider tx-sender)
    (request-data (unwrap! (map-get? emergency-requests { request-id: request-id }) ERR-NOT-FOUND))
    (provider-data (unwrap! (map-get? service-providers { provider: provider }) ERR-NOT-FOUND))
    (current-time block-height)
    (estimated-arrival (+ current-time (* estimated-arrival-minutes u60)))
  )
    (asserts! (get available provider-data) ERR-SERVICE-UNAVAILABLE)
    (asserts! (is-eq (get status request-data) STATUS-PENDING) ERR-INVALID-INPUT)
    (asserts! (> estimated-arrival-minutes u0) ERR-INVALID-INPUT)
    (asserts! (<= (* estimated-arrival-minutes u60) (var-get max-response-time)) ERR-INVALID-INPUT)

    (map-set emergency-requests
      { request-id: request-id }
      (merge request-data {
        status: STATUS-ASSIGNED,
        assigned-provider: (some provider),
        estimated-arrival: (some estimated-arrival)
      })
    )

    (map-set service-providers
      { provider: provider }
      (merge provider-data { available: false })
    )

    (ok true)
  )
)

;; Start service
(define-public (start-service (request-id uint))
  (let (
    (provider tx-sender)
    (request-data (unwrap! (map-get? emergency-requests { request-id: request-id }) ERR-NOT-FOUND))
    (current-time block-height)
  )
    (asserts! (is-eq (some provider) (get assigned-provider request-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) STATUS-ASSIGNED) ERR-INVALID-INPUT)

    (map-set emergency-requests
      { request-id: request-id }
      (merge request-data { status: STATUS-IN-PROGRESS })
    )

    (ok true)
  )
)

;; Complete service
(define-public (complete-service (request-id uint) (notes (string-ascii 300)))
  (let (
    (provider tx-sender)
    (request-data (unwrap! (map-get? emergency-requests { request-id: request-id }) ERR-NOT-FOUND))
    (provider-data (unwrap! (map-get? service-providers { provider: provider }) ERR-NOT-FOUND))
    (current-time block-height)
    (service-duration (- current-time (get timestamp request-data)))
  )
    (asserts! (is-eq (some provider) (get assigned-provider request-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) STATUS-IN-PROGRESS) ERR-INVALID-INPUT)
    (asserts! (> (len notes) u0) ERR-INVALID-INPUT)

    (map-set emergency-requests
      { request-id: request-id }
      (merge request-data {
        status: STATUS-COMPLETED,
        completion-time: (some current-time)
      })
    )

    (map-set service-history
      { provider: provider, request-id: request-id }
      {
        service-type: (get service-type request-data),
        start-time: (get timestamp request-data),
        completion-time: current-time,
        customer-rating: u0,
        payment-amount: (if (is-eq (get priority request-data) PRIORITY-EMERGENCY)
                          (+ (var-get base-service-fee) (var-get emergency-surcharge))
                          (var-get base-service-fee)),
        notes: notes
      }
    )

    (map-set service-providers
      { provider: provider }
      (merge provider-data {
        available: true,
        total-jobs: (+ (get total-jobs provider-data) u1)
      })
    )

    (ok true)
  )
)

;; Rate service provider
(define-public (rate-service (request-id uint) (rating uint))
  (let (
    (customer tx-sender)
    (request-data (unwrap! (map-get? emergency-requests { request-id: request-id }) ERR-NOT-FOUND))
    (provider (unwrap! (get assigned-provider request-data) ERR-NOT-FOUND))
    (service-data (unwrap! (map-get? service-history { provider: provider, request-id: request-id }) ERR-NOT-FOUND))
    (provider-data (unwrap! (map-get? service-providers { provider: provider }) ERR-NOT-FOUND))
  )
    (asserts! (is-eq customer (get customer request-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) STATUS-COMPLETED) ERR-INVALID-INPUT)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-INPUT)
    (asserts! (is-eq (get customer-rating service-data) u0) ERR-ALREADY-EXISTS)

    (map-set service-history
      { provider: provider, request-id: request-id }
      (merge service-data { customer-rating: rating })
    )

    ;; Update provider's average rating
    (let (
      (total-jobs (get total-jobs provider-data))
      (current-rating (get rating provider-data))
      (new-rating (/ (+ (* current-rating total-jobs) rating) (+ total-jobs u1)))
    )
      (map-set service-providers
        { provider: provider }
        (merge provider-data { rating: new-rating })
      )
    )

    (ok true)
  )
)

;; Update provider availability
(define-public (update-availability (available bool) (current-location (string-ascii 200)))
  (let (
    (provider tx-sender)
    (provider-data (unwrap! (map-get? service-providers { provider: provider }) ERR-NOT-FOUND))
  )
    (asserts! (> (len current-location) u0) ERR-INVALID-INPUT)

    (map-set service-providers
      { provider: provider }
      (merge provider-data {
        available: available,
        current-location: current-location
      })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get service provider details
(define-read-only (get-service-provider (provider principal))
  (map-get? service-providers { provider: provider })
)

;; Get emergency request details
(define-read-only (get-emergency-request (request-id uint))
  (map-get? emergency-requests { request-id: request-id })
)

;; Get service history
(define-read-only (get-service-history (provider principal) (request-id uint))
  (map-get? service-history { provider: provider, request-id: request-id })
)

;; Check if provider is available
(define-read-only (is-provider-available (provider principal))
  (match (map-get? service-providers { provider: provider })
    provider-data (get available provider-data)
    false
  )
)

;; Get current service fees
(define-read-only (get-base-service-fee)
  (var-get base-service-fee)
)

(define-read-only (get-emergency-surcharge)
  (var-get emergency-surcharge)
)

(define-read-only (get-max-response-time)
  (var-get max-response-time)
)
