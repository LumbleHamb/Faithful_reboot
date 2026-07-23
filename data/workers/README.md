# data/workers/

Reserved for converted `WorkerDefinition` `.tres` instances (villager
simulation constants from `Settings.xml` `<Villager>`/`<VillagerSounds>`/
`<AdoptedVillagers>`), per `docs/IMPLEMENTATION_ROADMAP.md` Phase 1.3.

Empty in Phase 1 by design — `DataManager.load_all()` is expected to run
correctly against an empty folder here (see `tests/test_foundation.gd`).
No gameplay content has been authored yet.
