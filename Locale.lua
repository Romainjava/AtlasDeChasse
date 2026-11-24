-- Atlas de chasse · every player-facing string.
-- Keys are the English text: an English client (or any client but frFR) shows
-- the keys themselves. A French client gets the values below. A missing key
-- falls back to the key, never to nil.
local _, ns = ...

local function ClientLocale()
	if type(GetLocale) ~= "function" then return "enUS" end
	local ok, locale = pcall(GetLocale)
	return ok and locale or "enUS"
end
ns.french = ClientLocale() == "frFR"

local FRENCH = {
	--- Window and sections -----------------------------------------------
	["Hunter's Atlas"] = "Atlas de chasse",
	["Pet"] = "Familier",
	["Family"] = "Famille",
	["Beast"] = "Bête",
	["Level"] = "Niv.",
	["Zone"] = "Zone",
	["Can learn now"] = "Peut apprendre maintenant",
	["Later"] = "Plus tard",
	["Pet trainer"] = "Dresseur de familiers",
	["Maxed out"] = "Au maximum",
	["No pet out — bring out your pet to see what it can learn."] =
		"Sors ton familier pour voir ce qu'il peut apprendre.",
	["Pick a family to browse:"] = "Choisis une famille à parcourir :",
	["No family recognized for this pet."] = "Famille du familier non reconnue.",
	["Unknown spell"] = "Sort inconnu",

	--- Rank line --------------------------------------------------------
	["rank %s"] = "rang %s",
	["Pet level %d · %d TP · %s"] = "Familier niv. %d · %d PD · %s",
	["Pet level %d · %d TP"] = "Familier niv. %d · %d PD",
	["Pet level %d"] = "Familier niv. %d",
	["level %d"] = "niv. %d",
	["%d · level %d"] = "%d · niv. %d",
	["%d → %d"] = "%d → %d",
	["%s %s"] = "%s %s",
	["Points %d / %d · Loyalty %s"] = "PD %d / %d · Loyauté %s",
	["Points %d / %d"] = "PD %d / %d",
	["Loyalty %s"] = "Loyauté %s",
	["Already learned — teach it in Beast Training"] =
		"Déjà appris — à enseigner dans Dressage des bêtes",
	["learned"] = "appris",
	["Ranks"] = "Rangs",
	["Your pet knows it"] = "Ton familier le connaît",
	["Already learned"] = "Déjà appris",
	["Next rank for your pet"] = "Prochain rang de ton familier",
	["Pet level %d needed"] = "Familier niv. %d requis",

	--- Filters ----------------------------------------------------------
	["Tameable at your level"] = "Apprivoisable à ton niveau",
	["My faction"] = "Ma faction",
	["My zone"] = "Ma zone",
	["Dungeons"] = "Donjons",
	["No beast matches these filters."] = "Aucune bête ne correspond à ces filtres.",

	--- Detail panel -----------------------------------------------------
	["Arrow + pin"] = "Flèche + repère",
	["Show on map"] = "Montrer sur la carte",
	["%s shown on the map."] = "%s : point posé sur la carte.",
	["Open the map (M) to see %s: the map cannot open during combat."] =
		"Ouvre la carte (M) pour voir %s : elle ne s'ouvre pas en combat.",
	["Right-click: remove the point"] = "Clic droit : retirer le point",
	["Other beasts are sorted by level."] = "Les autres bêtes sont triées par niveau.",
	["No map for this beast."] = "Pas de carte pour cette bête.",
	["No coordinates."] = "Pas de coordonnées.",
	["Dungeon"] = "Donjon",
	["Rare"] = "Rare",
	["Elite"] = "Élite",
	["Unknown position"] = "Position inconnue",
	["Position you saw"] = "Position vue par toi",

	--- Here tab ---------------------------------------------------------
	["Here"] = "Ici",
	["Tame now"] = "Apprivoise maintenant",
	["When you have the level"] = "Quand tu auras le niveau",
	["Already learned here"] = "Déjà appris ici",
	["+%d more"] = "+%d de plus",
	["%s · %d ranks to take in this zone"] = "%s · %d rangs à prendre dans cette zone",
	["you have %d"] = "tu as %d",
	["pet lvl %d needed"] = "familier niv. %d requis",
	["Nothing to learn in this zone for your pet."] =
		"Rien à apprendre dans cette zone pour ton familier.",
	["Unknown zone: the game does not give your position here."] =
		"Zone inconnue : le jeu ne donne pas ta position ici.",

	--- Sources, data date -----------------------------------------------
	["Verified"] = "Vérifié",
	["confirmed by taming"] = "confirmé par apprivoisement",
	["Seen in game"] = "Vu en jeu",
	["position noted in game"] = "position relevée en jeu",
	["site source"] = "source du site",
	["Data from %s"] = "Données du %s",

	--- Beast tooltip and alert toast (Alerts.lua) -----------------------
	["%s %d: tame it"] = "%s %d : à apprivoiser",
	["%s %d: pet level %d needed"] = "%s %d : familier niv. %d requis",
	["%s %d: too high for you"] = "%s %d : trop haute pour toi",
	["%s %d: already known"] = "%s %d : déjà appris",
	["%s %d: teach it at Beast Training"] = "%s %d : à enseigner au Dressage des bêtes",
	["%s teaches %s"] = "%s enseigne %s",
	["Your pet can learn it · click to open the atlas"] =
		"Ton familier peut l'apprendre · clic pour ouvrir l'atlas",

	--- Hidden pets tab --------------------------------------------------
	["Abilities"] = "Techniques",
	["Hidden pets"] = "Familiers cachés",
	["Found on Forever"] = "Découverts sur Forever",
	["Beasts that only appear after a hidden step."] = "Des bêtes qui n'apparaissent qu'après une étape cachée.",
	["No hidden pet known yet."] = "Aucun familier caché connu pour l'instant.",
	["Level %d / %d"] = "Niveau %d / %d",
	["It knows"] = "Il connaît",
	["Source: %s"] = "Source : %s",

	--- Themes -----------------------------------------------------------
	["Twilight"] = "Crépuscule",
	["Night"] = "Nuit",
	["Graphite"] = "Graphite",
	["Parchment"] = "Parchemin",
	["Theme"] = "Thème",
	["Themes"] = "Thèmes",
	["Theme set to %s."] = "Thème : %s.",
	["Unknown theme %s."] = "Thème inconnu : %s.",
	["Available themes: %s"] = "Thèmes disponibles : %s",

	--- Minimap button, slash command, compartment -----------------------
	["Minimap button hidden."] = "Bouton de minicarte masqué.",
	["Minimap button shown."] = "Bouton de minicarte affiché.",
	["Click: open or close Hunter's Atlas"] = "Clic : ouvrir / fermer l'Atlas de chasse",
	["Right-click: themes"] = "Clic droit : thèmes",
	["Drag: move around the minimap"] = "Glisse : déplacer autour de la minicarte",
	["Commands:"] = "Commandes :",
	["/atlas: open or close the window"] = "/atlas : ouvrir / fermer la fenêtre",
	["/atlas theme <name>: switch theme"] = "/atlas theme <nom> : changer de thème",
	["/atlas minimap: show or hide the minimap button"] =
		"/atlas minimap : afficher / masquer le bouton de minicarte",
	["/atlas alerts: turn beast alerts on or off"] =
		"/atlas alerts : active ou coupe les alertes de bêtes",
	["Beast alerts on."] = "Alertes de bêtes activées.",
	["Beast alerts off."] = "Alertes de bêtes coupées.",
	["/atlas help: this list"] = "/atlas help : cette liste",
	["Pin placed: %s (%s, %s)."] = "Repère posé : %s (%s, %s).",
	["%s position noted."] = "position de %s notée.",
	["%s (%s, %s) — no pin on this client, look for it on the map."] =
		"%s (%s, %s) — pas de repère sur ce client, cherche-la sur la carte.",
	["error: %s"] = "erreur : %s",
}

ns.L = setmetatable(ns.french and FRENCH or {}, { __index = function(_, key) return key end })

-- French prints coordinates with a comma ("67,4"), English with a dot ("67.4").
function ns.Coord(value)
	if type(value) ~= "number" then return "?" end
	local text = string.format("%.1f", value)
	if ns.french then text = text:gsub("%.", ",") end
	return text
end

-- "7 to 9 damage" (the data file's English effect) in French, when the shape
-- is the usual one. Anything else, and every English client, sees it untouched.
function ns.Effect(desc)
	if type(desc) ~= "string" or desc == "" then return nil end
	if not ns.french then return desc end
	local low, high = desc:match("^(%d+)%s+to%s+(%d+)%s+damage$")
	if low then return low .. "-" .. high .. " dégâts" end
	local min, max = desc:match("^(%d+)%s*%-%s*(%d+)%s+damage$")
	if min then return min .. "-" .. max .. " dégâts" end
	return desc
end
