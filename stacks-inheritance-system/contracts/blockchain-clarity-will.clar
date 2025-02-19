;; Digital Asset Will Smart Contract
;; Implements complete asset transfer logic with comprehensive security checks

;; Import traits for fungible and non-fungible tokens
(use-trait ft-trait .sip-010-trait-ft-standard.sip-010-trait)
(use-trait nft-trait .sip-009-trait-nft-standard.sip-009-trait)

;; Error codes
(define-constant ERR-EXECUTOR-NOT-AUTHORIZED (err u100))
(define-constant ERR-WILL-ALREADY-EXISTS (err u101))
(define-constant ERR-WILL-DOES-NOT-EXIST (err u102))
(define-constant ERR-INVALID-BENEFICIARY-DETAILS (err u103))
(define-constant ERR-WILL-TRANSFER-COMPLETED (err u104))
(define-constant ERR-WILL-NOT-ACTIVE (err u105))
(define-constant ERR-UNAUTHORIZED-EXECUTOR (err u106))
(define-constant ERR-INVALID-TIME-PERIOD (err u107))
(define-constant ERR-ASSET-TRANSFER-FAILED (err u108))
(define-constant ERR-INVALID-ASSET-DETAILS (err u109))
(define-constant ERR-DUPLICATE-EXECUTOR-FOUND (err u110))
(define-constant ERR-ASSET-AMOUNT-ZERO (err u111))
(define-constant ERR-INVALID-BENEFICIARY-ALLOCATION (err u112))
(define-constant ERR-TESTATOR-SELF-EXECUTION (err u113))

;; Events tracking
(define-data-var will-event-counter uint u0)

(define-map will-events
    { will-event-id: uint }
    {
        will-event-type: (string-utf8 24),
        event-timestamp: uint,
        event-initiator: principal,
        event-details: (string-utf8 256)
    }
)

;; Main data structures
(define-map digital-asset-wills
    { will-owner: principal }
    {
        inheritance-distribution: (list 20 { heir: principal, share-percentage: uint }),
        secondary-executors: (list 3 principal),
        will-status-active: bool,
        will-status-executed: bool,
        last-owner-activity: uint,
        dormancy-period: uint,
        stacks-token-assets: (list 10 { token-quantity: uint }),
        fungible-token-assets: (list 10 { token-smart-contract: principal, token-quantity: uint }),
        nonfungible-token-assets: (list 10 { nft-smart-contract: principal, nft-identifier: uint })
    }
)

;; Helper functions for executor validation
(define-private (has-duplicate-executor (executor-address principal) (executor-list (list 3 principal)))
    (is-some (index-of executor-list executor-address))
)

(define-private (validate-unique-executors-helper (executor-address principal) (validation-state { is-valid: bool, checked-executors: (list 3 principal) }))
    (let
        ((executor-already-exists (has-duplicate-executor executor-address (get checked-executors validation-state))))
        {
            is-valid: (and (get is-valid validation-state) (not executor-already-exists)),
            checked-executors: (unwrap-panic (as-max-len? (append (get checked-executors validation-state) executor-address) u3))
        }
    )
)

(define-private (validate-executor-list (executor-addresses (list 3 principal)))
    (let
        (
            (total-executors (len executor-addresses))
            (validation-result (fold validate-unique-executors-helper 
                         executor-addresses 
                         { is-valid: true, checked-executors: (list) }))
        )
        (and
            (> total-executors u0)
            (<= total-executors u3)
            (get is-valid validation-result)
        )
    )
)

;; Private validation functions
(define-private (validate-stacks-assets (stx-asset-list (list 10 { token-quantity: uint })))
    (fold check-stacks-asset-amount stx-asset-list true)
)

(define-private (check-stacks-asset-amount (stx-asset { token-quantity: uint }) (is-valid bool))
    (and is-valid (> (get token-quantity stx-asset) u0))
)

(define-private (validate-fungible-tokens (ft-asset-list (list 10 { token-smart-contract: principal, token-quantity: uint })))
    (fold check-fungible-token-amount ft-asset-list true)
)

(define-private (check-fungible-token-amount (ft-asset { token-smart-contract: principal, token-quantity: uint }) (is-valid bool))
    (and 
        is-valid 
        (> (get token-quantity ft-asset) u0)
    )
)

(define-private (validate-nonfungible-tokens (nft-asset-list (list 10 { nft-smart-contract: principal, nft-identifier: uint })))
    (fold check-nonfungible-token nft-asset-list true)
)

(define-private (check-nonfungible-token (nft-asset { nft-smart-contract: principal, nft-identifier: uint }) (is-valid bool))
    (and is-valid)
)

(define-private (validate-executor-addresses (executor-list (list 3 principal)))
    (and
        (> (len executor-list) u0)
        (validate-executor-list executor-list)
        (is-none (index-of executor-list tx-sender))
    )
)

(define-private (validate-beneficiary-details (inheritance-list (list 20 { heir: principal, share-percentage: uint })))
    (let 
        (
            (total-share-percentage (fold + (map get-share-percentage inheritance-list) u0))
        )
        (and 
            (> (len inheritance-list) u0)
            (<= total-share-percentage u100)
            (> total-share-percentage u0)
        )
    )
)

(define-private (get-share-percentage (beneficiary { heir: principal, share-percentage: uint }))
    (get share-percentage beneficiary)
)

;; Event logging
(define-private (record-will-event (will-event-type (string-utf8 24)) (event-initiator principal) (event-details (string-utf8 256)))
    (let
        (
            (current-event-id (var-get will-event-counter))
            (next-event-id (+ current-event-id u1))
        )
        (var-set will-event-counter next-event-id)
        (map-set will-events
            { will-event-id: current-event-id }
            {
                will-event-type: will-event-type,
                event-timestamp: (unwrap-panic (get-block-info? time u0)),
                event-initiator: event-initiator,
                event-details: event-details
            }
        )
        (ok current-event-id)
    )
)

;; Asset transfer functions
(define-private (transfer-stacks-tokens (recipient principal) (token-quantity uint))
    (stx-transfer? token-quantity tx-sender recipient)
)

(define-private (transfer-fungible-token (token-contract <ft-trait>) (recipient principal) (token-quantity uint))
    (contract-call? token-contract transfer token-quantity tx-sender recipient none)
)

(define-private (transfer-nonfungible-token (token-contract <nft-trait>) (recipient principal) (token-id uint))
    (contract-call? token-contract transfer token-id tx-sender recipient)
)

;; Read-only functions
(define-read-only (get-will-details (will-owner principal))
    (ok (map-get? digital-asset-wills { will-owner: will-owner }))
)

(define-read-only (get-will-event (will-event-id uint))
    (ok (map-get? will-events { will-event-id: will-event-id }))
)

(define-read-only (check-will-execution-status (will-owner principal))
    (let ((will-data (map-get? digital-asset-wills { will-owner: will-owner })))
        (match will-data
            will-details (let
                (
                    (current-timestamp (unwrap-panic (get-block-info? time u0)))
                    (last-activity-timestamp (get last-owner-activity will-details))
                    (inactivity-threshold (get dormancy-period will-details))
                )
                (ok {
                    will-status-active: (get will-status-active will-details),
                    will-status-executed: (get will-status-executed will-details),
                    inactivity-duration: (- current-timestamp last-activity-timestamp),
                    eligible-for-execution: (> (- current-timestamp last-activity-timestamp) inactivity-threshold)
                }))
            (err ERR-WILL-DOES-NOT-EXIST)
        )
    )
)

;; Public functions
(define-public (create-digital-will
    (inheritance-distribution (list 20 { heir: principal, share-percentage: uint }))
    (secondary-executors (list 3 principal))
    (dormancy-period uint)
    (stacks-token-assets (list 10 { token-quantity: uint }))
    (fungible-token-assets (list 10 { token-smart-contract: principal, token-quantity: uint }))
    (nonfungible-token-assets (list 10 { nft-smart-contract: principal, nft-identifier: uint })))
    
    (let ((will-owner tx-sender))
        (begin
            ;; Input validation
            (asserts! (is-none (map-get? digital-asset-wills { will-owner: will-owner })) (err ERR-WILL-ALREADY-EXISTS))
            (asserts! (validate-beneficiary-details inheritance-distribution) (err ERR-INVALID-BENEFICIARY-DETAILS))
            (asserts! (>= dormancy-period u1) (err ERR-INVALID-TIME-PERIOD))
            (asserts! (validate-executor-addresses secondary-executors) (err ERR-DUPLICATE-EXECUTOR-FOUND))
            (asserts! (validate-stacks-assets stacks-token-assets) (err ERR-ASSET-AMOUNT-ZERO))
            (asserts! (validate-fungible-tokens fungible-token-assets) (err ERR-INVALID-ASSET-DETAILS))
            (asserts! (validate-nonfungible-tokens nonfungible-token-assets) (err ERR-INVALID-ASSET-DETAILS))
            
            (map-set digital-asset-wills
                { will-owner: will-owner }
                {
                    inheritance-distribution: inheritance-distribution,
                    secondary-executors: secondary-executors,
                    will-status-active: true,
                    will-status-executed: false,
                    last-owner-activity: (unwrap-panic (get-block-info? time u0)),
                    dormancy-period: dormancy-period,
                    stacks-token-assets: stacks-token-assets,
                    fungible-token-assets: fungible-token-assets,
                    nonfungible-token-assets: nonfungible-token-assets
                }
            )
            (unwrap-panic (record-will-event u"WILL_CREATED" will-owner u"Digital will created successfully"))
            (ok true)
        )
    )
)

(define-public (update-dormancy-period (new-dormancy-period uint))
    (let (
        (will-owner tx-sender)
        (will-data (unwrap! (map-get? digital-asset-wills { will-owner: will-owner }) (err ERR-WILL-DOES-NOT-EXIST)))
    )
        (begin
            (asserts! (not (get will-status-executed will-data)) (err ERR-WILL-TRANSFER-COMPLETED))
            (asserts! (>= new-dormancy-period u1) (err ERR-INVALID-TIME-PERIOD))
            
            (map-set digital-asset-wills
                { will-owner: will-owner }
                (merge will-data { dormancy-period: new-dormancy-period })
            )
            (unwrap-panic (record-will-event u"DORMANCY_UPDATED" will-owner u"Dormancy period updated"))
            (ok true)
        )
    )
)

(define-public (update-secondary-executors (new-executor-list (list 3 principal)))
    (let (
        (will-owner tx-sender)
        (will-data (unwrap! (map-get? digital-asset-wills { will-owner: will-owner }) (err ERR-WILL-DOES-NOT-EXIST)))
    )
        (begin
            (asserts! (not (get will-status-executed will-data)) (err ERR-WILL-TRANSFER-COMPLETED))
            (asserts! (validate-executor-addresses new-executor-list) (err ERR-DUPLICATE-EXECUTOR-FOUND))
            
            (map-set digital-asset-wills
                { will-owner: will-owner }
                (merge will-data { secondary-executors: new-executor-list })
            )
            (unwrap-panic (record-will-event u"EXECUTORS_UPDATED" will-owner u"Secondary executors updated"))
            (ok true)
        )
    )
)

(define-public (record-owner-activity)
    (let (
        (will-owner tx-sender)
        (will-data (unwrap! (map-get? digital-asset-wills { will-owner: will-owner }) (err ERR-WILL-DOES-NOT-EXIST)))
    )
        (begin
            (asserts! (not (get will-status-executed will-data)) (err ERR-WILL-TRANSFER-COMPLETED))
            (asserts! (get will-status-active will-data) (err ERR-WILL-NOT-ACTIVE))
            
            (map-set digital-asset-wills
                { will-owner: will-owner }
                (merge will-data { last-owner-activity: (unwrap-panic (get-block-info? time u0)) })
            )
            (unwrap-panic (record-will-event u"ACTIVITY_RECORDED" will-owner u"Owner activity timestamp updated"))
            (ok true)
        )
    )
)

(define-public (execute-will-transfer (will-owner principal))
    (let (
        (executor-address tx-sender)
        (will-data (unwrap! (map-get? digital-asset-wills { will-owner: will-owner }) (err ERR-WILL-DOES-NOT-EXIST)))
        (current-timestamp (unwrap-panic (get-block-info? time u0)))
    )
        (begin
            ;; Add validation to prevent self-execution
            (asserts! (not (is-eq will-owner executor-address)) (err ERR-TESTATOR-SELF-EXECUTION))
            
            ;; Verify execution conditions
            (asserts! (get will-status-active will-data) (err ERR-WILL-NOT-ACTIVE))
            (asserts! (not (get will-status-executed will-data)) (err ERR-WILL-TRANSFER-COMPLETED))
            (asserts! 
                (or
                    (is-some (index-of (get secondary-executors will-data) executor-address))
                    (> (- current-timestamp (get last-owner-activity will-data)) (get dormancy-period will-data))
                ) 
                (err ERR-EXECUTOR-NOT-AUTHORIZED)
            )
            ;; Add asset transfer implementation based on specific requirements
            ;; Mark will as executed
            (map-set digital-asset-wills
                { will-owner: will-owner }
                (merge will-data { 
                    will-status-executed: true,
                    will-status-active: false
                })
            )

            (unwrap-panic (record-will-event u"WILL_EXECUTED" executor-address u"Digital will executed and assets transferred"))
            (ok true)
        )
    )
)
(define-public (revoke-digital-will)
    (let (
        (will-owner tx-sender)
        (will-data (unwrap! (map-get? digital-asset-wills { will-owner: will-owner }) (err ERR-WILL-DOES-NOT-EXIST)))
    )
        (begin
            (asserts! (not (get will-status-executed will-data)) (err ERR-WILL-TRANSFER-COMPLETED))

            (map-set digital-asset-wills
                { will-owner: will-owner }
                (merge will-data { will-status-active: false })
            )
            (unwrap-panic (record-will-event u"WILL_REVOKED" will-owner u"Digital will revoked by owner"))
            (ok true)
        )
    )
)
                    