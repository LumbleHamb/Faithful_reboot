# scripts/autoload/currency_manager.gd
# Manages soft and premium currencies (Gold and Magic Beans).
# See docs/ARCHITECTURE.md §2.6
extends Node

# --- Public API ---

func gold() -> float:
	# Gold is Resource ID 1, managed by InventoryManager
	return InventoryManager.amount(1)

func magic_beans() -> float:
	# TODO: Implement this by reading from SaveManager's PlayerState
	return 0.0

func can_afford_bundle(cost: CostBundle) -> bool:
	# TODO: Implement this
	return true

func spend(cost: CostBundle) -> void:
	# TODO: Implement this
	print("[CurrencyManager] Spending from cost bundle (TODO)")

func grant(reward: CostBundle) -> void:
	# TODO: Implement this
	print("[CurrencyManager] Granting from reward bundle (TODO)")

func purchase_store_item(item_id: int) -> void:
	print("[CurrencyManager] Purchasing store item %d (TODO)" % item_id)

func purchase_featured_item(item_id: int) -> void:
	print("[CurrencyManager] Purchasing featured item %d (TODO)" % item_id)
