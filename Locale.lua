-- Atlas de chasse · every player-facing string.
-- Keys are English so the code reads in one language; values are what the
-- player sees (French). A missing key falls back to the key, never to nil.
local _, ns = ...

local L = {
	--- Window and sections -----------------------------------------------
	["Atlas de chasse"] = "Atlas de chasse",
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

	--- Filters ----------------------------------------------------------
	["Tameable at your level"] = "Apprivoisable à ton niveau",
	["My faction"] = "Ma faction",
	["My zone"] = "Ma zone",
	["Dungeons"] = "Donjons",
	["No beast matches these filters."] = "Aucune bête ne correspond à ces filtres.",

	--- Detail panel -----------------------------------------------------
	["Arrow + pin"] = "Flèche + repère",
	["Map"] = "Carte",
	["Other beasts are sorted by level."] = "Les autres bêtes sont triées par niveau.",
	["No map for this beast."] = "Pas de carte pour cette bête.",
	["No coordinates."] = "Pas de coordonnées.",
	["Dungeon"] = "Donjon",
	["Rare"] = "Rare",
	["Elite"] = "Élite",
	["Unknown position"] = "Position inconnue",
	["Position vue par toi"] = "Position vue par toi",

	--- Themes -----------------------------------------------------------
	["Theme"] = "Thème",
	["Themes"] = "Thèmes",
	["Theme set to %s."] = "Thème : %s.",
	["Unknown theme %s."] = "Thème inconnu : %s.",
	["Available themes: %s"] = "Thèmes disponibles : %s",

	--- Minimap button, slash command, compartment -----------------------
	["Minimap button hidden."] = "Bouton de minicarte masqué.",
	["Minimap button shown."] = "Bouton de minicarte affiché.",
	["Click: open or close Atlas de chasse"] = "Clic : ouvrir / fermer l'Atlas de chasse",
	["Right-click: themes"] = "Clic droit : thèmes",
	["Drag: move around the minimap"] = "Glisse : déplacer autour de la minicarte",
	["Commands:"] = "Commandes :",
	["/atlas: open or close the window"] = "/atlas : ouvrir / fermer la fenêtre",
	["/atlas theme <name>: switch theme"] = "/atlas theme <nom> : changer de thème",
	["/atlas minimap: show or hide the minimap button"] =
		"/atlas minimap : afficher / masquer le bouton de minicarte",
	["/atlas help: this list"] = "/atlas help : cette liste",
	["Pin placed: %s (%s, %s)."] = "Repère posé : %s (%s, %s).",
	["position de %s notée."] = "position de %s notée.",
	["%s (%s, %s) — no pin on this client, look for it on the map."] =
		"%s (%s, %s) — pas de repère sur ce client, cherche-la sur la carte.",
	["error: %s"] = "erreur : %s",
}

ns.L = setmetatable(L, { __index = function(_, key) return key end })

-- French prints coordinates with a comma ("67,4"), never a dot.
function ns.Coord(value)
	if type(value) ~= "number" then return "?" end
	return (string.format("%.1f", value):gsub("%.", ","))
end

-- "7 to 9 damage" (the data file's English effect) in French, when the shape
-- is the usual one. Anything else is shown untouched.
function ns.Effect(desc)
	if type(desc) ~= "string" or desc == "" then return nil end
	local low, high = desc:match("^(%d+)%s+to%s+(%d+)%s+damage$")
	if low then return low .. "-" .. high .. " dégâts" end
	local min, max = desc:match("^(%d+)%s*%-%s*(%d+)%s+damage$")
	if min then return min .. "-" .. max .. " dégâts" end
	return desc
end
