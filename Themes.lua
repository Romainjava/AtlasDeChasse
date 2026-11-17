-- Atlas de chasse · the addon's own colour themes.
-- One token table per theme; every coloured region of the window reads its
-- colour from here through ns.Token, so switching a theme repaints the whole
-- open window at once. Inspired by Polestar's look, no code taken from it.
local _, ns = ...

local function Hex(value)
	local r = tonumber(value:sub(1, 2), 16) / 255
	local g = tonumber(value:sub(3, 4), 16) / 255
	local b = tonumber(value:sub(5, 6), 16) / 255
	return { r = r, g = g, b = b }
end

-- Every token a theme must provide. "line" is the hairline colour.
local TOKENS = {
	"bg", "panel", "alt", "sidebar", "sky", "line",
	"text", "dim", "muted", "accent", "onAccent",
	"ok", "danger", "npc", "place", "spell",
}

local function Theme(key, name, colors)
	local tokens = {}
	for _, token in ipairs(TOKENS) do
		local value = colors[token]
		if type(value) ~= "string" then
			error("theme " .. key .. " misses the token " .. token, 2)
		end
		tokens[token] = Hex(value)
	end
	return { key = key, name = name, tokens = tokens }
end

ns.themeList = {
	Theme("crepuscule", "Crépuscule", {
		bg = "181d2d", panel = "1c2234", alt = "232a3f", sidebar = "121624",
		sky = "283254", line = "3a4360",
		text = "f7f8fd", dim = "c3cadd", muted = "9aa2b9",
		accent = "e6ba66", onAccent = "0a0d14",
		ok = "6bd999", danger = "f57373", npc = "94c9ff", place = "f5ad85", spell = "78dbed",
	}),
	Theme("nuit", "Nuit", {
		bg = "0b0e17", panel = "10141f", alt = "161c2a", sidebar = "070910",
		sky = "1a2340", line = "28324b",
		text = "eef1fa", dim = "b6bdd0", muted = "7d859b",
		accent = "8fb2ff", onAccent = "070a14",
		ok = "6bd999", danger = "f58a8a", npc = "a9d4ff", place = "f2b795", spell = "86e6f5",
	}),
	Theme("graphite", "Graphite", {
		bg = "1b1b1d", panel = "222225", alt = "2b2b2f", sidebar = "141416",
		sky = "34343a", line = "44444b",
		text = "f2f2f4", dim = "c6c6cc", muted = "9a9aa2",
		accent = "d9d9df", onAccent = "141416",
		ok = "8fd7a6", danger = "ef8a8a", npc = "b9d4ea", place = "e6c39f", spell = "a9dbe6",
	}),
	Theme("parchemin", "Parchemin", {
		bg = "f4ecd8", panel = "fbf6e8", alt = "e9dec3", sidebar = "e6d8b7",
		sky = "f7e3b6", line = "c2b08a",
		text = "2a2118", dim = "4c4030", muted = "6d5c46",
		accent = "8a5a12", onAccent = "fdf6e6",
		ok = "2f7a4a", danger = "a83232", npc = "1f5f8b", place = "8a4a20", spell = "1e6d7a",
	}),
}

ns.themeByKey = {}
ns.themeOrder = {}

-- Accents folded so "/atlas theme crepuscule" finds "Crépuscule".
local FOLD = { ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["à"] = "a", ["â"] = "a", ["î"] = "i", ["ô"] = "o", ["û"] = "u", ["ç"] = "c" }

local function Fold(text)
	return (tostring(text):lower():gsub("[éèêàâîôûç]", FOLD))
end
ns.Fold = Fold

for _, theme in ipairs(ns.themeList) do
	ns.themeByKey[Fold(theme.key)] = theme
	ns.themeByKey[Fold(theme.name)] = theme
	ns.themeOrder[#ns.themeOrder + 1] = theme.key
end

-- Theme by key or display name ("parchemin", "Parchemin", "crepuscule").
function ns.Theme(key)
	if type(key) ~= "string" then return nil end
	return ns.themeByKey[Fold(key)]
end

-- The colour of a token in the active theme, as r, g, b.
function ns.Token(token)
	local theme = ns.activeTheme or ns.themeList[1]
	local color = theme.tokens[token]
	if not color then return 1, 0, 1 end
	return color.r, color.g, color.b
end
