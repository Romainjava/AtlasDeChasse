-- Atlas de chasse · what the atlas says about a beast without opening the
-- window: the verdict lines at the bottom of a teaching beast's tooltip, and one
-- small toast when the hunter targets or points at a beast that teaches a rank
-- the pet can take right now.
-- Both read the same Planner.Verdict the window reads, so a tooltip and the
-- window can never disagree. Every client read is guarded, a GUID the client
-- keeps to itself adds nothing, and the toast stays out of combat.
local _, ns = ...
local L = ns.L

local Guard = ns.Pet.Guard
local Discovery = ns.Discovery
local Planner = ns.Planner

local MEDIA = "Interface\\AddOns\\AtlasDeChasse\\Media\\Fonts\\"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local TOAST_SECONDS = 5
-- The order the lines print in: what to tame first, then what waits for a pet
-- level, then the ranks already settled.
local ORDER = { tame = 1, petLevel = 2, tooHigh = 3, learned = 4, known = 5 }
-- The one colour no theme token carries: the yellow of "pet level needed".
local PET_LEVEL = { 0.94, 0.75, 0.38 }
-- One line per status: its locale key, and the theme token it prints in (or the
-- fixed colour above).
local VERDICT = {
	tame = { "%s %d: tame it", "ok" },
	petLevel = { "%s %d: pet level %d needed", PET_LEVEL },
	tooHigh = { "%s %d: too high for you", "danger" },
	learned = { "%s %d: teach it at Beast Training", "dim" },
	known = { "%s %d: already known", "muted" },
}

local function AbilityName(ability)
	if type(ability) ~= "table" then return "?" end
	return ability.localName or ability.en or "?"
end

local function Color(colour)
	if type(colour) == "table" then return colour[1], colour[2], colour[3] end
	return ns.Token(colour)
end

-- The verdict line of one taught rank, and the colour that carries it.
local function VerdictLine(entry)
	local spec = VERDICT[entry.status]
	if not spec then return nil end
	local name, rank = AbilityName(entry.ability), entry.rank or 0
	if entry.status == "petLevel" then
		return L[spec[1]]:format(name, rank, entry.record.petLevel or 0), spec[2]
	end
	return L[spec[1]]:format(name, rank), spec[2]
end

-- The hunter's side of the verdict: the pet the addon last refreshed, the ranks
-- it knows, the ranks the hunter already learned, its level, and the beast.
local function Context(npcId)
	local pet = (ns.state and ns.state.pet) or {}
	return {
		-- No pet out: every family shows, since one may be tamed later.
		familyId = pet.exists and pet.familyId or nil,
		petLevel = pet.exists and pet.level or nil,
		known = Planner.Known(pet.spells),
		learned = ns.charDB and ns.charDB.learned or nil,
		playerLevel = ns.PlayerLevel and ns.PlayerLevel() or nil,
		beast = ns.beasts and ns.beasts[npcId] or nil,
	}
end

-- Every rank this beast teaches that concerns the pet, "family" dropped, in the
-- order the tooltip prints them.
local function Verdicts(npcId)
	local ctx = Context(npcId)
	local list = {}
	for _, teach in ipairs(Planner.Teaches(npcId)) do
		local status, gain = Planner.Verdict(teach.ability, teach.rank, teach.record, ctx)
		if status and status ~= "family" then
			list[#list + 1] = {
				ability = teach.ability,
				rank = teach.rank,
				record = teach.record,
				status = status,
				gain = gain or 0,
			}
		end
	end
	table.sort(list, function(a, b)
		if a.status ~= b.status then return ORDER[a.status] < ORDER[b.status] end
		if a.gain ~= b.gain then return a.gain > b.gain end
		local left, right = a.record.petLevel or 0, b.record.petLevel or 0
		if left ~= right then return left < right end
		return a.rank < b.rank
	end)
	return list
end

-- The "tame it" rank of a beast worth a toast: the biggest gain first, the
-- lowest pet level breaking the tie.
local function BestTame(list)
	local best
	for _, entry in ipairs(list) do
		if entry.status == "tame" then
			if not best or entry.gain > best.gain
				or (entry.gain == best.gain and (entry.record.petLevel or 0) < (best.record.petLevel or 0)) then
				best = entry
			end
		end
	end
	return best
end

local function InCombat()
	if type(InCombatLockdown) == "function" then
		local ok, locked = pcall(InCombatLockdown)
		if ok and locked == true then return true end
	end
	if type(UnitAffectingCombat) ~= "function" then return false end
	local ok, value = pcall(UnitAffectingCombat, "player")
	if not ok then return true end
	if value == true then return true end
	-- A boolean the client keeps to itself is read as combat: no toast.
	return type(value) ~= "boolean" and value ~= nil
end

------------------------------------------------------------------------------
-- Unit tooltip: "Hunter's Atlas", then one verdict line per taught rank
------------------------------------------------------------------------------

-- The npc id of the creature a tooltip was set on, or nil. This client answers
-- the name first and the unit token second (GetUnit), so the unit is the value
-- whose GUID carries an npc id; a GUID the client keeps secret answers nothing.
local function TooltipNpc(tt)
	if not tt then return nil end
	local first, second = Guard(tt.GetUnit, tt)
	for _, value in ipairs({ second, first }) do
		if type(value) == "string" then
			local npcId = Discovery.NpcId(value)
			if npcId then return npcId end
		end
	end
	return nil
end

-- The npc id already written on a tooltip: a client may call the post-hook more
-- than once for one content, the lines go in once.
local marked = setmetatable({}, { __mode = "k" })

local function AddLines(tt)
	if not ns.isHunter or not ns.db then return end
	local npcId = TooltipNpc(tt)
	if not npcId or marked[tt] == npcId then return end
	local list = Verdicts(npcId)
	if #list == 0 then return end

	-- Everything is computed before the first line: a tooltip never keeps half
	-- a header.
	local lines = {}
	local r, g, b = Color("accent")
	lines[#lines + 1] = { L["Hunter's Atlas"], r, g, b }
	for _, entry in ipairs(list) do
		local text, token = VerdictLine(entry)
		if text then
			local cr, cg, cb = Color(token)
			lines[#lines + 1] = { text, cr, cg, cb }
		end
	end

	marked[tt] = npcId
	for _, line in ipairs(lines) do tt:AddLine(line[1], line[2], line[3], line[4]) end
	-- a line added after the tooltip was shown only resizes it once reshown
	tt:Show()
end

local function SafeAdd(tt)
	local ok = pcall(AddLines, tt)
	if not ok then marked[tt] = nil end
end

if GameTooltip and GameTooltip.HookScript then
	pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(self)
		marked[self] = nil
	end)
end

-- The Unit post-call when the client has it, the tooltip script otherwise.
local hooked = false
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
	hooked = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt)
		if tt == GameTooltip then SafeAdd(tt) end
	end)
end
if not hooked and GameTooltip and GameTooltip.HookScript then
	pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(self)
		SafeAdd(self)
	end)
end

------------------------------------------------------------------------------
-- Toast: one beast that teaches a rank the pet can take now
------------------------------------------------------------------------------

local toast, toastBg, toastBar, toastEdges, toastIcon, toastText, toastHint
local toastRank -- { abilityKey, rank, npcId } of the toast on screen
local generation = 0
local toasted = {} -- [npcId] = true once this session

local HideToast

local function ApplyFont(text, face, size, template)
	local ok, loaded = pcall(text.SetFont, text, MEDIA .. face, size, "")
	if ok and loaded ~= false then return end
	pcall(text.SetFontObject, text, template)
end

-- The colours are taken from the theme each time the toast shows, so a theme
-- switched in the window applies to the next toast.
local function PaintToast()
	local r, g, b = ns.Token("panel")
	toastBg:SetColorTexture(r, g, b, 0.95)
	r, g, b = ns.Token("line")
	for _, edge in ipairs(toastEdges) do edge:SetColorTexture(r, g, b) end
	r, g, b = ns.Token("accent")
	toastBar:SetColorTexture(r, g, b)
	r, g, b = ns.Token("text")
	toastText:SetTextColor(r, g, b)
	r, g, b = ns.Token("muted")
	toastHint:SetTextColor(r, g, b)
end

local function BuildToast()
	if toast or type(CreateFrame) ~= "function" or not UIParent then return toast end
	toast = CreateFrame("Button", "AtlasDeChasseToast", UIParent)
	if not toast then return nil end
	toast:SetSize(300, 38)
	toast:SetPoint("TOP", UIParent, "TOP", 0, -16)
	toast:SetFrameStrata("HIGH")
	toast:SetClampedToScreen(true)
	toast:EnableMouse(true)
	toast:RegisterForClicks("LeftButtonUp")

	toastBg = toast:CreateTexture(nil, "BACKGROUND")
	toastBg:SetAllPoints()

	-- 1px line on three sides, a 3px accent bar standing in for the fourth
	toastBar = toast:CreateTexture(nil, "BORDER")
	toastBar:SetPoint("TOPLEFT")
	toastBar:SetPoint("BOTTOMLEFT")
	toastBar:SetWidth(3)
	local top = toast:CreateTexture(nil, "BORDER")
	top:SetPoint("TOPLEFT", 3, 0)
	top:SetPoint("TOPRIGHT")
	top:SetHeight(1)
	local bottom = toast:CreateTexture(nil, "BORDER")
	bottom:SetPoint("BOTTOMLEFT", 3, 0)
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(1)
	local right = toast:CreateTexture(nil, "BORDER")
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(1)
	toastEdges = { top, bottom, right }

	toastIcon = toast:CreateTexture(nil, "ARTWORK")
	toastIcon:SetSize(22, 22)
	toastIcon:SetPoint("LEFT", 10, 0)

	toastText = toast:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	toastText:SetPoint("TOPLEFT", toastIcon, "TOPRIGHT", 8, 4)
	ApplyFont(toastText, "Inter-Regular.ttf", 13, "GameFontNormal")
	toastHint = toast:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	toastHint:SetPoint("TOPLEFT", toastText, "BOTTOMLEFT", 0, -2)
	ApplyFont(toastHint, "Inter-Regular.ttf", 11, "GameFontHighlightSmall")

	toast:SetScript("OnMouseUp", function(_, button)
		if button and button ~= "LeftButton" then return end
		local rank = toastRank
		HideToast()
		if not rank or not ns.FocusRank then return end
		pcall(ns.FocusRank, rank[1], rank[2], rank[3])
	end)
	toast:Hide()
	return toast
end

-- A new toast, or the click, cancels the timer of the one before: only the
-- toast on screen hides itself.
HideToast = function()
	generation = generation + 1
	toastRank = nil
	if toast then toast:Hide() end
end

local function ShowToast(entry, npcId, beastName)
	if not BuildToast() then return false end
	local r, g, b = Color("spell")
	local rank = ("|cff%02x%02x%02x%s %d|r"):format(
		math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5),
		AbilityName(entry.ability), entry.rank or 0)
	toastText:SetText(L["%s teaches %s"]:format(beastName, rank))
	toastHint:SetText(L["Your pet can learn it · click to open the atlas"])
	toastIcon:SetTexture(entry.ability.icon or DEFAULT_ICON)
	PaintToast()
	-- One line each, never wrapped: the frame follows the longer one.
	local width = math.max(toastText:GetStringWidth() or 0, toastHint:GetStringWidth() or 0)
	toast:SetWidth(math.min(math.max(width + 52, 220), 520))
	toastRank = { entry.ability.key, entry.rank, npcId }
	generation = generation + 1
	local current = generation
	toast:Show()
	if C_Timer and C_Timer.After then
		C_Timer.After(TOAST_SECONDS, function()
			if current == generation then HideToast() end
		end)
	end
	return true
end

local function OnUnit(unit)
	if not ns.isHunter or not ns.db then return end
	if ns.db.alerts == false then return end
	if InCombat() then return end
	local npcId = Discovery.NpcId(unit)
	if not npcId or toasted[npcId] then return end
	local best = BestTame(Verdicts(npcId))
	if not best then return end
	local name = Planner.BeastName(ns.beasts and ns.beasts[npcId], npcId)
	if type(name) ~= "string" or name == "" then name = Guard(UnitName, unit) end
	if type(name) ~= "string" or name == "" then name = "?" end
	if ShowToast(best, npcId, name) then toasted[npcId] = true end
end

local function OnEvent(_, event)
	local unit = event == "PLAYER_TARGET_CHANGED" and "target" or "mouseover"
	local ok, err = pcall(OnUnit, unit)
	if not ok and ns.Print then ns.Print(L["error: %s"]:format(tostring(err))) end
end

if type(CreateFrame) == "function" then
	local events = CreateFrame("Frame", "AtlasDeChasseAlerts")
	if events and events.RegisterEvent then
		events:RegisterEvent("PLAYER_TARGET_CHANGED")
		events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
		events:SetScript("OnEvent", OnEvent)
	end
end
