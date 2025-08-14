;; Decentralized Banking Protocol
;; Banking and finance 

;; Bank Management
(define-constant bank-manager tx-sender)
(define-constant bank-err-access-denied (err u600))
(define-constant bank-err-insufficient-reserves (err u601))
(define-constant bank-err-invalid-transaction (err u602))
(define-constant bank-err-rate-unfavorable (err u603))
(define-constant bank-err-currency-error (err u604))
(define-constant bank-err-processing-failed (err u605))
(define-constant bank-err-bank-operational (err u606))
(define-constant bank-err-bank-closed (err u607))

;; Banking Reserves
(define-data-var bank-stx-reserves uint u0)
(define-data-var bank-alt-currency-reserves uint u0)
(define-data-var bank-shares-outstanding uint u0)
(define-data-var banking-services-active bool false)

;; Alternative Currency Contract
(define-data-var alt-currency-contract principal .token)

;; Customer Account Balances
(define-map customer-accounts principal uint)

;; Banking Transaction Records
(define-map transaction-ledger 
  { ledger-entry: uint }
  { 
    customer: principal,
    stx-credited: uint,
    alt-currency-debited: uint,
    stx-debited: uint,
    alt-currency-credited: uint,
    processing-block: uint
  }
)

(define-data-var ledger-entry-counter uint u0)

;; Currency Interface Standard
(define-trait bank-currency
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Mathematical Operations

;; Return lower amount
(define-private (lower-amount (amount1 uint) (amount2 uint))
  (if (< amount1 amount2) amount1 amount2))

;; Banking Information Services

(define-read-only (check-bank-reserves)
  {
    stx-reserves: (var-get bank-stx-reserves),
    alt-currency-reserves: (var-get bank-alt-currency-reserves)
  }
)

(define-read-only (check-customer-account (customer principal))
  (default-to u0 (map-get? customer-accounts customer))
)

(define-read-only (check-outstanding-shares)
  (var-get bank-shares-outstanding)
)

(define-read-only (check-banking-status)
  (var-get banking-services-active)
)

(define-read-only (check-alt-currency-contract)
  (var-get alt-currency-contract)
)

;; Exchange Rate Calculations (0.3% banking fee)
(define-read-only (calculate-exchange-output (input-sum uint) (input-reserves uint) (output-reserves uint))
  (if (or (is-eq input-sum u0) (is-eq input-reserves u0) (is-eq output-reserves u0))
    u0
    (let (
      (fee-adjusted-sum (* input-sum u997))
      (exchange-numerator (* fee-adjusted-sum output-reserves))
      (exchange-denominator (+ (* input-reserves u1000) fee-adjusted-sum))
    )
    (/ exchange-numerator exchange-denominator)))
)

(define-read-only (calculate-required-input (output-sum uint) (input-reserves uint) (output-reserves uint))
  (if (or (is-eq output-sum u0) (is-eq input-reserves u0) (is-eq output-reserves u0))
    u0
    (let (
      (required-numerator (* (* input-reserves output-sum) u1000))
      (required-denominator (* (- output-reserves output-sum) u997))
    )
    (+ (/ required-numerator required-denominator) u1)))
)

(define-read-only (calculate-share-value (currency-amount uint) (currency-reserves uint) (paired-reserves uint))
  (if (is-eq currency-reserves u0)
    u0
    (/ (* currency-amount paired-reserves) currency-reserves))
)

;; Banking Services

(define-public (open-bank (currency-interface <bank-currency>) (stx-capital uint) (alt-capital uint))
  (let (
    (initial-shares (lower-amount stx-capital alt-capital))
  )
    (asserts! (not (var-get banking-services-active)) bank-err-bank-operational)
    (asserts! (> stx-capital u0) bank-err-invalid-transaction)
    (asserts! (> alt-capital u0) bank-err-invalid-transaction)
    (asserts! (> initial-shares u0) bank-err-insufficient-reserves)
    
    (var-set alt-currency-contract (contract-of currency-interface))
    
    (try! (contract-call? currency-interface transfer alt-capital tx-sender (as-contract tx-sender) none))
    
    (var-set bank-stx-reserves stx-capital)
    (var-set bank-alt-currency-reserves alt-capital)
    (var-set bank-shares-outstanding initial-shares)
    (var-set banking-services-active true)
    
    (map-set customer-accounts tx-sender initial-shares)
    
    (ok initial-shares)
  )
)

(define-public (make-deposit (currency-interface <bank-currency>) (stx-deposit uint) (alt-deposit uint) (min-shares uint))
  (let (
    (current-stx-reserves (var-get bank-stx-reserves))
    (current-alt-reserves (var-get bank-alt-currency-reserves))
    (current-shares (var-get bank-shares-outstanding))
    (new-shares (lower-amount 
                 (/ (* stx-deposit current-shares) current-stx-reserves)
                 (/ (* alt-deposit current-shares) current-alt-reserves)))
    (current-account-balance (check-customer-account tx-sender))
  )
    (asserts! (var-get banking-services-active) bank-err-bank-closed)
    (asserts! (is-eq (contract-of currency-interface) (var-get alt-currency-contract)) bank-err-currency-error)
    (asserts! (> stx-deposit u0) bank-err-invalid-transaction)
    (asserts! (> alt-deposit u0) bank-err-invalid-transaction)
    (asserts! (>= new-shares min-shares) bank-err-rate-unfavorable)
    
    (try! (contract-call? currency-interface transfer alt-deposit tx-sender (as-contract tx-sender) none))
    
    (var-set bank-stx-reserves (+ current-stx-reserves stx-deposit))
    (var-set bank-alt-currency-reserves (+ current-alt-reserves alt-deposit))
    (var-set bank-shares-outstanding (+ current-shares new-shares))
    
    (map-set customer-accounts tx-sender (+ current-account-balance new-shares))
    
    (ok new-shares)
  )
)

(define-public (make-withdrawal (currency-interface <bank-currency>) (share-amount uint) (min-stx uint) (min-alt uint))
  (let (
    (current-stx-reserves (var-get bank-stx-reserves))
    (current-alt-reserves (var-get bank-alt-currency-reserves))
    (current-shares (var-get bank-shares-outstanding))
    (current-account-balance (check-customer-account tx-sender))
    (stx-withdrawal (/ (* share-amount current-stx-reserves) current-shares))
    (alt-withdrawal (/ (* share-amount current-alt-reserves) current-shares))
  )
    (asserts! (var-get banking-services-active) bank-err-bank-closed)
    (asserts! (is-eq (contract-of currency-interface) (var-get alt-currency-contract)) bank-err-currency-error)
    (asserts! (> share-amount u0) bank-err-invalid-transaction)
    (asserts! (>= current-account-balance share-amount) bank-err-insufficient-reserves)
    (asserts! (>= stx-withdrawal min-stx) bank-err-rate-unfavorable)
    (asserts! (>= alt-withdrawal min-alt) bank-err-rate-unfavorable)
    
    (var-set bank-stx-reserves (- current-stx-reserves stx-withdrawal))
    (var-set bank-alt-currency-reserves (- current-alt-reserves alt-withdrawal))
    (var-set bank-shares-outstanding (- current-shares share-amount))
    
    (map-set customer-accounts tx-sender (- current-account-balance share-amount))
    
    (try! (as-contract (contract-call? currency-interface transfer alt-withdrawal tx-sender tx-sender none)))
    
    (ok { stx: stx-withdrawal, alt-currency: alt-withdrawal })
  )
)

(define-public (exchange-stx-for-alt (currency-interface <bank-currency>) (stx-amount uint) (min-alt-output uint))
  (let (
    (current-stx-reserves (var-get bank-stx-reserves))
    (current-alt-reserves (var-get bank-alt-currency-reserves))
    (alt-output (calculate-exchange-output stx-amount current-stx-reserves current-alt-reserves))
    (ledger-entry (var-get ledger-entry-counter))
  )
    (asserts! (var-get banking-services-active) bank-err-bank-closed)
    (asserts! (is-eq (contract-of currency-interface) (var-get alt-currency-contract)) bank-err-currency-error)
    (asserts! (> stx-amount u0) bank-err-invalid-transaction)
    (asserts! (>= alt-output min-alt-output) bank-err-rate-unfavorable)
    (asserts! (< alt-output current-alt-reserves) bank-err-insufficient-reserves)
    
    (var-set bank-stx-reserves (+ current-stx-reserves stx-amount))
    (var-set bank-alt-currency-reserves (- current-alt-reserves alt-output))
    
    (try! (as-contract (contract-call? currency-interface transfer alt-output tx-sender tx-sender none)))
    
    (map-set transaction-ledger 
      { ledger-entry: ledger-entry }
      { 
        customer: tx-sender,
        stx-credited: stx-amount,
        alt-currency-debited: alt-output,
        stx-debited: u0,
        alt-currency-credited: u0,
        processing-block: block-height
      }
    )
    (var-set ledger-entry-counter (+ ledger-entry u1))
    
    (ok alt-output)
  )
)

(define-public (exchange-alt-for-stx (currency-interface <bank-currency>) (alt-amount uint) (min-stx-output uint))
  (let (
    (current-stx-reserves (var-get bank-stx-reserves))
    (current-alt-reserves (var-get bank-alt-currency-reserves))
    (stx-output (calculate-exchange-output alt-amount current-alt-reserves current-stx-reserves))
    (ledger-entry (var-get ledger-entry-counter))
  )
    (asserts! (var-get banking-services-active) bank-err-bank-closed)
    (asserts! (is-eq (contract-of currency-interface) (var-get alt-currency-contract)) bank-err-currency-error)
    (asserts! (> alt-amount u0) bank-err-invalid-transaction)
    (asserts! (>= stx-output min-stx-output) bank-err-rate-unfavorable)
    (asserts! (< stx-output current-stx-reserves) bank-err-insufficient-reserves)
    
    (try! (contract-call? currency-interface transfer alt-amount tx-sender (as-contract tx-sender) none))
    
    (var-set bank-stx-reserves (- current-stx-reserves stx-output))
    (var-set bank-alt-currency-reserves (+ current-alt-reserves alt-amount))
    
    (try! (as-contract (stx-transfer? stx-output tx-sender tx-sender)))
    
    (map-set transaction-ledger 
      { ledger-entry: ledger-entry }
      { 
        customer: tx-sender,
        stx-credited: u0,
        alt-currency-debited: u0,
        stx-debited: stx-output,
        alt-currency-credited: alt-amount,
        processing-block: block-height
      }
    )
    (var-set ledger-entry-counter (+ ledger-entry u1))
    
    (ok stx-output)
  )
)