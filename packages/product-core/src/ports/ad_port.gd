extends RefCounted

# AdPort — platform-agnostic in-app ad capability contract.
#
# Pure core seam: no engine, no AdMob, no Toss Ads, no platform types. The base
# implementation is a no-op so the domain/use-case and godot layers can depend
# on this interface while engine adapters (Toss Ads via JS bridge on web/AIT,
# Google AdMob via native plugin) provide the real behaviour.
#
# Placements are stable string ids used for both ad routing (ad group / unit) and
# analytics: "foam_bomb_free" (rewarded), "game_over" (interstitial).
#
# Ads must never block gameplay: every method is safe to call unconditionally and
# no-ops when the platform/SDK is absent. Rewards are delivered via the on_reward
# Callable, which the caller uses to grant the boost. on_reward runs only on a
# genuine reward event (ad watched to completion); dismissed/failed never grant.

# True only when a rewarded ad for `placement` is loaded and ready to show now.
func is_rewarded_ready(_placement: String) -> bool:
	return false

# Show a rewarded ad. `on_reward` is called (zero args) exactly once iff the user
# earns the reward. No-op (and on_reward never fires) when not ready/supported.
func show_rewarded(_placement: String, _on_reward: Callable) -> void:
	pass

# Show a full-screen interstitial for `placement`. Fire-and-forget; no reward.
func show_interstitial(_placement: String) -> void:
	pass

# Called once at startup so adapters can begin preloading inventory.
func setup() -> void:
	pass
