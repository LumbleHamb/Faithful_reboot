# systems/

Reserved for Phase 2+ support classes used *by* the autoload managers
(economy, building, worker, tutorial, prerequisite/cost-ledger evaluators)
per `docs/ARCHITECTURE.md` §1/§2.

Empty in Phase 1 — the four Phase 1 autoloads (`DataManager`, `SaveManager`,
`TimeManager`, `GameManager`) are simple enough not to need a support-class
split yet. See `docs/IMPLEMENTATION_STATUS.md`.
