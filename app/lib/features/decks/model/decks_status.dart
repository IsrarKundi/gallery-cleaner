// Scan/hub status for the decks feature (requirements §7, Phase 2).
// Kept separate from the deck's DeckStatus: the hub scans in the
// background and reports per-deck readiness, which the main deck's
// loading/ready/denied/error states do not describe.
enum DecksStatus { loading, scanning, ready, denied, error }
