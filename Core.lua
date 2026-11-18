-- Atlas de chasse · saved data, hunter detection, the current selection, the
-- events that refresh it, the slash command and the addon compartment.
local addonName, ns = ...
local L = ns.L

local DB_NAME = "AtlasDeChasseDB"
local CHAR_DB_NAME = "AtlasDeChasseCharDB"
local DEFAULT_THEME = "crepuscule"
-- French puts a space before the colon.
local CHAT_PREFIX = "|cffe6ba66" .. L["Hunter's Atlas"] .. "|r" .. (ns.french and " : " or ": ")

local EVENTS = {
	"ADDON_LOADED",
	"PLAYER_LOGIN",
	"UNIT_PET",
	"PET_BAR_UPDATE",
	"SPELLS_CHANGED",
	"UNIT_LEVEL",
	"PLAYER_LEVEL_UP",
	"ZONE_CHANGED_NEW_AREA",
	"PLAYER_TARGET_CHANGED",
	"UPDATE_MOUSEOVER_UNIT",
	"CHAT_MSG_SYSTEM",
	"BAG_UPDATE_DELAYED",
}

-- What the window shows: the pet, the plan, the chosen rank, its teachers.
local state = {
	filters = { tameable = true, faction = true, zone = false, dungeons = false },
}
ns.state = state

function ns.Print(message)
	if type(print) ~= "function" then return end
	print(CHAT_PREFIX .. tostring(message))
end

-----------------------------------------------------------------------------
-- Saved variables
-----------------------------------------------------------------------------

function ns.EnsureDB()
	if type(_G[DB_NAME]) ~= "table" then _G[DB_NAME] = {} end
	local db = _G[DB_NAME]
	if type(db.theme) ~= "string" then db.theme = DEFAULT_THEME end
	if type(db.minimap) ~= "table" then db.minimap = {} end
	if type(db.minimap.angle) ~= "number" then db.minimap.angle = 200 end
	if type(db.minimap.hide) ~= "boolean" then db.minimap.hide = false end
	if type(db.familyNames) ~= "table" then db.familyNames = {} end
	if type(db.seen) ~= "table" then db.seen = {} end

	if type(_G[CHAR_DB_NAME]) ~= "table" then _G[CHAR_DB_NAME] = {} end
	local charDB = _G[CHAR_DB_NAME]
	if type(charDB.learned) ~= "table" then charDB.learned = {} end

	ns.db, ns.charDB = db, charDB
	state.learnedTable = charDB.learned
	local theme = ns.Theme(db.theme) or ns.Theme(DEFAULT_THEME)
	ns.theme = theme.key
	ns.activeTheme = theme
end

-----------------------------------------------------------------------------
-- Client reads (all guarded)
-----------------------------------------------------------------------------

local Guard = ns.Pet.Guard

local function PlayerLevel()
	local level = Guard(UnitLevel, "player")
	if type(level) == "number" and level > 0 then return level end
	return nil
end

local function PlayerFaction()
	local group, english = Guard(UnitFactionGroup, "player")
	if type(group) == "string" and group ~= "" then return group end
	if type(english) == "string" and english ~= "" then return english end
	return nil
end

local function CurrentMap()
	if C_Map and C_Map.GetBestMapForUnit then
		local mapID = Guard(C_Map.GetBestMapForUnit, "player")
		if type(mapID) == "number" then return mapID end
	end
	return nil
end

ns.PlayerLevel, ns.PlayerFaction, ns.CurrentMap = PlayerLevel, PlayerFaction, CurrentMap

-- Families in alphabetical order, for the browse dropdown.
function ns.FamilyOrder()
	local order = {}
	for id in pairs(ns.families or {}) do order[#order + 1] = id end
	table.sort(order, function(a, b)
		local left, right = ns.Pet.DisplayName(a), ns.Pet.DisplayName(b)
		if left ~= right then return left < right end
		return a < b
	end)
	return order
end

-----------------------------------------------------------------------------
-- The plan and the teacher list
-----------------------------------------------------------------------------

local GROUP_ORDER = { "now", "later", "trainer", "maxed" }

local function FindInPlan(plan, abilityKey, rank)
	if not abilityKey or not rank then return nil end
	for _, groupKey in ipairs(GROUP_ORDER) do
		for _, entry in ipairs(plan[groupKey] or {}) do
			if entry.ability.key == abilityKey and entry.rank == rank then return entry end
		end
	end
	return nil
end

local function RecomputeRank()
	local entry = state.selection
	local rankRecord = entry and ns.Planner.RankAt(entry.ability, entry.rank) or nil
	state.rank = rankRecord
	local learned = state.learnedTable or {}
	state.learned = rankRecord ~= nil and rankRecord.spell ~= nil and learned[rankRecord.spell] ~= nil
	state.teachers = ns.Planner.Teachers(rankRecord, {
		playerLevel = PlayerLevel(),
		faction = PlayerFaction(),
		currentMap = CurrentMap(),
		filters = state.filters,
	})
	local chosen
	for _, teacher in ipairs(state.teachers) do
		if teacher.id == state.beastId then chosen = teacher end
	end
	if not chosen then chosen = state.teachers[1] end
	state.beast = chosen
	state.beastId = chosen and chosen.id or nil
end

function ns.Refresh()
	if not ns.db or not ns.isHunter then return end
	ns.state = state
	local pet = ns.Pet.Info()
	state.pet = pet
	if pet.exists then
		state.familyId = pet.familyId
	else
		state.familyId = state.browseFamily or ns.FamilyOrder()[1]
	end
	state.browsing = not pet.exists
	state.plan = ns.Planner.Plan({
		familyId = state.familyId,
		petLevel = pet.exists and pet.level or nil,
		spells = pet.spells,
	})
	local kept = state.selection and FindInPlan(state.plan, state.selection.ability.key, state.selection.rank)
	if not kept then
		kept = state.plan.now[1] or state.plan.later[1] or state.plan.trainer[1] or state.plan.maxed[1]
	end
	state.selection = kept
	RecomputeRank()
	if ns.ui and ns.ui.Render then ns.ui.Render() end
end

function ns.SelectPlanEntry(entry)
	if not entry then return end
	state.selection = entry
	state.beastId = nil
	state.beast = nil
	RecomputeRank()
	if ns.ui and ns.ui.Render then ns.ui.Render() end
end

function ns.SelectBeast(id)
	for _, teacher in ipairs(state.teachers or {}) do
		if teacher.id == id then
			state.beast, state.beastId = teacher, id
			if ns.ui and ns.ui.Render then ns.ui.Render() end
			return
		end
	end
end

function ns.ToggleFilter(filterKey)
	if not filterKey then return end
	state.filters[filterKey] = not state.filters[filterKey]
	RecomputeRank()
	if ns.ui and ns.ui.Render then ns.ui.Render() end
end

function ns.BrowseFamily(familyId)
	if type(familyId) ~= "number" then return end
	state.browseFamily = familyId
	state.selection = nil
	state.beast, state.beastId = nil, nil
	ns.Refresh()
end

-----------------------------------------------------------------------------
-- Themes
-----------------------------------------------------------------------------

function ns.SetTheme(key)
	local theme = ns.Theme(key)
	if not theme then
		ns.Print(L["Unknown theme %s."]:format(tostring(key)))
		ns.Print(L["Available themes: %s"]:format(table.concat(ns.ThemeNames(), ", ")))
		return false
	end
	ns.theme, ns.activeTheme = theme.key, theme
	if ns.db then ns.db.theme = theme.key end
	if ns.ui and ns.ui.Paint then ns.ui.Paint() end
	ns.Print(L["Theme set to %s."]:format(theme.name))
	return true
end

function ns.ThemeNames()
	local names = {}
	for _, theme in ipairs(ns.themeList) do names[#names + 1] = theme.name end
	return names
end

function ns.ToggleThemeMenu()
	if ns.ui and ns.ui.ToggleThemeMenu then ns.ui.ToggleThemeMenu() end
end

-----------------------------------------------------------------------------
-- Learned ranks, from the system messages the client prints when the hunter
-- learns a pet ability ("Vous avez appris un nouveau sort : |Hspell:17257|h…")
-----------------------------------------------------------------------------

function ns.NoteLearned(message)
	if type(message) ~= "string" or not ns.charDB then return false end
	local spellID = tonumber(message:match("|Hspell:(%d+)|h"))
	if not spellID then return false end
	-- only ranks a pet ability really carries: any other spell link is ignored
	if not ns.Planner.RankOf(spellID) then return false end
	if ns.charDB.learned[spellID] then return false end
	ns.charDB.learned[spellID] = type(time) == "function" and time() or 0
	return true
end

-----------------------------------------------------------------------------
-- Window entry points
-----------------------------------------------------------------------------

local function IsHunter()
	local _, class = Guard(UnitClass, "player")
	return class == "HUNTER"
end

function ns.Open()
	if not ns.isHunter or not ns.db then return end
	if type(CreateFrame) ~= "function" then return end
	if ns.ui and ns.ui.Build then ns.ui.Build() end
	-- Build first: the refresh renders into the window it just created.
	ns.Refresh()
	if ns.ui and ns.ui.frame then
		ns.ui.frame:Show()
		if ns.ui.Paint then ns.ui.Paint() end
	end
end

function ns.Close()
	if ns.ui and ns.ui.frame then ns.ui.frame:Hide() end
	if ns.ui and ns.ui.CloseThemeMenu then ns.ui.CloseThemeMenu() end
end

function ns.Toggle()
	if not ns.isHunter or not ns.db then return end
	if ns.ui and ns.ui.frame and ns.ui.frame:IsShown() then
		ns.Close()
	else
		ns.Open()
	end
end

-----------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------

local pending = false

local function RunRefresh()
	pending = false
	local ok, err = pcall(ns.Refresh)
	if not ok then ns.Print(L["error: %s"]:format(tostring(err))) end
end

function ns.QueueRefresh()
	if pending then return end
	pending = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0.2, RunRefresh)
	else
		RunRefresh()
	end
end

-- A beast the hunter targets or points at, close by, teaches the atlas its
-- localized name and where it was seen: the window then names it in its own
-- language. One discreet line the first time a beast the data could not place
-- gets a position, never more.
local function NoteUnit(unit)
	if not (ns.Discovery and ns.Discovery.Watch) then return end
	local ok, sighting = pcall(ns.Discovery.Watch, unit)
	if not ok or type(sighting) ~= "table" then return end
	if sighting.firstSpot then
		local name = ns.Planner.BeastName(ns.beasts and ns.beasts[sighting.id], sighting.id)
		if name == "" then name = sighting.name or "?" end
		ns.Print(L["%s position noted."]:format(name))
	end
	ns.QueueRefresh()
end

local function OnEvent(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then ns.EnsureDB() end
	elseif event == "PLAYER_LOGIN" then
		ns.EnsureDB()
		ns.isHunter = IsHunter()
		if ns.isHunter then
			if ns.SetupMinimap then pcall(ns.SetupMinimap) end
			local ok, err = pcall(ns.Refresh)
			if not ok then ns.Print(L["error: %s"]:format(tostring(err))) end
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		if ns.NoteLearned and ns.NoteLearned(arg1) then
			ns.Refresh()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		NoteUnit("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		NoteUnit("mouseover")
	elseif event == "BAG_UPDATE_DELAYED" then
		-- only the hidden pets page counts items, and only while it is open
		if ns.ui and ns.ui.RenderSecrets and ns.ui.frame and ns.ui.frame:IsShown() then
			ns.ui.RenderSecrets()
		end
	elseif event == "UNIT_PET" then
		if arg1 == nil or arg1 == "player" then ns.QueueRefresh() end
	elseif event == "UNIT_LEVEL" then
		if arg1 == nil or arg1 == "pet" or arg1 == "player" then ns.QueueRefresh() end
	else
		ns.QueueRefresh()
	end
end

if type(CreateFrame) == "function" then
	local events = CreateFrame("Frame", addonName .. "EventFrame")
	if events then
		for _, event in ipairs(EVENTS) do
			if events.RegisterEvent then events:RegisterEvent(event) end
		end
		events:SetScript("OnEvent", OnEvent)
	end
end

-----------------------------------------------------------------------------
-- Slash command: /atlas and /adc (no other addon uses /atlas on this client)
-----------------------------------------------------------------------------

local function PrintHelp()
	ns.Print(L["Commands:"])
	ns.Print("  " .. L["/atlas: open or close the window"])
	ns.Print("  " .. L["/atlas theme <name>: switch theme"])
	ns.Print("  " .. L["/atlas minimap: show or hide the minimap button"])
	ns.Print("  " .. L["/atlas help: this list"])
	ns.Print("  " .. L["Available themes: %s"]:format(table.concat(ns.ThemeNames(), ", ")))
end

local function HandleSlash(message)
	if not ns.db then ns.EnsureDB() end
	local text = tostring(message or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local command, rest = text:match("^(%S*)%s*(.*)$")
	command = (command or ""):lower()
	rest = rest or ""
	if command == "" then
		ns.Toggle()
	elseif command == "theme" or command == "thème" then
		if rest == "" then
			ns.Print(L["Available themes: %s"]:format(table.concat(ns.ThemeNames(), ", ")))
		else
			ns.SetTheme(rest)
		end
	elseif command == "minimap" then
		if ns.db then
			ns.db.minimap.hide = not ns.db.minimap.hide
			if ns.UpdateMinimapButton then pcall(ns.UpdateMinimapButton) end
			ns.Print(ns.db.minimap.hide and L["Minimap button hidden."] or L["Minimap button shown."])
		end
	elseif command == "help" or command == "aide" then
		PrintHelp()
	else
		PrintHelp()
	end
end

if SlashCmdList then
	SLASH_ATLASDECHASSE1 = "/atlas"
	SLASH_ATLASDECHASSE2 = "/adc"
	SlashCmdList["ATLASDECHASSE"] = HandleSlash
end

-----------------------------------------------------------------------------
-- Addon compartment (## AddonCompartmentFunc* in the toc)
-----------------------------------------------------------------------------

function AtlasDeChasse_OnAddonCompartmentClick(_, button)
	if not ns.isHunter or not ns.db then return end
	if button == "RightButton" then
		ns.ToggleThemeMenu()
	else
		ns.Toggle()
	end
end

function AtlasDeChasse_OnAddonCompartmentEnter(_, menuButton)
	if not ns.isHunter or not GameTooltip then return end
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	GameTooltip:AddLine(L["Hunter's Atlas"])
	GameTooltip:AddLine(L["Click: open or close Hunter's Atlas"], 1, 1, 1)
	GameTooltip:AddLine(L["Right-click: themes"], 1, 1, 1)
	GameTooltip:Show()
end

function AtlasDeChasse_OnAddonCompartmentLeave()
	if GameTooltip then GameTooltip:Hide() end
end
