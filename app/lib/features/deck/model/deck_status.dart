// Deck load state. Errors reach the UI as state (AGENTS.md), never as
// exceptions: [DeckStatus.denied] renders the permission empty state
// with retry, [DeckStatus.error] renders the error key with retry.
enum DeckStatus { loading, ready, denied, error }
