;; Maritime Trading Platform Smart Contract

;; Constants
(define-constant contract-administrator tx-sender)
(define-constant ERR_ADMINISTRATOR_ONLY (err u100))
(define-constant ERR_VESSEL_NOT_REGISTERED (err u101))
(define-constant ERR_INVALID_COORDINATES (err u102))
(define-constant ERR_TRADE_ALREADY_EXISTS (err u103))
(define-constant ERR_UNAUTHORIZED_ACCESS (err u104))
(define-constant ERR_INVALID_INPUT_PARAMETER (err u105))
(define-constant ERR_DUPLICATE_VESSEL_ID (err u106))

;; Input Validation Functions
(define-private (validate-identifier-length (identifier-string (string-utf8 36)))
    (and 
        (>= (len identifier-string) u1)
        (<= (len identifier-string) u36)
    )
)

(define-private (validate-registration-number (registration-number (string-utf8 50)))
    (and 
        (>= (len registration-number) u5)
        (<= (len registration-number) u50)
    )
)

(define-private (validate-vessel-category (vessel-category (string-utf8 20)))
    (and 
        (>= (len vessel-category) u2)
        (<= (len vessel-category) u20)
    )
)

(define-private (validate-cargo-category (cargo-category (string-utf8 50)))
    (and 
        (>= (len cargo-category) u2)
        (<= (len cargo-category) u50)
    )
)

;; Data Variables
(define-map registered-vessels
    { vessel-identifier: (string-utf8 36) }
    {
        vessel-owner: principal,
        vessel-registration: (string-utf8 50),
        vessel-category: (string-utf8 20),
        cargo-capacity: uint,
        vessel-position: {latitude: int, longitude: int},
        operational-status: bool
    }
)

(define-map vessel-ownership-registry 
    { vessel-owner: principal } 
    { vessel-identifier: (string-utf8 36) }
)

(define-map maritime-trade-contracts
    { trade-identifier: (string-utf8 36) }
    {
        selling-party: principal,
        buying-party: principal,
        cargo-category: (string-utf8 50),
        cargo-quantity: uint,
        contract-price: uint,
        contract-status: (string-utf8 20),
        delivery-location: {latitude: int, longitude: int},
        customs-clearance: bool
    }
)

;; Implement maritime-trade-trait
(impl-trait .maritime-trade-trait.maritime-trade-trait)

;; Public Functions
(define-public (register-maritime-vessel 
    (vessel-identifier (string-utf8 36))
    (vessel-registration (string-utf8 50))
    (vessel-category (string-utf8 20))
    (cargo-capacity uint))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERR_ADMINISTRATOR_ONLY)
        (asserts! (validate-identifier-length vessel-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-registration-number vessel-registration) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-vessel-category vessel-category) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (> cargo-capacity u0) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (is-none (map-get? registered-vessels {vessel-identifier: vessel-identifier})) ERR_DUPLICATE_VESSEL_ID)
        
        (map-set registered-vessels
            {vessel-identifier: vessel-identifier}
            {
                vessel-owner: tx-sender,
                vessel-registration: vessel-registration,
                vessel-category: vessel-category,
                cargo-capacity: cargo-capacity,
                vessel-position: {latitude: 0, longitude: 0},
                operational-status: true
            }
        )
        (map-set vessel-ownership-registry 
            {vessel-owner: tx-sender} 
            {vessel-identifier: vessel-identifier}
        )
        (ok true)
    )
)

(define-public (create-trade-contract
    (trade-identifier (string-utf8 36))
    (buying-party principal)
    (cargo-category (string-utf8 50))
    (cargo-quantity uint)
    (contract-price uint)
    (delivery-latitude int)
    (delivery-longitude int))
    (let
        ((selling-party tx-sender))
        (asserts! (validate-identifier-length trade-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-cargo-category cargo-category) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (and (> cargo-quantity u0) (> contract-price u0)) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (and 
            (>= delivery-latitude (* -90 1000000))
            (<= delivery-latitude (* 90 1000000))
            (>= delivery-longitude (* -180 1000000))
            (<= delivery-longitude (* 180 1000000))
        ) ERR_INVALID_COORDINATES)
        (asserts! (is-some (get-vessel-by-owner selling-party)) ERR_VESSEL_NOT_REGISTERED)
        (asserts! (is-some (get-vessel-by-owner buying-party)) ERR_VESSEL_NOT_REGISTERED)
        (asserts! (is-none (map-get? maritime-trade-contracts {trade-identifier: trade-identifier})) ERR_TRADE_ALREADY_EXISTS)
        
        (ok (map-set maritime-trade-contracts
            {trade-identifier: trade-identifier}
            {
                selling-party: selling-party,
                buying-party: buying-party,
                cargo-category: cargo-category,
                cargo-quantity: cargo-quantity,
                contract-price: contract-price,
                contract-status: u"pending",
                delivery-location: {
                    latitude: delivery-latitude,
                    longitude: delivery-longitude
                },
                customs-clearance: false
            }
        ))
    )
)

;; Required by maritime-trade-trait
(define-public (get-trade-agreement (trade-identifier (string-utf8 36)))
    (begin
        (asserts! (validate-identifier-length trade-identifier) ERR_INVALID_INPUT_PARAMETER)
        (ok (map-get? maritime-trade-contracts {trade-identifier: trade-identifier}))
    )
)

(define-public (update-vessel-location 
    (vessel-identifier (string-utf8 36))
    (updated-latitude int)
    (updated-longitude int))
    (begin
        (asserts! (validate-identifier-length vessel-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (is-some (map-get? registered-vessels {vessel-identifier: vessel-identifier})) ERR_VESSEL_NOT_REGISTERED)
        (asserts! (and 
            (>= updated-latitude (* -90 1000000))
            (<= updated-latitude (* 90 1000000))
            (>= updated-longitude (* -180 1000000))
            (<= updated-longitude (* 180 1000000))
        ) ERR_INVALID_COORDINATES)
        
        (ok (map-set registered-vessels
            {vessel-identifier: vessel-identifier}
            (merge (unwrap-panic (map-get? registered-vessels {vessel-identifier: vessel-identifier}))
                  {vessel-position: {latitude: updated-latitude, longitude: updated-longitude}})
        ))
    )
)

;; Read-Only Functions
(define-read-only (get-vessel-by-owner (vessel-owner principal))
    (match (map-get? vessel-ownership-registry {vessel-owner: vessel-owner})
        ownership-record (map-get? registered-vessels {vessel-identifier: (get vessel-identifier ownership-record)})
        none
    )
)

(define-read-only (get-vessel-details (vessel-identifier (string-utf8 36)))
    (begin
        (asserts! (validate-identifier-length vessel-identifier) ERR_INVALID_INPUT_PARAMETER)
        (ok (map-get? registered-vessels {vessel-identifier: vessel-identifier}))
    )
)