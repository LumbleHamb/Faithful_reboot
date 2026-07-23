# data/resources/

Reserved for converted `ResourceDefinition` `.tres` instances (one per
original `Resources.xml` entry — Gold, Wood, Rock, Wheat, Wool, Lumber, Cut
Stone, Cloth), per `docs/IMPLEMENTATION_ROADMAP.md` Phase 1.3.

Empty in Phase 1 by design — `DataManager.load_all()` is expected to run
correctly against an empty folder here (see `tests/test_foundation.gd`).
No gameplay content has been authored yet.
