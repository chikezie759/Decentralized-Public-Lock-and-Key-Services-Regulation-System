;; Key Cutting Certification Contract
;; Manages licenses for key duplication and lock installation services

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-ALREADY-CERTIFIED (err u201))
(define-constant ERR-NOT-FOUND (err u202))
(define-constant ERR-INVALID-INPUT (err u203))
(define-constant ERR-CERTIFICATION-EXPIRED (err u204))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u205))
(define-constant ERR-EQUIPMENT-NOT-CERTIFIED (err u206))

;; Certification levels
(define-constant CERT-BASIC u1)
(define-constant CERT-ADVANCED u2)
(define-constant CERT-MASTER u3)

;; Key types
(define-constant KEY-RESIDENTIAL u1)
(define-constant KEY-COMMERCIAL u2)
(define-constant KEY-HIGH-SECURITY u3)
(define-constant KEY-AUTOMOTIVE u4)

;; Equipment status
(define-constant EQUIPMENT-ACTIVE u1)
(define-constant EQUIPMENT-MAINTENANCE u2)
(define-constant EQUIPMENT-RETIRED u3)

;; Data Variables
(define-data-var certification-fee uint u750000) ;; 0.75 STX
(define-data-var equipment-registration-fee uint u250000) ;; 0.25 STX
(define-data-var certification-duration uint u15768000) ;; 6 months in seconds

;; Data Maps
(define-map certifications
  { operator: principal }
  {
    name: (string-ascii 100),
    certification-level: uint,
    authorized-key-types: (list 10 uint),
    issue-date: uint,
    expiry-date: uint,
    training-hours: uint,
    practical-tests-passed: uint
  }
)

(define-map equipment-registry
  { operator: principal, equipment-id: (string-ascii 50) }
  {
    equipment-type: (string-ascii 100),
    manufacturer: (string-ascii 100),
    model: (string-ascii 100),
    serial-number: (string-ascii 100),
    certification-date: uint,
    last-maintenance: uint,
    status: uint
  }
)

(define-map key-cutting-records
  { operator: principal, record-id: uint }
  {
    key-type: uint,
    quantity: uint,
    customer-id: (string-ascii 100),
    timestamp: uint,
    equipment-used: (string-ascii 50)
  }
)

(define-data-var next-record-id uint u1)

;; Public Functions

;; Apply for key cutting certification
(define-public (apply-for-certification
  (name (string-ascii 100))
  (certification-level uint)
  (training-hours uint)
  (key-types (list 10 uint))
)
  (let (
    (operator tx-sender)
    (current-time block-height)
    (expiry-time (+ current-time (var-get certification-duration)))
  )
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= certification-level u1) (<= certification-level u3)) ERR-INVALID-INPUT)
    (asserts! (> training-hours u0) ERR-INVALID-INPUT)
    (asserts! (> (len key-types) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? certifications { operator: operator })) ERR-ALREADY-CERTIFIED)
    (asserts! (>= (stx-get-balance tx-sender) (var-get certification-fee)) ERR-INSUFFICIENT-PAYMENT)

    (try! (stx-transfer? (var-get certification-fee) tx-sender CONTRACT-OWNER))

    (map-set certifications
      { operator: operator }
      {
        name: name,
        certification-level: certification-level,
        authorized-key-types: key-types,
        issue-date: current-time,
        expiry-date: expiry-time,
        training-hours: training-hours,
        practical-tests-passed: u0
      }
    )

    (ok true)
  )
)

;; Register key cutting equipment
(define-public (register-equipment
  (equipment-id (string-ascii 50))
  (equipment-type (string-ascii 100))
  (manufacturer (string-ascii 100))
  (model (string-ascii 100))
  (serial-number (string-ascii 100))
)
  (let (
    (operator tx-sender)
    (current-time block-height)
  )
    (asserts! (> (len equipment-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len equipment-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len manufacturer) u0) ERR-INVALID-INPUT)
    (asserts! (> (len model) u0) ERR-INVALID-INPUT)
    (asserts! (> (len serial-number) u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? certifications { operator: operator })) ERR-NOT-FOUND)
    (asserts! (>= (stx-get-balance tx-sender) (var-get equipment-registration-fee)) ERR-INSUFFICIENT-PAYMENT)

    (try! (stx-transfer? (var-get equipment-registration-fee) tx-sender CONTRACT-OWNER))

    (map-set equipment-registry
      { operator: operator, equipment-id: equipment-id }
      {
        equipment-type: equipment-type,
        manufacturer: manufacturer,
        model: model,
        serial-number: serial-number,
        certification-date: current-time,
        last-maintenance: current-time,
        status: EQUIPMENT-ACTIVE
      }
    )

    (ok true)
  )
)

;; Record key cutting activity
(define-public (record-key-cutting
  (key-type uint)
  (quantity uint)
  (customer-id (string-ascii 100))
  (equipment-id (string-ascii 50))
)
  (let (
    (operator tx-sender)
    (current-time block-height)
    (record-id (var-get next-record-id))
    (cert-data (unwrap! (map-get? certifications { operator: operator }) ERR-NOT-FOUND))
    (equipment-data (unwrap! (map-get? equipment-registry { operator: operator, equipment-id: equipment-id }) ERR-EQUIPMENT-NOT-CERTIFIED))
  )
    (asserts! (and (>= key-type u1) (<= key-type u4)) ERR-INVALID-INPUT)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    (asserts! (> (len customer-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len equipment-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (get expiry-date cert-data) current-time) ERR-CERTIFICATION-EXPIRED)
    (asserts! (is-eq (get status equipment-data) EQUIPMENT-ACTIVE) ERR-EQUIPMENT-NOT-CERTIFIED)

    ;; Check if operator is authorized for this key type
    (asserts! (is-some (index-of (get authorized-key-types cert-data) key-type)) ERR-NOT-AUTHORIZED)

    (map-set key-cutting-records
      { operator: operator, record-id: record-id }
      {
        key-type: key-type,
        quantity: quantity,
        customer-id: customer-id,
        timestamp: current-time,
        equipment-used: equipment-id
      }
    )

    (var-set next-record-id (+ record-id u1))

    (ok record-id)
  )
)

;; Update equipment maintenance
(define-public (update-equipment-maintenance (equipment-id (string-ascii 50)))
  (let (
    (operator tx-sender)
    (current-time block-height)
    (equipment-data (unwrap! (map-get? equipment-registry { operator: operator, equipment-id: equipment-id }) ERR-NOT-FOUND))
  )
    (map-set equipment-registry
      { operator: operator, equipment-id: equipment-id }
      (merge equipment-data { last-maintenance: current-time })
    )

    (ok true)
  )
)

;; Renew certification
(define-public (renew-certification (additional-training-hours uint))
  (let (
    (operator tx-sender)
    (current-time block-height)
    (new-expiry (+ current-time (var-get certification-duration)))
    (cert-data (unwrap! (map-get? certifications { operator: operator }) ERR-NOT-FOUND))
  )
    (asserts! (>= (stx-get-balance tx-sender) (var-get certification-fee)) ERR-INSUFFICIENT-PAYMENT)

    (try! (stx-transfer? (var-get certification-fee) tx-sender CONTRACT-OWNER))

    (map-set certifications
      { operator: operator }
      (merge cert-data {
        expiry-date: new-expiry,
        training-hours: (+ (get training-hours cert-data) additional-training-hours)
      })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get certification details
(define-read-only (get-certification (operator principal))
  (map-get? certifications { operator: operator })
)

;; Check if certification is valid
(define-read-only (is-certification-valid (operator principal))
  (match (map-get? certifications { operator: operator })
    cert-data
    (let (
      (current-time block-height)
    )
      (> (get expiry-date cert-data) current-time)
    )
    false
  )
)

;; Get equipment details
(define-read-only (get-equipment (operator principal) (equipment-id (string-ascii 50)))
  (map-get? equipment-registry { operator: operator, equipment-id: equipment-id })
)

;; Get key cutting record
(define-read-only (get-key-cutting-record (operator principal) (record-id uint))
  (map-get? key-cutting-records { operator: operator, record-id: record-id })
)

;; Check if operator can cut specific key type
(define-read-only (can-cut-key-type (operator principal) (key-type uint))
  (match (map-get? certifications { operator: operator })
    cert-data
    (let (
      (current-time block-height)
    )
      (and
        (> (get expiry-date cert-data) current-time)
        (is-some (index-of (get authorized-key-types cert-data) key-type))
      )
    )
    false
  )
)

;; Get current fees
(define-read-only (get-certification-fee)
  (var-get certification-fee)
)

(define-read-only (get-equipment-registration-fee)
  (var-get equipment-registration-fee)
)
