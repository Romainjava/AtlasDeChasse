-- Atlas de chasse · every player-facing string.
-- Keys are the English text: an English client (or any client but frFR, deDE,
-- esES and esMX) shows the keys themselves. The three tables below are the
-- addon's French, German and Spanish. A missing key falls back to the key,
-- never to nil.
local _, ns = ...

local function ClientLocale()
	if type(GetLocale) ~= "function" then return "enUS" end
	local ok, locale = pcall(GetLocale)
	return ok and locale or "enUS"
end

-- The client's locale, and the language the addon speaks on it: "fr", "de",
-- "es", or nil for English and every other client. esMX reads the Spanish
-- table too; only its beast names differ (see ns.Pick).
ns.locale = ClientLocale()
local LANGUAGES = { frFR = "fr", deDE = "de", esES = "es", esMX = "es" }
ns.lang = LANGUAGES[ns.locale]

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

	--- Site names: the same everywhere, they are brands --------------------
	["Petopia"] = "Petopia",
	["HunterPetJournal"] = "HunterPetJournal",
	["Wowhead"] = "Wowhead",
}

local GERMAN = {
	--- Window and sections -----------------------------------------------
	["Hunter's Atlas"] = "Jägeratlas",
	["Pet"] = "Begleiter",
	["Family"] = "Familie",
	["Beast"] = "Wildtier",
	["Level"] = "Stufe",
	["Zone"] = "Zone",
	["Can learn now"] = "Jetzt lernbar",
	["Later"] = "Später",
	["Pet trainer"] = "Tierausbilder",
	["Maxed out"] = "Maximum erreicht",
	["No pet out — bring out your pet to see what it can learn."] =
		"Kein Begleiter draußen — ruf deinen Begleiter, um zu sehen, was er lernen kann.",
	["Pick a family to browse:"] = "Wähle eine Familie:",
	["No family recognized for this pet."] = "Familie dieses Begleiters nicht erkannt.",
	["Unknown spell"] = "Unbekannter Zauber",

	--- Rank line --------------------------------------------------------
	["rank %s"] = "Rang %s",
	["Pet level %d · %d TP · %s"] = "Begleiter Stufe %d · %d TP · %s",
	["Pet level %d · %d TP"] = "Begleiter Stufe %d · %d TP",
	["Pet level %d"] = "Begleiter Stufe %d",
	["level %d"] = "Stufe %d",
	["%d · level %d"] = "%d · Stufe %d",
	["%d → %d"] = "%d → %d",
	["%s %s"] = "%s %s",
	["Points %d / %d · Loyalty %s"] = "Punkte %d / %d · Loyalität %s",
	["Points %d / %d"] = "Punkte %d / %d",
	["Loyalty %s"] = "Loyalität %s",
	["Already learned — teach it in Beast Training"] =
		"Bereits gelernt — in der Tierausbildung beibringen",
	["learned"] = "gelernt",
	["Ranks"] = "Ränge",
	["Your pet knows it"] = "Dein Begleiter kennt es",
	["Already learned"] = "Bereits gelernt",
	["Next rank for your pet"] = "Nächster Rang für deinen Begleiter",
	["Pet level %d needed"] = "Begleiter Stufe %d nötig",

	--- Filters ----------------------------------------------------------
	["Tameable at your level"] = "Auf deiner Stufe zähmbar",
	["My faction"] = "Meine Fraktion",
	["My zone"] = "Meine Zone",
	["Dungeons"] = "Dungeons",
	["No beast matches these filters."] = "Kein Wildtier passt zu diesen Filtern.",

	--- Detail panel -----------------------------------------------------
	["Arrow + pin"] = "Pfeil + Markierung",
	["Show on map"] = "Auf der Karte zeigen",
	["%s shown on the map."] = "%s auf der Karte markiert.",
	["Open the map (M) to see %s: the map cannot open during combat."] =
		"Öffne die Karte (M), um %s zu sehen: im Kampf öffnet sie sich nicht.",
	["Right-click: remove the point"] = "Rechtsklick: Markierung entfernen",
	["Other beasts are sorted by level."] = "Die übrigen Wildtiere sind nach Stufe sortiert.",
	["No map for this beast."] = "Keine Karte für dieses Wildtier.",
	["No coordinates."] = "Keine Koordinaten.",
	["Dungeon"] = "Dungeon",
	["Rare"] = "Selten",
	["Elite"] = "Elite",
	["Unknown position"] = "Position unbekannt",
	["Position you saw"] = "Von dir gesehene Position",

	--- Here tab ---------------------------------------------------------
	["Here"] = "Hier",
	["Tame now"] = "Jetzt zähmen",
	["When you have the level"] = "Wenn du die Stufe hast",
	["Already learned here"] = "Hier bereits gelernt",
	["+%d more"] = "+%d weitere",
	["%s · %d ranks to take in this zone"] = "%s · %d Ränge in dieser Zone zu holen",
	["you have %d"] = "du hast %d",
	["pet lvl %d needed"] = "Begleiter Stufe %d nötig",
	["Nothing to learn in this zone for your pet."] =
		"In dieser Zone gibt es nichts für deinen Begleiter zu lernen.",
	["Unknown zone: the game does not give your position here."] =
		"Unbekannte Zone: das Spiel gibt deine Position hier nicht an.",

	--- Sources, data date -----------------------------------------------
	["Verified"] = "Bestätigt",
	["confirmed by taming"] = "durch Zähmen bestätigt",
	["Seen in game"] = "Im Spiel gesehen",
	["position noted in game"] = "Position im Spiel notiert",
	["site source"] = "Quelle der Seite",
	["Data from %s"] = "Daten vom %s",

	--- Beast tooltip and alert toast (Alerts.lua) -----------------------
	["%s %d: tame it"] = "%s %d: zähmen",
	["%s %d: pet level %d needed"] = "%s %d: Begleiter Stufe %d nötig",
	["%s %d: too high for you"] = "%s %d: zu hoch für dich",
	["%s %d: already known"] = "%s %d: bereits bekannt",
	["%s %d: teach it at Beast Training"] = "%s %d: in der Tierausbildung beibringen",
	["%s teaches %s"] = "%s lehrt %s",
	["Your pet can learn it · click to open the atlas"] =
		"Dein Begleiter kann es lernen · Klick öffnet den Atlas",

	--- Hidden pets tab --------------------------------------------------
	["Abilities"] = "Fähigkeiten",
	["Hidden pets"] = "Versteckte Begleiter",
	["Found on Forever"] = "Auf Forever gefunden",
	["Beasts that only appear after a hidden step."] =
		"Wildtiere, die erst nach einem versteckten Schritt erscheinen.",
	["No hidden pet known yet."] = "Noch kein versteckter Begleiter bekannt.",
	["Level %d / %d"] = "Stufe %d / %d",
	["It knows"] = "Es kennt",
	["Source: %s"] = "Quelle: %s",

	--- Themes -----------------------------------------------------------
	["Twilight"] = "Dämmerung",
	["Night"] = "Nacht",
	["Graphite"] = "Graphit",
	["Parchment"] = "Pergament",
	["Theme"] = "Design",
	["Themes"] = "Designs",
	["Theme set to %s."] = "Design: %s.",
	["Unknown theme %s."] = "Unbekanntes Design: %s.",
	["Available themes: %s"] = "Verfügbare Designs: %s",

	--- Minimap button, slash command, compartment -----------------------
	["Minimap button hidden."] = "Minikartenknopf ausgeblendet.",
	["Minimap button shown."] = "Minikartenknopf eingeblendet.",
	["Click: open or close Hunter's Atlas"] = "Klick: Jägeratlas öffnen oder schließen",
	["Right-click: themes"] = "Rechtsklick: Designs",
	["Drag: move around the minimap"] = "Ziehen: um die Minikarte bewegen",
	["Commands:"] = "Befehle:",
	["/atlas: open or close the window"] = "/atlas: Fenster öffnen oder schließen",
	["/atlas theme <name>: switch theme"] = "/atlas theme <Name>: Design wechseln",
	["/atlas minimap: show or hide the minimap button"] =
		"/atlas minimap: Minikartenknopf ein- oder ausblenden",
	["/atlas alerts: turn beast alerts on or off"] =
		"/atlas alerts: Wildtier-Alarme ein- oder ausschalten",
	["Beast alerts on."] = "Wildtier-Alarme an.",
	["Beast alerts off."] = "Wildtier-Alarme aus.",
	["/atlas help: this list"] = "/atlas help: diese Liste",
	["Pin placed: %s (%s, %s)."] = "Markierung gesetzt: %s (%s, %s).",
	["%s position noted."] = "Position von %s notiert.",
	["%s (%s, %s) — no pin on this client, look for it on the map."] =
		"%s (%s, %s) — keine Markierung auf diesem Client, such es auf der Karte.",
	["error: %s"] = "Fehler: %s",

	--- Site names: the same everywhere, they are brands ------------------
	["Petopia"] = "Petopia",
	["HunterPetJournal"] = "HunterPetJournal",
	["Wowhead"] = "Wowhead",
}

local SPANISH = {
	--- Window and sections -----------------------------------------------
	["Hunter's Atlas"] = "Atlas del cazador",
	["Pet"] = "Mascota",
	["Family"] = "Familia",
	["Beast"] = "Bestia",
	["Level"] = "Nivel",
	["Zone"] = "Zona",
	["Can learn now"] = "Puede aprenderlo ya",
	["Later"] = "Más tarde",
	["Pet trainer"] = "Instructor de mascotas",
	["Maxed out"] = "Al máximo",
	["No pet out — bring out your pet to see what it can learn."] =
		"No tienes mascota — llama a tu mascota para ver qué puede aprender.",
	["Pick a family to browse:"] = "Elige una familia:",
	["No family recognized for this pet."] = "No se reconoce la familia de esta mascota.",
	["Unknown spell"] = "Hechizo desconocido",

	--- Rank line --------------------------------------------------------
	["rank %s"] = "rango %s",
	["Pet level %d · %d TP · %s"] = "Mascota nivel %d · %d PA · %s",
	["Pet level %d · %d TP"] = "Mascota nivel %d · %d PA",
	["Pet level %d"] = "Mascota nivel %d",
	["level %d"] = "nivel %d",
	["%d · level %d"] = "%d · nivel %d",
	["%d → %d"] = "%d → %d",
	["%s %s"] = "%s %s",
	["Points %d / %d · Loyalty %s"] = "Puntos %d / %d · Lealtad %s",
	["Points %d / %d"] = "Puntos %d / %d",
	["Loyalty %s"] = "Lealtad %s",
	["Already learned — teach it in Beast Training"] =
		"Ya aprendido — enséñalo en Adiestramiento de bestias",
	["learned"] = "aprendido",
	["Ranks"] = "Rangos",
	["Your pet knows it"] = "Tu mascota lo conoce",
	["Already learned"] = "Ya aprendido",
	["Next rank for your pet"] = "Siguiente rango para tu mascota",
	["Pet level %d needed"] = "Mascota nivel %d necesario",

	--- Filters ----------------------------------------------------------
	["Tameable at your level"] = "Domable a tu nivel",
	["My faction"] = "Mi facción",
	["My zone"] = "Mi zona",
	["Dungeons"] = "Mazmorras",
	["No beast matches these filters."] = "Ninguna bestia coincide con estos filtros.",

	--- Detail panel -----------------------------------------------------
	["Arrow + pin"] = "Flecha + marca",
	["Show on map"] = "Mostrar en el mapa",
	["%s shown on the map."] = "%s marcado en el mapa.",
	["Open the map (M) to see %s: the map cannot open during combat."] =
		"Abre el mapa (M) para ver %s: no se abre en combate.",
	["Right-click: remove the point"] = "Clic derecho: quitar la marca",
	["Other beasts are sorted by level."] = "Las demás bestias están ordenadas por nivel.",
	["No map for this beast."] = "No hay mapa para esta bestia.",
	["No coordinates."] = "Sin coordenadas.",
	["Dungeon"] = "Mazmorra",
	["Rare"] = "Raro",
	["Elite"] = "Élite",
	["Unknown position"] = "Posición desconocida",
	["Position you saw"] = "Posición que viste",

	--- Here tab ---------------------------------------------------------
	["Here"] = "Aquí",
	["Tame now"] = "Domar ahora",
	["When you have the level"] = "Cuando tengas el nivel",
	["Already learned here"] = "Ya aprendido aquí",
	["+%d more"] = "+%d más",
	["%s · %d ranks to take in this zone"] = "%s · %d rangos que coger en esta zona",
	["you have %d"] = "tienes %d",
	["pet lvl %d needed"] = "mascota nivel %d necesario",
	["Nothing to learn in this zone for your pet."] =
		"No hay nada que aprender en esta zona para tu mascota.",
	["Unknown zone: the game does not give your position here."] =
		"Zona desconocida: el juego no da tu posición aquí.",

	--- Sources, data date -----------------------------------------------
	["Verified"] = "Verificado",
	["confirmed by taming"] = "confirmado al domar",
	["Seen in game"] = "Visto en el juego",
	["position noted in game"] = "posición anotada en el juego",
	["site source"] = "fuente del sitio",
	["Data from %s"] = "Datos del %s",

	--- Beast tooltip and alert toast (Alerts.lua) -----------------------
	["%s %d: tame it"] = "%s %d: dómalo",
	["%s %d: pet level %d needed"] = "%s %d: mascota nivel %d necesario",
	["%s %d: too high for you"] = "%s %d: demasiado alto para ti",
	["%s %d: already known"] = "%s %d: ya conocido",
	["%s %d: teach it at Beast Training"] = "%s %d: enséñalo en Adiestramiento de bestias",
	["%s teaches %s"] = "%s enseña %s",
	["Your pet can learn it · click to open the atlas"] =
		"Tu mascota puede aprenderlo · haz clic para abrir el atlas",

	--- Hidden pets tab --------------------------------------------------
	["Abilities"] = "Habilidades",
	["Hidden pets"] = "Mascotas ocultas",
	["Found on Forever"] = "Descubiertas en Forever",
	["Beasts that only appear after a hidden step."] =
		"Bestias que solo aparecen tras un paso oculto.",
	["No hidden pet known yet."] = "Aún no se conoce ninguna mascota oculta.",
	["Level %d / %d"] = "Nivel %d / %d",
	["It knows"] = "Conoce",
	["Source: %s"] = "Fuente: %s",

	--- Themes -----------------------------------------------------------
	["Twilight"] = "Crepúsculo",
	["Night"] = "Noche",
	["Graphite"] = "Grafito",
	["Parchment"] = "Pergamino",
	["Theme"] = "Tema",
	["Themes"] = "Temas",
	["Theme set to %s."] = "Tema: %s.",
	["Unknown theme %s."] = "Tema desconocido: %s.",
	["Available themes: %s"] = "Temas disponibles: %s",

	--- Minimap button, slash command, compartment -----------------------
	["Minimap button hidden."] = "Botón del minimapa oculto.",
	["Minimap button shown."] = "Botón del minimapa visible.",
	["Click: open or close Hunter's Atlas"] = "Clic: abrir o cerrar el Atlas del cazador",
	["Right-click: themes"] = "Clic derecho: temas",
	["Drag: move around the minimap"] = "Arrastra: mover alrededor del minimapa",
	["Commands:"] = "Comandos:",
	["/atlas: open or close the window"] = "/atlas: abrir o cerrar la ventana",
	["/atlas theme <name>: switch theme"] = "/atlas theme <nombre>: cambiar de tema",
	["/atlas minimap: show or hide the minimap button"] =
		"/atlas minimap: mostrar u ocultar el botón del minimapa",
	["/atlas alerts: turn beast alerts on or off"] =
		"/atlas alerts: activar o desactivar las alertas de bestias",
	["Beast alerts on."] = "Alertas de bestias activadas.",
	["Beast alerts off."] = "Alertas de bestias desactivadas.",
	["/atlas help: this list"] = "/atlas help: esta lista",
	["Pin placed: %s (%s, %s)."] = "Marca puesta: %s (%s, %s).",
	["%s position noted."] = "posición de %s anotada.",
	["%s (%s, %s) — no pin on this client, look for it on the map."] =
		"%s (%s, %s) — sin marca en este cliente, búscalo en el mapa.",
	["error: %s"] = "error: %s",

	--- Site names: the same everywhere, they are brands ------------------
	["Petopia"] = "Petopia",
	["HunterPetJournal"] = "HunterPetJournal",
	["Wowhead"] = "Wowhead",
}

local TABLES = { fr = FRENCH, de = GERMAN, es = SPANISH }
ns.L = setmetatable(TABLES[ns.lang] or {}, { __index = function(_, key) return key end })

-- The pet families of the data file in the addon's three languages, keyed by
-- the English family name the data carries. Pet.lua displays them and matches
-- the name the client hands over; the game's own name always comes first, so a
-- name that differs only costs the fallback. The Spanish ones are the esES
-- client's (HunterPetJournal's `es` names), the French and German ones were read
-- off the client and the localised addon data.
ns.familyNames = {
	fr = {
		["Wolf"] = "Loup",
		["Cat"] = "Félin",
		["Spider"] = "Araignée",
		["Bear"] = "Ours",
		["Boar"] = "Sanglier",
		["Crocolisk"] = "Crocilisque",
		["Carrion Bird"] = "Charognard",
		["Crab"] = "Crabe",
		["Gorilla"] = "Gorille",
		["Raptor"] = "Raptor",
		["Tallstrider"] = "Haut-trotteur",
		["Scorpid"] = "Scorpide",
		["Turtle"] = "Tortue",
		["Bat"] = "Chauve-souris",
		["Hyena"] = "Hyène",
		["Bird of Prey"] = "Oiseau de proie",
		["Owl"] = "Chouette",
		["Wind Serpent"] = "Serpent des vents",
		["Windserpent"] = "Serpent des vents",
		["Fox"] = "Renard",
	},
	de = {
		["Wolf"] = "Wolf",
		["Cat"] = "Katze",
		["Spider"] = "Spinne",
		["Bear"] = "Bär",
		["Boar"] = "Eber",
		["Crocolisk"] = "Krokilisk",
		["Carrion Bird"] = "Aasvogel",
		["Crab"] = "Krebs",
		["Gorilla"] = "Gorilla",
		["Raptor"] = "Raptor",
		["Tallstrider"] = "Weitschreiter",
		["Scorpid"] = "Skorpid",
		["Turtle"] = "Schildkröte",
		["Bat"] = "Fledermaus",
		["Hyena"] = "Hyäne",
		["Bird of Prey"] = "Raubvogel",
		["Owl"] = "Eule",
		["Wind Serpent"] = "Windnatter",
		["Windserpent"] = "Windnatter",
		["Fox"] = "Fuchs",
	},
	es = {
		["Wolf"] = "Lobo",
		["Cat"] = "Felino",
		["Spider"] = "Araña",
		["Bear"] = "Oso",
		["Boar"] = "Jabalí",
		["Crocolisk"] = "Crocolisco",
		["Carrion Bird"] = "Carroñero",
		["Crab"] = "Cangrejo",
		["Gorilla"] = "Gorila",
		["Raptor"] = "Raptor",
		["Tallstrider"] = "Zancudo",
		["Scorpid"] = "Escórpido",
		["Turtle"] = "Tortuga",
		["Bat"] = "Murciélago",
		["Hyena"] = "Hiena",
		["Bird of Prey"] = "Ave rapaz",
		["Owl"] = "Lechuza",
		["Wind Serpent"] = "Serpiente alada",
		["Windserpent"] = "Serpiente alada",
		["Fox"] = "Zorro",
	},
}

-- The name field this client reads: the record's own language, and on a
-- Spanish (Mexico) client the "mx" name first, since the esMX client names a
-- share of the beasts differently from esES.
local function Localized(record)
	if ns.lang == "es" and ns.locale == "esMX" and type(record.mx) == "string" and record.mx ~= "" then
		return record.mx
	end
	local text = ns.lang and record[ns.lang]
	if type(text) == "string" and text ~= "" then return text end
	return nil
end

-- A record's text ({ en = ..., fr = ..., de = ..., es = ..., mx = ... }) in the
-- client's language, and the English one when it has none. The one place that
-- decides which field a client reads: beast names, secret steps, item names.
function ns.Pick(record)
	if type(record) ~= "table" then return nil end
	return Localized(record) or record.en
end

-- The same, without the English fallback: nil when the record has no name in
-- the client's language (Discovery merges the one the hunter learned in game).
function ns.Localized(record)
	if type(record) ~= "table" then return nil end
	return Localized(record)
end

-- French, German and Spanish print coordinates with a comma ("67,4"); English
-- with a dot ("67.4").
function ns.Coord(value)
	if type(value) ~= "number" then return "?" end
	local text = string.format("%.1f", value)
	if ns.lang then text = text:gsub("%.", ",") end
	return text
end

-- "7 to 9 damage" (the data file's English effect) in the client's language,
-- when the shape is the usual one. Anything else, and every English client,
-- sees it untouched.
local EFFECTS = {
	fr = " dégâts",
	de = " Schaden",
	es = " de daño",
}
function ns.Effect(desc)
	if type(desc) ~= "string" or desc == "" then return nil end
	local suffix = ns.lang and EFFECTS[ns.lang]
	if not suffix then return desc end
	local low, high = desc:match("^(%d+)%s+to%s+(%d+)%s+damage$")
	if not low then low, high = desc:match("^(%d+)%s*%-%s*(%d+)%s+damage$") end
	if not low then return desc end
	-- German typography writes a range with an en dash, French and Spanish with a hyphen
	local dash = ns.lang == "de" and "–" or "-"
	return low .. dash .. high .. suffix
end
