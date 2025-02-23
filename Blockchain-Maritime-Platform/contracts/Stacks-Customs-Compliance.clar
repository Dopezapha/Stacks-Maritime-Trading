;; Customs Compliance Contract for Maritime Trading Platform

;; Import the maritime trade trait
(use-trait maritime-trade-trait .maritime-trade-trait.maritime-trade-trait)

;; Constants
(define-constant contract-administrator tx-sender)
(define-constant ERR_ADMINISTRATOR_ONLY (err u100))
(define-constant ERR_INVALID_INPUT_PARAMETER (err u101))
(define-constant ERR_UNAUTHORIZED_ACCESS (err u102))
(define-constant ERR_DOCUMENT_ALREADY_EXISTS (err u103))
(define-constant ERR_DOCUMENT_NOT_FOUND (err u104))
(define-constant ERR_INVALID_DOCUMENT_STATUS (err u105))
(define-constant ERR_TRADE_AGREEMENT_NOT_FOUND (err u106))
(define-constant ERR_INVALID_VERIFIER_CREDENTIALS (err u107))

;; Document Types and Status Constants
(define-data-var DOCUMENT_TYPE_BILL_OF_LADING (string-utf8 50) u"bill_of_lading")
(define-data-var DOCUMENT_TYPE_CARGO_MANIFEST (string-utf8 50) u"cargo_manifest")
(define-data-var DOCUMENT_TYPE_CUSTOMS_DECLARATION (string-utf8 50) u"customs_declaration")
(define-data-var DOCUMENT_STATUS_PENDING (string-utf8 20) u"pending")
(define-data-var DOCUMENT_STATUS_VERIFIED (string-utf8 20) u"verified")
(define-data-var DOCUMENT_STATUS_REJECTED (string-utf8 20) u"rejected")

;; Data Maps
(define-map customs-verifiers
    { verifier-principal: principal } 
    { 
        verifier-active-status: bool,
        verifier-jurisdiction: (string-utf8 50)
    }
)

(define-map trade-document-records
    { 
        trade-identifier: (string-utf8 36),
        document-category: (string-utf8 50)
    }
    {
        document-hash: (buff 32),
        document-status: (string-utf8 20),
        verifying-authority: (optional principal),
        verification-timestamp: (optional uint),
        verification-notes: (optional (string-utf8 500))
    }
)

(define-map port-document-requirements
    { port-identifier: (string-utf8 50) }
    {
        mandatory-documents: (list 10 (string-utf8 50)),
        minimum-verification-period: uint,
        permitted-jurisdiction: (string-utf8 50)
    }
)

;; Private validation functions
(define-private (validate-trade-identifier (trade-id (string-utf8 36)))
    (and 
        (not (is-eq trade-id u""))
        (<= (len trade-id) u36)
    )
)

(define-private (validate-document-type (document-category (string-utf8 50)))
    (or 
        (is-eq document-category (var-get DOCUMENT_TYPE_BILL_OF_LADING))
        (is-eq document-category (var-get DOCUMENT_TYPE_CARGO_MANIFEST))
        (is-eq document-category (var-get DOCUMENT_TYPE_CUSTOMS_DECLARATION))
    )
)

(define-private (validate-hash-length (hash (buff 32)))
    (is-eq (len hash) u32)
)

(define-private (validate-notes-content (notes (optional (string-utf8 500))))
    (match notes
        note-content (and 
            (not (is-eq note-content u""))
            (<= (len note-content) u500)
        )
        true
    )
)

(define-private (validate-port-identifier (port-id (string-utf8 50)))
    (and 
        (not (is-eq port-id u""))
        (<= (len port-id) u50)
    )
)

(define-private (validate-jurisdiction-code (code (string-utf8 50)))
    (and 
        (not (is-eq code u""))
        (<= (len code) u50)
    )
)

(define-private (validate-document-types-fold (document-type (string-utf8 50)) (previous-result bool))
    (and previous-result (validate-document-type document-type))
)

;; Public functions
(define-public (submit-trade-document
    (trade-identifier (string-utf8 36))
    (document-category (string-utf8 50))
    (document-hash (buff 32))
    (maritime-contract <maritime-trade-trait>))
    (begin
        (asserts! (validate-trade-identifier trade-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-document-type document-category) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-hash-length document-hash) ERR_INVALID_INPUT_PARAMETER)
        
        (let
            ((existing-document (map-get? trade-document-records 
                {trade-identifier: trade-identifier, document-category: document-category}))
             (trade-agreement-response (try! (contract-call? maritime-contract get-trade-agreement trade-identifier))))
            
            (asserts! (is-some trade-agreement-response) ERR_TRADE_AGREEMENT_NOT_FOUND)
            (let 
                ((trade-agreement (unwrap! trade-agreement-response ERR_TRADE_AGREEMENT_NOT_FOUND)))
                (asserts! (is-none existing-document) ERR_DOCUMENT_ALREADY_EXISTS)
                (asserts! (or 
                    (is-eq tx-sender (get selling-party trade-agreement))
                    (is-eq tx-sender (get buying-party trade-agreement))
                ) ERR_UNAUTHORIZED_ACCESS)
                (ok (map-set trade-document-records
                    {trade-identifier: trade-identifier, document-category: document-category}
                    {
                        document-hash: document-hash,
                        document-status: (var-get DOCUMENT_STATUS_PENDING),
                        verifying-authority: none,
                        verification-timestamp: none,
                        verification-notes: none
                    }
                ))
            )
        )
    )
)

(define-public (verify-trade-document
    (trade-identifier (string-utf8 36))
    (document-category (string-utf8 50))
    (verification-result bool)
    (verification-notes (optional (string-utf8 500))))
    (begin
        (asserts! (validate-trade-identifier trade-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-document-type document-category) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-notes-content verification-notes) ERR_INVALID_INPUT_PARAMETER)
        
        (let
            ((verifier-credentials (map-get? customs-verifiers {verifier-principal: tx-sender}))
             (submitted-document (map-get? trade-document-records {trade-identifier: trade-identifier, document-category: document-category})))
            
            (asserts! (is-some verifier-credentials) ERR_UNAUTHORIZED_ACCESS)
            (asserts! (get verifier-active-status (unwrap! verifier-credentials ERR_UNAUTHORIZED_ACCESS)) ERR_UNAUTHORIZED_ACCESS)
            (asserts! (is-some submitted-document) ERR_DOCUMENT_NOT_FOUND)
            
            (ok (map-set trade-document-records
                {trade-identifier: trade-identifier, document-category: document-category}
                {
                    document-hash: (get document-hash (unwrap! submitted-document ERR_DOCUMENT_NOT_FOUND)),
                    document-status: (if verification-result 
                        (var-get DOCUMENT_STATUS_VERIFIED) 
                        (var-get DOCUMENT_STATUS_REJECTED)),
                    verifying-authority: (some tx-sender),
                    verification-timestamp: (some block-height),
                    verification-notes: verification-notes
                }
            ))
        )
    )
)

;; Port Management
(define-public (configure-port-requirements
    (port-identifier (string-utf8 50))
    (required-document-types (list 10 (string-utf8 50)))
    (minimum-verification-period uint)
    (jurisdiction-code (string-utf8 50)))
    (begin
        (asserts! (validate-port-identifier port-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (> minimum-verification-period u0) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-jurisdiction-code jurisdiction-code) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (fold validate-document-types-fold required-document-types true) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (is-eq tx-sender contract-administrator) ERR_ADMINISTRATOR_ONLY)
        
        (ok (map-set port-document-requirements
            {port-identifier: port-identifier}
            {
                mandatory-documents: required-document-types,
                minimum-verification-period: minimum-verification-period,
                permitted-jurisdiction: jurisdiction-code
            }
        ))
    )
)

;; Read-Only Functions
(define-read-only (get-document-verification-status
    (trade-identifier (string-utf8 36))
    (document-category (string-utf8 50)))
    (begin
        (asserts! (and 
            (validate-trade-identifier trade-identifier)
            (validate-document-type document-category)
        ) ERR_INVALID_INPUT_PARAMETER)
        (ok (map-get? trade-document-records {trade-identifier: trade-identifier, document-category: document-category}))
    )
)

(define-read-only (get-port-documentation-requirements (port-identifier (string-utf8 50)))
    (begin
        (asserts! (validate-port-identifier port-identifier) ERR_INVALID_INPUT_PARAMETER)
        (ok (map-get? port-document-requirements {port-identifier: port-identifier}))
    )
)

(define-read-only (verify-trade-compliance
    (trade-identifier (string-utf8 36))
    (port-identifier (string-utf8 50)))
    (begin
        (asserts! (validate-trade-identifier trade-identifier) ERR_INVALID_INPUT_PARAMETER)
        (asserts! (validate-port-identifier port-identifier) ERR_INVALID_INPUT_PARAMETER)
        
        (ok (match (map-get? port-document-requirements {port-identifier: port-identifier})
            port-requirements (let
                ((compliance-check-result (fold check-document-verification-status 
                    (get mandatory-documents port-requirements)
                    {trade-identifier: trade-identifier, compliance-status: true})))
                (get compliance-status compliance-check-result)
            )
            false
        ))
    )
)

(define-private (check-document-verification-status 
    (document-category (string-utf8 50)) 
    (compliance-state {trade-identifier: (string-utf8 36), compliance-status: bool}))
    (if (get compliance-status compliance-state)
        (match (map-get? trade-document-records 
            {
                trade-identifier: (get trade-identifier compliance-state), 
                document-category: document-category
            })
            document-record {
                trade-identifier: (get trade-identifier compliance-state), 
                compliance-status: (is-eq (get document-status document-record) (var-get DOCUMENT_STATUS_VERIFIED))
            }
            {
                trade-identifier: (get trade-identifier compliance-state), 
                compliance-status: false
            }
        )
        compliance-state
    )
)