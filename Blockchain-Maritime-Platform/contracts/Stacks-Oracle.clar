;; GPS Oracle Contract for Maritime Trading Platform

;; Constants
(define-constant contract-administrator tx-sender)
(define-constant ERR_ADMINISTRATOR_ONLY (err u100))
(define-constant ERR_INVALID_GPS_COORDINATES (err u101))
(define-constant ERR_UNAUTHORIZED_GPS_ORACLE (err u102))
(define-constant ERR_VESSEL_NOT_REGISTERED (err u103))
(define-constant ERR_VESSEL_OUTSIDE_GEOFENCE (err u104))
(define-constant ERR_INVALID_INPUT_PARAMETER (err u105))
(define-constant ERR_INVALID_GEOFENCE_TYPE (err u106))
(define-constant ERR_INVALID_ORACLE_ADDRESS (err u107))
(define-constant ERR_ORACLE_ALREADY_REGISTERED (err u108))

;; Data Maps
(define-map gps-oracle-registry 
    { oracle-address: principal } 
    { oracle-active-status: bool }
)

(define-map maritime-geofence-zones
    { geofence-identifier: (string-utf8 36) }
    {
        geofence-latitude: int,
        geofence-longitude: int,
        geofence-radius: uint,  ;; in meters
        geofence-category: (string-ascii 20)  ;; e.g., "port", "trading", "restricted"
    }
)

;; Input Validation Functions
(define-private (validate-geofence-category (geofence-category (string-ascii 20)))
    (or
        (is-eq geofence-category "port")
        (is-eq geofence-category "trading")
        (is-eq geofence-category "restricted")
    )
)

(define-private (validate-identifier-length (identifier-string (string-utf8 36)))
    (and 
        (>= (len identifier-string) u1)
        (<= (len identifier-string) u36)
    )
)

;; Helper Functions
(define-private (calculate-geographic-distance 
    (latitude1 int) 
    (longitude1 int) 
    (latitude2 int) 
    (longitude2 int))
    ;; Simplified distance calculation using Manhattan distance
    ;; Returns approximate distance in coordinate units
    (let
        (
            (latitude-difference (if (> latitude2 latitude1)
                (- latitude2 latitude1)
                (- latitude1 latitude2)))
            (longitude-difference (if (> longitude2 longitude1)
                (- longitude2 longitude1)
                (- longitude1 longitude2)))
        )
        (to-uint (+ latitude-difference longitude-difference))
    )
)

;; Public Functions
(define-public (register-gps-oracle (oracle-address principal))
    (begin
        ;; Check that caller is contract administrator
        (asserts! (is-eq tx-sender contract-administrator) ERR_ADMINISTRATOR_ONLY)
        
        ;; Verify oracle is not tx-sender
        (asserts! (not (is-eq oracle-address tx-sender)) ERR_INVALID_ORACLE_ADDRESS)
        
        ;; Check oracle is not null/zero address
        (asserts! (not (is-eq oracle-address 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)) ERR_INVALID_ORACLE_ADDRESS)
        
        ;; Check if oracle is already registered
        (asserts! (is-none (map-get? gps-oracle-registry {oracle-address: oracle-address})) ERR_ORACLE_ALREADY_REGISTERED)
        
        ;; If all checks pass, register the oracle
        (ok (map-set gps-oracle-registry
            {oracle-address: oracle-address}
            {oracle-active-status: true}
        ))
    )
)

(define-public (update-vessel-position
    (vessel-identifier (string-utf8 36))
    (updated-latitude int)
    (updated-longitude int))
    (let
        ((oracle-address tx-sender))
        ;; Input validation
        (asserts! (validate-identifier-length vessel-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (is-some (map-get? gps-oracle-registry {oracle-address: oracle-address})) ERR_UNAUTHORIZED_GPS_ORACLE)
        
        ;; Coordinate validation
        (asserts! (and 
            (>= updated-latitude (* -90 1000000))
            (<= updated-latitude (* 90 1000000))
            (>= updated-longitude (* -180 1000000))
            (<= updated-longitude (* 180 1000000))
        ) ERR_INVALID_GPS_COORDINATES)
        
        ;; Update location in the main contract
        (contract-call? 
            .Maritime-Trading 
            update-vessel-location 
            vessel-identifier 
            updated-latitude 
            updated-longitude
        )
    )
)

(define-public (create-geofence-zone
    (geofence-identifier (string-utf8 36))
    (geofence-latitude int)
    (geofence-longitude int)
    (geofence-radius uint)
    (geofence-category (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERR_ADMINISTRATOR_ONLY)
        ;; Input validation
        (asserts! (validate-identifier-length geofence-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-geofence-category geofence-category) ERR_INVALID_GEOFENCE_TYPE)
        (asserts! (> geofence-radius u0) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (and 
            (>= geofence-latitude (* -90 1000000))
            (<= geofence-latitude (* 90 1000000))
            (>= geofence-longitude (* -180 1000000))
            (<= geofence-longitude (* 180 1000000))
        ) ERR_INVALID_GPS_COORDINATES)
        
        (map-set maritime-geofence-zones
            {geofence-identifier: geofence-identifier}
            {
                geofence-latitude: geofence-latitude,
                geofence-longitude: geofence-longitude,
                geofence-radius: geofence-radius,
                geofence-category: geofence-category
            }
        )
        (ok true)
    )
)

;; Read-Only Functions
(define-read-only (verify-vessel-in-geofence 
    (vessel-latitude int)
    (vessel-longitude int)
    (geofence-identifier (string-utf8 36)))
    (begin
        (asserts! (validate-identifier-length geofence-identifier) ERR_INVALID_INPUT_PARAMETER)
        (ok (match (map-get? maritime-geofence-zones {geofence-identifier: geofence-identifier})
            geofence-data
            (let
                ((geographic-distance (calculate-geographic-distance
                    vessel-latitude
                    vessel-longitude
                    (get geofence-latitude geofence-data)
                    (get geofence-longitude geofence-data)
                )))
                (<= geographic-distance (get geofence-radius geofence-data))
            )
            false
        ))
    )
)

(define-read-only (check-oracle-authorization (oracle-address principal))
    (match (map-get? gps-oracle-registry {oracle-address: oracle-address})
        oracle-data (get oracle-active-status oracle-data)
        false
    )
)