;; Student Art NFT Gallery - Fundraising through creative expression

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-price (err u104))
(define-constant err-invalid-percentage (err u105))
(define-constant err-artwork-not-for-sale (err u106))
(define-constant err-insufficient-balance (err u107))
(define-constant err-transfer-failed (err u108))

;; Data Variables
(define-data-var total-artworks uint u0)
(define-data-var total-sales uint u0)
(define-data-var platform-fee-percentage uint u5)
(define-data-var contract-paused bool false)
(define-data-var minimum-price uint u1000000) ;; 1 STX minimum

;; Data Maps
(define-map artworks
    { artwork-id: uint }
    {
        title: (string-ascii 100),
        artist: principal,
        uri: (string-ascii 256),
        price: uint,
        for-sale: bool,
        school-percentage: uint
    }
)

(define-map artwork-owners
    { artwork-id: uint }
    { owner: principal }
)

(define-map artist-profiles
    { artist: principal }
    {
        name: (string-ascii 50),
        artworks-created: uint,
        total-earned: uint
    }
)

(define-map school-fundraising
    { school: principal }
    { total-raised: uint }
)

(define-map artwork-likes
    { artwork-id: uint, liker: principal }
    { liked: bool }
)

(define-map artwork-like-count
    { artwork-id: uint }
    { count: uint }
)

(define-map featured-artworks
    { artwork-id: uint }
    { featured: bool, featured-at: uint }
)

(define-map artist-followers
    { artist: principal, follower: principal }
    { following: bool }
)

(define-map artist-follower-count
    { artist: principal }
    { count: uint }
)

;; Read-only functions
(define-read-only (get-artwork (artwork-id uint))
    (map-get? artworks { artwork-id: artwork-id })
)

(define-read-only (get-artwork-owner (artwork-id uint))
    (map-get? artwork-owners { artwork-id: artwork-id })
)

(define-read-only (get-artist-profile (artist principal))
    (map-get? artist-profiles { artist: artist })
)

(define-read-only (get-school-fundraising (school principal))
    (default-to u0 (get total-raised (map-get? school-fundraising { school: school })))
)

(define-read-only (get-total-artworks)
    (ok (var-get total-artworks))
)

(define-read-only (get-total-sales)
    (ok (var-get total-sales))
)

(define-read-only (get-platform-fee)
    (ok (var-get platform-fee-percentage))
)

(define-read-only (get-contract-paused)
    (ok (var-get contract-paused))
)

(define-read-only (get-minimum-price)
    (ok (var-get minimum-price))
)

(define-read-only (get-artwork-likes (artwork-id uint))
    (default-to u0 (get count (map-get? artwork-like-count { artwork-id: artwork-id })))
)

(define-read-only (has-liked-artwork (artwork-id uint) (liker principal))
    (default-to false (get liked (map-get? artwork-likes { artwork-id: artwork-id, liker: liker })))
)

(define-read-only (is-featured (artwork-id uint))
    (is-some (map-get? featured-artworks { artwork-id: artwork-id }))
)

(define-read-only (get-artist-followers (artist principal))
    (default-to u0 (get count (map-get? artist-follower-count { artist: artist })))
)

(define-read-only (is-following (artist principal) (follower principal))
    (default-to false (get following (map-get? artist-followers { artist: artist, follower: follower })))
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-artist-profile (name (string-ascii 50)))
    (let ((existing-profile (map-get? artist-profiles { artist: tx-sender })))
        (if (is-some existing-profile)
            err-already-exists
            (ok (map-set artist-profiles
                { artist: tx-sender }
                { name: name, artworks-created: u0, total-earned: u0 }
            ))
        )
    )
)

;; #[allow(unchecked_data)]
(define-public (mint-artwork (title (string-ascii 100)) (uri (string-ascii 256)) (price uint) (school-percentage uint))
    (let (
        (new-artwork-id (+ (var-get total-artworks) u1))
        (artist-profile (unwrap! (map-get? artist-profiles { artist: tx-sender }) err-unauthorized))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (<= school-percentage u100) err-invalid-percentage)
        (asserts! (>= price (var-get minimum-price)) err-invalid-price)
        (map-set artworks
            { artwork-id: new-artwork-id }
            {
                title: title,
                artist: tx-sender,
                uri: uri,
                price: price,
                for-sale: true,
                school-percentage: school-percentage
            }
        )
        (map-set artwork-owners
            { artwork-id: new-artwork-id }
            { owner: tx-sender }
        )
        (map-set artist-profiles
            { artist: tx-sender }
            (merge artist-profile { artworks-created: (+ (get artworks-created artist-profile) u1) })
        )
        (var-set total-artworks new-artwork-id)
        (ok new-artwork-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (purchase-artwork (artwork-id uint) (school principal))
    (let (
        (artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) err-not-found))
        (owner-info (unwrap! (map-get? artwork-owners { artwork-id: artwork-id }) err-not-found))
        (artist-profile (unwrap! (map-get? artist-profiles { artist: (get artist artwork) }) err-not-found))
        (price (get price artwork))
        (school-amount (/ (* price (get school-percentage artwork)) u100))
        (platform-amount (/ (* price (var-get platform-fee-percentage)) u100))
        (artist-amount (- (- price school-amount) platform-amount))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (get for-sale artwork) err-artwork-not-for-sale)
        (asserts! (not (is-eq tx-sender (get owner owner-info))) err-unauthorized)
        (try! (stx-transfer? price tx-sender (get artist artwork)))
        (map-set artwork-owners
            { artwork-id: artwork-id }
            { owner: tx-sender }
        )
        (map-set artworks
            { artwork-id: artwork-id }
            (merge artwork { for-sale: false })
        )
        (map-set artist-profiles
            { artist: (get artist artwork) }
            (merge artist-profile { total-earned: (+ (get total-earned artist-profile) artist-amount) })
        )
        (map-set school-fundraising
            { school: school }
            { total-raised: (+ (get-school-fundraising school) school-amount) }
        )
        (var-set total-sales (+ (var-get total-sales) u1))
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (set-artwork-for-sale (artwork-id uint) (for-sale bool) (new-price uint))
    (let (
        (artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) err-not-found))
        (owner-info (unwrap! (map-get? artwork-owners { artwork-id: artwork-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender (get owner owner-info)) err-unauthorized)
        (asserts! (>= new-price (var-get minimum-price)) err-invalid-price)
        (ok (map-set artworks
            { artwork-id: artwork-id }
            (merge artwork { for-sale: for-sale, price: new-price })
        ))
    )
)

;; #[allow(unchecked_data)]
(define-public (transfer-artwork (artwork-id uint) (recipient principal))
    (let (
        (artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) err-not-found))
        (owner-info (unwrap! (map-get? artwork-owners { artwork-id: artwork-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender (get owner owner-info)) err-unauthorized)
        (asserts! (not (get for-sale artwork)) err-unauthorized)
        (map-set artwork-owners
            { artwork-id: artwork-id }
            { owner: recipient }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (update-artist-profile (name (string-ascii 50)))
    (let (
        (artist-profile (unwrap! (map-get? artist-profiles { artist: tx-sender }) err-not-found))
    )
        (ok (map-set artist-profiles
            { artist: tx-sender }
            (merge artist-profile { name: name })
        ))
    )
)

;; #[allow(unchecked_data)]
(define-public (like-artwork (artwork-id uint))
    (let (
        (artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) err-not-found))
        (current-likes (get-artwork-likes artwork-id))
        (already-liked (has-liked-artwork artwork-id tx-sender))
    )
        (asserts! (not already-liked) err-already-exists)
        (map-set artwork-likes
            { artwork-id: artwork-id, liker: tx-sender }
            { liked: true }
        )
        (map-set artwork-like-count
            { artwork-id: artwork-id }
            { count: (+ current-likes u1) }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (unlike-artwork (artwork-id uint))
    (let (
        (artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) err-not-found))
        (current-likes (get-artwork-likes artwork-id))
        (already-liked (has-liked-artwork artwork-id tx-sender))
    )
        (asserts! already-liked err-not-found)
        (map-set artwork-likes
            { artwork-id: artwork-id, liker: tx-sender }
            { liked: false }
        )
        (map-set artwork-like-count
            { artwork-id: artwork-id }
            { count: (if (> current-likes u0) (- current-likes u1) u0) }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (follow-artist (artist principal))
    (let (
        (current-followers (get-artist-followers artist))
        (already-following (is-following artist tx-sender))
    )
        (asserts! (not (is-eq tx-sender artist)) err-unauthorized)
        (asserts! (not already-following) err-already-exists)
        (map-set artist-followers
            { artist: artist, follower: tx-sender }
            { following: true }
        )
        (map-set artist-follower-count
            { artist: artist }
            { count: (+ current-followers u1) }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (unfollow-artist (artist principal))
    (let (
        (current-followers (get-artist-followers artist))
        (already-following (is-following artist tx-sender))
    )
        (asserts! already-following err-not-found)
        (map-set artist-followers
            { artist: artist, follower: tx-sender }
            { following: false }
        )
        (map-set artist-follower-count
            { artist: artist }
            { count: (if (> current-followers u0) (- current-followers u1) u0) }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (feature-artwork (artwork-id uint))
    (let (
        (artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set featured-artworks
            { artwork-id: artwork-id }
            { featured: true, featured-at: stacks-block-height }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (unfeature-artwork (artwork-id uint))
    (let (
        (artwork (unwrap! (map-get? artworks { artwork-id: artwork-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete featured-artworks { artwork-id: artwork-id })
        (ok true)
    )
)

;; Admin functions
;; #[allow(unchecked_data)]
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u20) err-invalid-percentage)
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (set-minimum-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set minimum-price new-price)
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused true)
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused false)
        (ok true)
    )
)