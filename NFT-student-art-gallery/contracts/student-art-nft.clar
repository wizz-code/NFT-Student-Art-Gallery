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