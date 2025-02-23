;; Maritime trait file

(define-trait maritime-trade-trait
    (
        (get-trade-agreement ((string-utf8 36)) (response (optional {
            selling-party: principal,
            buying-party: principal,
            cargo-category: (string-utf8 50),
            cargo-quantity: uint,
            contract-price: uint,
            contract-status: (string-utf8 20),
            delivery-location: {latitude: int, longitude: int},
            customs-clearance: bool
        }) uint))
        
        (update-vessel-location ((string-utf8 36) int int) (response bool uint))
    )
)