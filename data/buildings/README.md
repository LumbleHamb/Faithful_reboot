# data/buildings/

Reserved for converted `BuildingDefinition` `.tres` instances (the full
building/decoration roster from `Objects.xml` + `Vanilla_*`/`Crossover_*`/
seasonal XML), per `docs/IMPLEMENTATION_ROADMAP.md` Phase 1.3.

Empty in Phase 1 by design — `DataManager.load_all()` is expected to run
correctly against an empty folder here (see `tests/test_foundation.gd`).
No gameplay content has been authored yet.
