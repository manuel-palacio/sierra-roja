class_name Language
extends RefCounted
## Which language the game speaks: English, or Spanish from assets/i18n/es.po. It starts in the
## browser's own language, and a choice made on the briefing is kept in the browser. A page
## address with ?lang=es or ?lang=en starts in that one.
##
## The text in the code and the scenes is the English, and is what the translation is looked up
## by. Labels and buttons translate what they show by themselves; text put together from parts
## is translated where it is put together, with tr().

const CODES: Array[String] = ["en", "es"]
## What each calls itself, for the button that switches to it.
const NAMES := { "en": "English", "es": "Español" }
const STORAGE_KEY := "sierra-roja-language"

static var _restored := false


static func current() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"


## The other of the two.
static func other() -> String:
	return "en" if current() == "es" else "es"


static func choose(code: String) -> void:
	if not code in CODES:
		return
	TranslationServer.set_locale(code)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem('%s','%s')}catch(e){}})()"
				% [STORAGE_KEY, code], true)


## Once in a session: the language of the address, else the one chosen before, else the browser's.
static func restore() -> void:
	if _restored:
		return
	_restored = true
	if not OS.has_feature("web"):
		return
	var asked := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('lang')", true))
	if not asked in CODES:
		asked = str(JavaScriptBridge.eval(
				"(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % STORAGE_KEY, true))
	if asked in CODES:
		TranslationServer.set_locale(asked)
