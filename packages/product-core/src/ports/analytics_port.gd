extends RefCounted

# AnalyticsPort — platform-agnostic analytics capability contract.
#
# Pure core seam: no engine, no Firebase, no platform types. The base
# implementation is a no-op so the domain/use-case layers can depend on this
# interface while engine adapters (e.g. Firebase) provide the real behaviour.
#
# Events are fire-and-forget: log_event must never raise, block, or alter
# gameplay state or return values.
func log_event(event_name: String, params: Dictionary = {}) -> void:
	# Base no-op. Concrete adapters override this to forward events.
	pass
