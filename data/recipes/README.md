# data/recipes/

Reserved for converted `ProductionRecipe` `.tres` instances (both GATHER
recipes from mine-type `<Object>` `<Produce>` blocks and CRAFT recipes from
`Items.xml` `type="shopItem"` entries), per
`docs/IMPLEMENTATION_ROADMAP.md` Phase 1.3.

Empty in Phase 1 by design — `DataManager.load_all()` is expected to run
correctly against an empty folder here (see `tests/test_foundation.gd`).
No gameplay content has been authored yet.
