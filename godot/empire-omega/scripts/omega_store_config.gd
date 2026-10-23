extends RefCounted
## Public, non-secret application configuration for authenticated OSGARD purchases.
## Required values come from the operator's real Supabase project AFTER deployment.
## NEVER put sk_live_*, whsec_*, Stripe secret keys or Supabase service_role here.
const SUPABASE_URL = ""
const SUPABASE_PUBLISHABLE_KEY = ""

static func _base() -> String:
	var env: String = OS.get_environment("OSGARD_SUPABASE_URL").strip_edges()
	return (env if not env.is_empty() else SUPABASE_URL).trim_suffix("/")

static func public_key() -> String:
	var env: String = OS.get_environment("OSGARD_SUPABASE_PUBLISHABLE_KEY").strip_edges()
	return env if not env.is_empty() else SUPABASE_PUBLISHABLE_KEY

static func configured() -> bool:
	return _base().begins_with("https://") and not public_key().is_empty()

static func auth_url(resource: String) -> String:
	return _base() + "/auth/v1/" + resource

static func shop_url(resource: String) -> String:
	return _base() + "/functions/v1/osgard-store/" + resource
