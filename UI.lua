-- Atlas de chasse · the window: pet card and ranks on the left, the beasts that
-- teach the chosen rank in the middle, the selected beast and its map on the
-- right. Every coloured region takes its colour from the active theme, so a
-- theme switch repaints the open window through one function (UI.Paint).
local _, ns = ...
local L = ns.L

local UI = {}
ns.ui = UI

-----------------------------------------------------------------------------
-- Measurements (the mock is 820x480)
-----------------------------------------------------------------------------

local W, H = 820, 480
local SIDEBAR_W = 230
local HEADER_H = 62
local CHIPS_H = 30
local DETAIL_W = 220
local ROW_H = 18
local BEAST_ROW_H = 20
local BEAST_MAX = 24
local TABLE_W = 350
local MAP_W, MAP_H = 200, 133

local GROUPS = {
	{ key = "now", title = "Can learn now", max = 5 },
	{ key = "later", title = "Later", max = 5 },
	{ key = "trainer", title = "Pet trainer", max = 4 },
}

local CHIPS = {
	{ key = "tameable", label = "Tameable at your level", width = 152 },
	{ key = "faction", label = "My faction", width = 82 },
	{ key = "zone", label = "My zone", width = 74 },
	{ key = "dungeons", label = "Dungeons", width = 66 },
}

local frame
local painters = {}      -- static regions painted from the theme tokens
local abilityGroups = {}
local beastRows = {}
local chips = {}
local petPortrait, petName, petStats, familyButton, emptyPetText, familyMenu, familyMenuRows
local headerGradient, titleName, titleRank, subtitle, learnedBadge
local gearButton, closeButton
local headName, headLevel, headZone
local scroll, scrollChild, scrollOffset, tableEmpty
local detailName, detailZone, detailHint
local mapFrame, mapArt, mapHint, pinParts
local waypointButton, mapButton
local themeMenu, themeRowList

-----------------------------------------------------------------------------
-- Paint helpers
-----------------------------------------------------------------------------

local function PaintedTexture(parent, layer, token, alpha, sublevel)
	local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	painters[#painters + 1] = { object = texture, kind = "tex", token = token, alpha = alpha }
	return texture
end

local function PaintedText(parent, template, token)
	local text = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
	painters[#painters + 1] = { object = text, kind = "text", token = token }
	return text
end

local function SetTextureColor(texture, token, alpha)
	local r, g, b = ns.Token(token)
	texture:SetColorTexture(r, g, b, alpha or 1)
end

local function SetTextColor(text, token)
	local r, g, b = ns.Token(token)
	text:SetTextColor(r, g, b)
end

local function AbilityName(ability)
	if not ability then return "" end
	return ability.localName or ability.en or "?"
end

-----------------------------------------------------------------------------
-- Build
-----------------------------------------------------------------------------

local function BuildSidebar()
	local sidebar = CreateFrame("Frame", nil, frame)
	sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	sidebar:SetWidth(SIDEBAR_W)
	local background = PaintedTexture(sidebar, "BACKGROUND", "sidebar")
	background:SetAllPoints()
	frame.sidebar = sidebar

	-- Pet card: portrait, name + level, then what the client knows.
	local portraitFrame = CreateFrame("Frame", nil, sidebar)
	portraitFrame:SetSize(44, 44)
	portraitFrame:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 12, -12)
	local ring = PaintedTexture(portraitFrame, "BACKGROUND", "accent")
	ring:SetAllPoints()
	petPortrait = portraitFrame:CreateTexture(nil, "ARTWORK")
	petPortrait:SetPoint("TOPLEFT", 2, -2)
	petPortrait:SetPoint("BOTTOMRIGHT", -2, 2)
	petPortrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- A round mask when the client has one; a square portrait otherwise.
	if petPortrait.AddMaskTexture and portraitFrame.CreateTexture then
		local mask = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		mask:SetAllPoints(petPortrait)
		pcall(petPortrait.AddMaskTexture, petPortrait, mask)
	end

	petName = PaintedText(sidebar, "GameFontNormal", "text")
	petName:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 66, -18)
	petName:SetWidth(150)
	petName:SetJustifyH("LEFT")
	petStats = PaintedText(sidebar, "GameFontHighlightSmall", "dim")
	petStats:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 66, -36)
	petStats:SetWidth(152)
	petStats:SetJustifyH("LEFT")
	petStats:SetWordWrap(true)

	-- Only when the hunter has no pet out: pick a family to browse.
	familyButton = CreateFrame("Button", nil, sidebar)
	familyButton:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 12, -58)
	familyButton:SetSize(206, 18)
	familyButton.label = PaintedText(familyButton, "GameFontNormalSmall", "spell")
	familyButton.label:SetPoint("LEFT", 0, 0)
	familyButton.label:SetJustifyH("LEFT")
	familyButton.highlight = familyButton:CreateTexture(nil, "HIGHLIGHT")
	familyButton.highlight:SetAllPoints()
	familyButton:SetScript("OnClick", function()
		if UI.ToggleFamilyMenu then UI.ToggleFamilyMenu() end
	end)

	emptyPetText = PaintedText(sidebar, "GameFontHighlightSmall", "muted")
	emptyPetText:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 12, -80)
	emptyPetText:SetWidth(206)
	emptyPetText:SetJustifyH("LEFT")
	emptyPetText:SetWordWrap(true)
	emptyPetText:SetText(L["No pet out — bring out your pet to see what it can learn."])

	local y = -114
	for _, definition in ipairs(GROUPS) do
		local group = { key = definition.key, rows = {} }
		group.header = PaintedText(sidebar, "GameFontNormalSmall", "muted")
		group.header:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 12, y)
		group.header:SetText(L[definition.title])
		y = y - 20
		for index = 1, definition.max do
			local row = CreateFrame("Button", nil, sidebar)
			row:SetHeight(ROW_H)
			row:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, y)
			row:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, y)
			row.selected = row:CreateTexture(nil, "BACKGROUND")
			row.selected:SetAllPoints()
			row.selected:Hide()
			row.bar = row:CreateTexture(nil, "BACKGROUND", nil, 1)
			row.bar:SetPoint("TOPLEFT", 0, 0)
			row.bar:SetPoint("BOTTOMLEFT", 0, 0)
			row.bar:SetWidth(3)
			row.bar:Hide()
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetPoint("LEFT", 12, 0)
			row.icon:SetSize(14, 14)
			row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			row.text:SetPoint("LEFT", 32, 0)
			row.text:SetWidth(120)
			row.text:SetJustifyH("LEFT")
			row.suffix = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			row.suffix:SetPoint("RIGHT", -12, 0)
			row.suffix:SetJustifyH("RIGHT")
			row:SetScript("OnClick", function(self)
				if self.entry and ns.SelectPlanEntry then ns.SelectPlanEntry(self.entry) end
			end)
			group.rows[index] = row
			y = y - ROW_H
		end
		y = y - 10
		abilityGroups[#abilityGroups + 1] = group
	end
end

local function BuildMain()
	local main = CreateFrame("Frame", nil, frame)
	main:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W, 0)
	main:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	frame.main = main

	-- Header band: sky fading into the window background.
	local header = CreateFrame("Frame", nil, main)
	header:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
	header:SetHeight(HEADER_H)
	headerGradient = header:CreateTexture(nil, "BACKGROUND")
	headerGradient:SetAllPoints()
	frame.header = header

	titleName = PaintedText(header, "GameFontNormalLarge", "text")
	titleName:SetPoint("TOPLEFT", header, "TOPLEFT", 14, -8)
	titleName:SetJustifyH("LEFT")
	titleRank = PaintedText(header, "GameFontNormalLarge", "accent")
	titleRank:SetPoint("LEFT", titleName, "RIGHT", 6, 0)
	titleRank:SetJustifyH("LEFT")
	subtitle = PaintedText(header, "GameFontHighlightSmall", "dim")
	subtitle:SetPoint("TOPLEFT", header, "TOPLEFT", 14, -28)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetWidth(430)
	learnedBadge = PaintedText(header, "GameFontNormalSmall", "ok")
	learnedBadge:SetPoint("TOPLEFT", header, "TOPLEFT", 14, -44)
	learnedBadge:SetWidth(430)
	learnedBadge:SetJustifyH("LEFT")
	learnedBadge:Hide()

	gearButton = CreateFrame("Button", nil, header)
	gearButton:SetSize(18, 18)
	gearButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -34, -12)
	local gearIcon = gearButton:CreateTexture(nil, "ARTWORK")
	gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	gearIcon:SetAllPoints()
	gearButton:SetScript("OnClick", function() UI.ToggleThemeMenu() end)
	gearButton:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L["Themes"])
		GameTooltip:Show()
	end)
	gearButton:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)

	closeButton = CreateFrame("Button", nil, header)
	closeButton:SetSize(18, 18)
	closeButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -12, -12)
	local closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
	closeIcon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	closeIcon:SetAllPoints()
	closeButton:SetScript("OnClick", function() ns.Close() end)

	-- Filter chips.
	local chipRow = CreateFrame("Frame", nil, main)
	chipRow:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -HEADER_H)
	chipRow:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, -HEADER_H)
	chipRow:SetHeight(CHIPS_H)
	frame.chipRow = chipRow
	local showFaction = ns.Planner.HasZoneFactions()
	local x = 14
	for _, definition in ipairs(CHIPS) do
		-- Without any zone faction in the data the filter could not change anything.
		if definition.key ~= "faction" or showFaction then
			local chip = CreateFrame("Button", nil, chipRow)
			chip:SetSize(definition.width, 18)
			chip:SetPoint("LEFT", chipRow, "LEFT", x, 0)
			chip.key = definition.key
			chip.background = chip:CreateTexture(nil, "BACKGROUND")
			chip.background:SetAllPoints()
			chip.label = chip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			chip.label:SetPoint("CENTER", 0, 0)
			chip.label:SetText(L[definition.label])
			chip:SetScript("OnClick", function(self)
				if ns.ToggleFilter then ns.ToggleFilter(self.key) end
			end)
			chips[#chips + 1] = chip
			x = x + definition.width + 6
		end
	end

	-- Beast table.
	local tableTop = HEADER_H + CHIPS_H
	headName = PaintedText(main, "GameFontNormalSmall", "muted")
	headName:SetPoint("TOPLEFT", main, "TOPLEFT", 12, -(tableTop + 8))
	headName:SetText(L["Beast"])
	headLevel = PaintedText(main, "GameFontNormalSmall", "muted")
	headLevel:SetPoint("TOPLEFT", main, "TOPLEFT", 196, -(tableTop + 8))
	headLevel:SetWidth(50)
	headLevel:SetJustifyH("RIGHT")
	headLevel:SetText(L["Level"])
	headZone = PaintedText(main, "GameFontNormalSmall", "muted")
	headZone:SetPoint("TOPLEFT", main, "TOPLEFT", 252, -(tableTop + 8))
	headZone:SetText(L["Zone"])

	scroll = CreateFrame("ScrollFrame", nil, main)
	scroll:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -(tableTop + 24))
	scroll:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -(DETAIL_W + 12), 12)
	scrollChild = CreateFrame("Frame", nil, scroll)
	scrollChild:SetSize(TABLE_W, BEAST_ROW_H)
	scroll:SetScrollChild(scrollChild)
	scrollOffset = 0

	local function OnWheel(_, delta)
		local maxScroll = math.max(0, (scrollChild:GetHeight() or 0) - (scroll:GetHeight() or 0))
		scrollOffset = math.max(0, math.min(maxScroll, scrollOffset - delta * BEAST_ROW_H * 2))
		scroll:SetVerticalScroll(scrollOffset)
	end
	scroll:SetScript("OnMouseWheel", OnWheel)
	scrollChild:SetScript("OnMouseWheel", OnWheel)

	for index = 1, BEAST_MAX do
		local row = CreateFrame("Button", nil, scrollChild)
		row:SetHeight(BEAST_ROW_H)
		row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * BEAST_ROW_H))
		row:SetWidth(TABLE_W)
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:Hide()
		row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.name:SetPoint("TOPLEFT", 10, -4)
		row.name:SetWidth(180)
		row.name:SetJustifyH("LEFT")
		row.level = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.level:SetPoint("TOPLEFT", 196, -4)
		row.level:SetWidth(50)
		row.level:SetJustifyH("RIGHT")
		row.zone = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.zone:SetPoint("TOPLEFT", 252, -4)
		row.zone:SetWidth(92)
		row.zone:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			if self.entry and ns.SelectBeast then ns.SelectBeast(self.entry.id) end
		end)
		row:SetScript("OnMouseWheel", OnWheel)
		beastRows[index] = row
	end

	tableEmpty = PaintedText(scrollChild, "GameFontHighlightSmall", "muted")
	tableEmpty:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -8)
	tableEmpty:SetWidth(TABLE_W - 20)
	tableEmpty:SetJustifyH("LEFT")
	tableEmpty:SetWordWrap(true)
	tableEmpty:Hide()

	-- Detail panel: selected beast, its map and the waypoint buttons.
	local detail = CreateFrame("Frame", nil, main)
	detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -12, -(tableTop + 8))
	detail:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -12, 12)
	detail:SetWidth(DETAIL_W)
	frame.detail = detail
	local separator = PaintedTexture(detail, "BACKGROUND", "line")
	separator:SetPoint("TOPLEFT", detail, "TOPLEFT", -12, 0)
	separator:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", -12, 0)
	separator:SetWidth(1)

	detailName = PaintedText(detail, "GameFontNormal", "npc")
	detailName:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
	detailName:SetWidth(DETAIL_W)
	detailName:SetJustifyH("LEFT")
	detailZone = PaintedText(detail, "GameFontHighlightSmall", "place")
	detailZone:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -18)
	detailZone:SetWidth(DETAIL_W)
	detailZone:SetJustifyH("LEFT")
	detailZone:SetWordWrap(true)
	detailHint = PaintedText(detail, "GameFontHighlightSmall", "muted")
	detailHint:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -46)
	detailHint:SetWidth(DETAIL_W)
	detailHint:SetJustifyH("LEFT")
	detailHint:SetWordWrap(true)
	detailHint:SetText(L["Other beasts are sorted by level."])

	mapFrame = CreateFrame("Frame", nil, detail)
	mapFrame:SetSize(MAP_W, MAP_H)
	mapFrame:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -70)
	local mapBackground = PaintedTexture(mapFrame, "BACKGROUND", "alt")
	mapBackground:SetAllPoints()
	mapArt = mapFrame:CreateTexture(nil, "BORDER")
	mapArt:SetAllPoints()
	mapArt:Hide()
	mapHint = PaintedText(mapFrame, "GameFontHighlightSmall", "muted")
	mapHint:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", 8, -8)
	mapHint:SetWidth(MAP_W - 16)
	mapHint:SetJustifyH("LEFT")
	mapHint:SetWordWrap(true)

	pinParts = {}
	local ring = mapFrame:CreateTexture(nil, "OVERLAY", nil, 2)
	ring:SetTexture("Interface\\Buttons\\WHITE8X8")
	ring:SetSize(11, 11)
	local hole = mapFrame:CreateTexture(nil, "OVERLAY", nil, 3)
	hole:SetTexture("Interface\\Buttons\\WHITE8X8")
	hole:SetSize(7, 7)
	local dot = mapFrame:CreateTexture(nil, "OVERLAY", nil, 4)
	dot:SetTexture("Interface\\Buttons\\WHITE8X8")
	dot:SetSize(3, 3)
	pinParts.ring, pinParts.hole, pinParts.dot = ring, hole, dot
	ring:Hide()
	hole:Hide()
	dot:Hide()

	waypointButton = CreateFrame("Button", nil, detail)
	waypointButton:SetSize(DETAIL_W, 22)
	waypointButton:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 26)
	waypointButton.background = waypointButton:CreateTexture(nil, "BACKGROUND")
	waypointButton.background:SetAllPoints()
	waypointButton.label = waypointButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	waypointButton.label:SetPoint("CENTER")
	waypointButton.label:SetText(L["Arrow + pin"])
	waypointButton:SetScript("OnClick", function() UI.PlaceWaypoint(ns.state and ns.state.beast) end)

	mapButton = CreateFrame("Button", nil, detail)
	mapButton:SetSize(DETAIL_W, 20)
	mapButton:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 2)
	mapButton.background = mapButton:CreateTexture(nil, "BACKGROUND")
	mapButton.background:SetAllPoints()
	mapButton.label = mapButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	mapButton.label:SetPoint("CENTER")
	mapButton.label:SetText(L["Map"])
	mapButton:SetScript("OnClick", function() UI.OpenMap(ns.state and ns.state.beast) end)
end

function UI.Build()
	if frame then return frame end
	if type(CreateFrame) ~= "function" then return nil end
	frame = CreateFrame("Frame", "AtlasDeChasseFrame", UIParent)
	UI.frame = frame
	ns.ui.frame = frame
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	frame:SetScript("OnHide", function() UI.CloseThemeMenu() end)

	local border = PaintedTexture(frame, "BACKGROUND", "accent", 0.35)
	border:SetAllPoints()
	local background = PaintedTexture(frame, "BACKGROUND", "bg")
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)
	frame.background = background
	frame.border = border

	BuildSidebar()
	BuildMain()

	if type(UISpecialFrames) == "table" then
		local named = true
		for _, name in ipairs(UISpecialFrames) do
			if name == "AtlasDeChasseFrame" then named = false end
		end
		if named then UISpecialFrames[#UISpecialFrames + 1] = "AtlasDeChasseFrame" end
	end

	UI.Paint()
	return frame
end

-----------------------------------------------------------------------------
-- Paint: every colour of the window comes from here
-----------------------------------------------------------------------------

function UI.Paint()
	if not frame then return end
	for _, painter in ipairs(painters) do
		if painter.kind == "text" then
			SetTextColor(painter.object, painter.token)
		else
			SetTextureColor(painter.object, painter.token, painter.alpha)
		end
	end

	local skyR, skyG, skyB = ns.Token("sky")
	local bgR, bgG, bgB = ns.Token("bg")
	headerGradient:SetGradientAlpha("VERTICAL", skyR, skyG, skyB, 1, bgR, bgG, bgB, 1)

	-- Filter chips: pressed ones are filled with the accent colour.
	for _, chip in ipairs(chips) do
		local pressed = ns.state and ns.state.filters and ns.state.filters[chip.key]
		if pressed then
			SetTextureColor(chip.background, "accent")
			SetTextColor(chip.label, "onAccent")
		else
			SetTextureColor(chip.background, "alt")
			SetTextColor(chip.label, "dim")
		end
	end

	-- Rank rows: the selected one carries the accent bar of the mock.
	local selection = ns.state and ns.state.selection
	for _, group in ipairs(abilityGroups) do
		for _, row in ipairs(group.rows) do
			local entry = row.entry
			local selected = entry ~= nil and entry == selection
			row.selected:SetShown(selected)
			row.bar:SetShown(selected)
			if selected then
				SetTextureColor(row.selected, "accent", 0.10)
				SetTextureColor(row.bar, "accent")
			end
			if entry then
				SetTextColor(row.text, selected and "text" or "dim")
				local learned = ns.state and ns.state.learned and entry == selection
				if learned then
					SetTextColor(row.suffix, "ok")
				elseif group.key == "now" then
					SetTextColor(row.suffix, "ok")
				elseif group.key == "trainer" then
					SetTextColor(row.suffix, "muted")
				else
					SetTextColor(row.suffix, "muted")
				end
			end
		end
	end

	-- Beast rows: the selected one is tinted, a beast above the player's level
	-- is red.
	local state = ns.state or {}
	for _, row in ipairs(beastRows) do
		local entry = row.entry
		row.selected:SetShown(entry ~= nil and entry == state.beast)
		if entry then
			if entry == state.beast then SetTextureColor(row.selected, "accent", 0.07) end
			SetTextColor(row.name, "npc")
			SetTextColor(row.level, entry.high and "danger" or "dim")
			SetTextColor(row.zone, "place")
		end
	end

	-- Pin drawn over the map art.
	local ring = pinParts and pinParts.ring
	if ring then
		SetTextureColor(pinParts.ring, "accent")
		SetTextureColor(pinParts.hole, "bg")
		SetTextureColor(pinParts.dot, "accent")
	end

	if themeMenu then
		for _, row in ipairs(themeRowList or {}) do
			local current = row.key == ns.theme
			if current then
				SetTextColor(row.text, "accent")
			else
				SetTextColor(row.text, "dim")
			end
		end
	end
end

-----------------------------------------------------------------------------
-- Beast card of the right panel
-----------------------------------------------------------------------------

local function HidePin()
	for _, part in ipairs({ pinParts.ring, pinParts.hole, pinParts.dot }) do part:Hide() end
end

local function UpdateDetailMap(entry)
	mapArt:Hide()
	HidePin()
	mapHint:Show()
	if not entry then
		mapHint:SetText(L["No map for this beast."])
		return
	end
	mapHint:SetText(entry.zoneName or "")
	if not (entry.map and entry.x and entry.y) then return end
	if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return end
	local okLayers, layers = pcall(C_Map.GetMapArtLayers, entry.map)
	if not okLayers or type(layers) ~= "table" or not layers[1] then return end
	local okTiles, tiles = pcall(C_Map.GetMapArtLayerTextures, entry.map, 1, 0)
	if not okTiles or type(tiles) ~= "table" or not tiles[1] then return end
	mapArt:SetTexture(tiles[1])
	mapArt:Show()
	mapHint:Hide()
	local px = math.floor((entry.x / 100) * MAP_W + 0.5)
	local py = math.floor((entry.y / 100) * MAP_H + 0.5)
	for _, part in ipairs({ pinParts.ring, pinParts.hole, pinParts.dot }) do
		part:ClearAllPoints()
		part:SetPoint("CENTER", mapArt, "TOPLEFT", px, -py)
		part:Show()
	end
end

-----------------------------------------------------------------------------
-- Render: what the window says
-----------------------------------------------------------------------------

local function PetCardText(pet)
	if not pet or not pet.exists then return L["Pet"], "" end
	local familyName = pet.familyName
	local label = familyName or (pet.familyId and ns.Pet.DisplayName(pet.familyId)) or pet.name
	if pet.level and label then label = L["%s %s"]:format(label, tostring(pet.level)) end
	local details = {}
	if pet.points then
		details[#details + 1] = pet.pointsMax
			and L["Points %d / %d"]:format(pet.points, pet.pointsMax)
			or tostring(pet.points)
	end
	if pet.loyalty then details[#details + 1] = L["Loyalty %s"]:format(pet.loyalty) end
	local second
	if #details > 0 then
		second = table.concat(details, " · ")
	else
		second = familyName or ns.Pet.DisplayName(pet.familyId)
	end
	return label, second
end

local function RankSubtitle(rankRecord)
	if not rankRecord then return "" end
	local effect = ns.Planner.Description(rankRecord)
	if rankRecord.petLevel then
		if rankRecord.tp and effect then
			return L["Pet level %d · %d TP · %s"]:format(rankRecord.petLevel, rankRecord.tp, effect)
		elseif rankRecord.tp then
			return L["Pet level %d · %d TP"]:format(rankRecord.petLevel, rankRecord.tp)
		end
		return L["Pet level %d"]:format(rankRecord.petLevel)
	end
	return effect or ""
end

local function SuffixOf(entry, learned)
	if learned then return L["learned"] end
	local rankRecord = ns.Planner.RankAt(entry.ability, entry.rank)
	if not rankRecord then return "" end
	if entry.known and entry.known > 0 then
		return L["%d → %d"]:format(entry.known, entry.rank)
	end
	if rankRecord.petLevel then
		return L["%d · level %d"]:format(entry.rank, rankRecord.petLevel)
	end
	return tostring(entry.rank)
end

function UI.Render()
	if not frame then return end
	local state = ns.state or {}
	local pet = state.pet or {}

	local label, details = PetCardText(pet)
	petName:SetText(label)
	petStats:SetText(details)
	petStats:SetShown(details ~= "")
	familyButton:SetShown(state.browsing and true or false)
	emptyPetText:SetShown(state.browsing and true or false)
	if state.browsing then
		familyButton.label:SetText(L["Family"] .. " : " .. ns.Pet.DisplayName(state.familyId) .. " ▾")
	else
		familyButton.label:SetText("")
	end
	local family = state.familyId and ns.families and ns.families[state.familyId]
	if pet.exists and petPortrait then
		if type(SetPortraitTexture) == "function" then
			pcall(SetPortraitTexture, petPortrait, "pet")
		elseif family and family.icon then
			petPortrait:SetTexture(family.icon)
		end
	elseif family and family.icon then
		petPortrait:SetTexture(family.icon)
	end

	-- Rank rows.
	for _, group in ipairs(abilityGroups) do
		local entries = state.plan and state.plan[group.key] or {}
		for index, row in ipairs(group.rows) do
			local entry = entries[index]
			row.entry = entry
			row:SetShown(entry ~= nil)
			if entry then
				local learned = entry == state.selection and state.learned and true or false
				row.icon:SetTexture(entry.ability.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				row.text:SetText(AbilityName(entry.ability))
				row.suffix:SetText(SuffixOf(entry, learned))
			end
		end
	end

	-- Title: the chosen rank.
	local ability = state.selection and state.selection.ability
	local rankRecord = state.rank
	if ability and rankRecord then
		titleName:SetText(AbilityName(ability))
		titleRank:SetText(L["rank %s"]:format(rankRecord.rank or (state.selection and state.selection.rank) or "?"))
		subtitle:SetText(RankSubtitle(rankRecord))
	else
		titleName:SetText(L["Atlas de chasse"])
		titleRank:SetText("")
		if pet.exists and not pet.familyId then
			subtitle:SetText(L["No family recognized for this pet."])
		else
			subtitle:SetText(L["No pet out — bring out your pet to see what it can learn."])
		end
	end

	learnedBadge:SetText(state.learned and L["Already learned — teach it in Beast Training"] or "")
	learnedBadge:SetShown(state.learned and true or false)

	-- Beast table.
	local teachers = state.teachers or {}
	for index, row in ipairs(beastRows) do
		local entry = teachers[index]
		row.entry = entry
		row:SetShown(entry ~= nil)
		if entry then
			local name = entry.name
			if entry.rare then name = name .. " *" end
			row.name:SetText(name)
			row.level:SetText(entry.levelText)
			row.zone:SetText(entry.zoneName or "")
		end
	end
	scrollChild:SetHeight(math.max(1, math.min(#teachers, BEAST_MAX) * BEAST_ROW_H))
	scrollOffset = 0
	if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
	tableEmpty:SetShown(#teachers == 0)
	if #teachers == 0 then
		tableEmpty:SetText(state.browsing
			and L["No pet out — bring out your pet to see what it can learn."]
			or L["No beast matches these filters."])
	end

	-- Detail panel.
	local beast = state.beast
	if beast then
		detailName:SetText(beast.name)
		local zone = beast.zoneName or ""
		if beast.dungeon then zone = L["Dungeon"] .. " · " .. zone end
		local position
		if beast.x and beast.y then
			position = ns.Coord(beast.x) .. " " .. ns.Coord(beast.y)
		else
			position = L["Unknown position"]
		end
		detailZone:SetText(zone ~= "" and (zone .. " · " .. position) or position)
		-- A position the hunter found themselves is theirs, not the data's.
		detailHint:SetText(beast.seenPosition and L["Position vue par toi"]
			or L["Other beasts are sorted by level."])
		waypointButton:SetShown(beast.map ~= nil and beast.x ~= nil and beast.y ~= nil)
		mapButton:SetShown(beast.map ~= nil)
	else
		detailName:SetText("")
		detailZone:SetText(L["No beast matches these filters."])
		detailHint:SetText("")
		waypointButton:Hide()
		mapButton:Hide()
	end
	UpdateDetailMap(beast)

	UI.Paint()
end

-----------------------------------------------------------------------------
-- Waypoint and world map
-----------------------------------------------------------------------------

function UI.PlaceWaypoint(entry)
	if not entry then return end
	local mapID, x, y = entry.map, entry.x, entry.y
	if not (mapID and x and y) then
		ns.Print(L["No coordinates."])
		return
	end
	-- TomTom, when the player has it (it is not installed on the verified client)
	if TomTom and type(TomTom.AddWaypoint) == "function" then
		local ok = pcall(TomTom.AddWaypoint, TomTom, mapID, x / 100, y / 100, { title = entry.name })
		if ok then
			ns.Print(L["Pin placed: %s (%s, %s)."]:format(entry.name, ns.Coord(x), ns.Coord(y)))
			return
		end
	end
	if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
		local ok = pcall(function()
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
		end)
		if ok then
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
			end
			ns.Print(L["Pin placed: %s (%s, %s)."]:format(entry.name, ns.Coord(x), ns.Coord(y)))
			return
		end
	end
	ns.Print(L["%s (%s, %s) — no pin on this client, look for it on the map."]:format(
		entry.name, ns.Coord(x), ns.Coord(y)))
end

function UI.OpenMap(entry)
	if not entry or not entry.map then return end
	if type(OpenWorldMap) == "function" and pcall(OpenWorldMap, entry.map) then return end
	if WorldMapFrame then
		if not WorldMapFrame:IsShown() then
			if type(ToggleWorldMap) == "function" then
				pcall(ToggleWorldMap)
			elseif type(ShowUIPanel) == "function" then
				pcall(ShowUIPanel, WorldMapFrame)
			end
		end
		if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, entry.map) end
	end
end

-----------------------------------------------------------------------------
-- Theme menu (gear button, right-click on the minimap button, /atlas theme)
-----------------------------------------------------------------------------

local function BuildThemeMenu()
	themeMenu = CreateFrame("Frame", "AtlasDeChasseThemeMenu", UIParent)
	themeMenu:SetFrameStrata("FULLSCREEN_DIALOG")
	themeMenu:SetSize(180, 18 + #ns.themeList * 20 + 8)
	local border = themeMenu:CreateTexture(nil, "BACKGROUND")
	border:SetAllPoints()
	SetTextureColor(border, "line")
	local background = themeMenu:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)
	painters[#painters + 1] = { object = background, kind = "tex", token = "panel" }
	painters[#painters + 1] = { object = border, kind = "tex", token = "line" }

	local title = themeMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText(L["Themes"])
	themeRowList = {}
	for index, theme in ipairs(ns.themeList) do
		local row = CreateFrame("Button", nil, themeMenu)
		row:SetPoint("TOPLEFT", 4, -(8 + index * 20))
		row:SetPoint("TOPRIGHT", -4, -(8 + index * 20))
		row:SetHeight(18)
		row.key = theme.key
		row.background = row:CreateTexture(nil, "HIGHLIGHT")
		row.background:SetAllPoints()
		SetTextureColor(row.background, "alt")
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.text:SetPoint("LEFT", 8, 0)
		row.text:SetText(theme.name)
		row:SetScript("OnClick", function()
			ns.SetTheme(theme.key)
			UI.Paint()
		end)
		themeRowList[#themeRowList + 1] = row
	end
	themeMenu:Hide()
end

function UI.OpenThemeMenu(anchor)
	if not themeMenu then BuildThemeMenu() end
	themeMenu:ClearAllPoints()
	themeMenu:SetPoint("TOPRIGHT", anchor or gearButton or UIParent, "BOTTOMRIGHT", 0, -4)
	themeMenu:Show()
	UI.Paint()
end

function UI.CloseThemeMenu()
	if themeMenu then themeMenu:Hide() end
	if familyMenu then familyMenu:Hide() end
end

function UI.ToggleThemeMenu(anchor)
	if not themeMenu then
		UI.OpenThemeMenu(anchor)
		return
	end
	if themeMenu:IsShown() then themeMenu:Hide() else UI.OpenThemeMenu(anchor) end
end

-----------------------------------------------------------------------------
-- Family dropdown, for browsing without a pet
-----------------------------------------------------------------------------

local function BuildFamilyMenu()
	familyMenu = CreateFrame("Frame", "AtlasDeChasseFamilyMenu", UIParent)
	familyMenu:SetFrameStrata("FULLSCREEN_DIALOG")
	local border = familyMenu:CreateTexture(nil, "BACKGROUND")
	border:SetAllPoints()
	SetTextureColor(border, "line")
	familyMenu.border = border
	local background = familyMenu:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)
	SetTextureColor(background, "panel")
	familyMenu.background = background
	familyMenuRows = {}
	local order = ns.FamilyOrder()
	local columns = #order > 14 and 2 or 1
	local rows = math.ceil(#order / columns)
	familyMenu:SetSize(columns * 110 + 8, rows * 16 + 8)
	for index, familyId in ipairs(order) do
		local column = math.floor((index - 1) / rows)
		local line = (index - 1) % rows
		local row = CreateFrame("Button", nil, familyMenu)
		row:SetPoint("TOPLEFT", 4 + column * 110, -(4 + line * 16))
		row:SetSize(106, 16)
		row.familyId = familyId
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.text:SetPoint("LEFT", 4, 0)
		row.text:SetText(ns.Pet.DisplayName(familyId))
		row:SetScript("OnClick", function()
			familyMenu:Hide()
			if ns.BrowseFamily then ns.BrowseFamily(familyId) end
		end)
		familyMenuRows[#familyMenuRows + 1] = row
	end
	familyMenu:Hide()
end

function UI.ToggleFamilyMenu()
	if not familyMenu then BuildFamilyMenu() end
	if familyMenu:IsShown() then
		familyMenu:Hide()
		return
	end
	familyMenu:ClearAllPoints()
	familyMenu:SetPoint("TOPLEFT", familyButton, "BOTTOMLEFT", 0, -4)
	familyMenu:Show()
end
