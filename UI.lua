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
local CARD_H = 68
local HEADER_H = 62
local CHIPS_H = 36
local CHIP_H = 22
local TABLE_HEAD_H = 26
local DETAIL_W = 200
local ROW_H = 21
local GROUP_HEAD_H = 22
local GROUP_GAP = 8
local BEAST_ROW_H = 24
local BEAST_MAX = 24
local TABLE_W = 364
local MAP_W, MAP_H = 200, 133
local BUTTON_H = 24

-----------------------------------------------------------------------------
-- Fonts and media. Inter (SIL OFL, Media\Fonts\Inter-OFL.txt) draws "→", which
-- the game font lacks; if it cannot load, every font falls back to the game's.
-----------------------------------------------------------------------------

local MEDIA = "Interface\\AddOns\\AtlasDeChasse\\Media\\"
local DISC = MEDIA .. "disc"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FACES = {
	regular = MEDIA .. "Fonts\\Inter-Regular.ttf",
	semibold = MEDIA .. "Fonts\\Inter-SemiBold.ttf",
}
local FONTS = {
	title = { "AtlasDeChasseFontTitle", "semibold", 17 },
	name = { "AtlasDeChasseFontName", "semibold", 13 },
	body = { "AtlasDeChasseFontBody", "regular", 12 },
	strong = { "AtlasDeChasseFontStrong", "semibold", 12 },
	small = { "AtlasDeChasseFontSmall", "regular", 11 },
	label = { "AtlasDeChasseFontLabel", "semibold", 11 },
}

-- Creates the font objects once; true when Inter loaded for all of them.
local function CreateFonts()
	if type(CreateFont) ~= "function" then return false end
	local fallback = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	local all = true
	for _, spec in pairs(FONTS) do
		local name, face, size = spec[1], spec[2], spec[3]
		local font = _G[name] or CreateFont(name)
		local ok, loaded = pcall(font.SetFont, font, FACES[face], size, "")
		if not (ok and loaded ~= false and font:GetFont()) then
			all = false
			font:SetFont(fallback, size, "")
		end
	end
	return all
end

-- At load: the theme menu can open from the minimap button before the window.
ns.fontReady = CreateFonts()

-- The font template of a role ("body", "label", ...).
local function Font(role)
	return FONTS[role][1]
end

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
local detailMap
local waypointButton, mapButton
local themeMenu, themeRowList

-- Header tabs: the rank planner, or the hidden pets page.
local VIEWS = {
	{ key = "abilities", label = "Abilities" },
	{ key = "secrets", label = "Hidden pets" },
}
local view = "abilities"
local tabs = {}
local secretList, secretBody, secretRows, secretSelected
local secretName, secretTitle, secretZone, secretSteps, secretAbilities, secretSource
local secretMap, secretPills, secretButtons = nil, {}, {}
local SECRET_STEPS_MAX = 6
local SECRET_PANEL_W = 224

-----------------------------------------------------------------------------
-- Paint helpers
-----------------------------------------------------------------------------

local function PaintedTexture(parent, layer, token, alpha, sublevel)
	local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	painters[#painters + 1] = { object = texture, kind = "tex", token = token, alpha = alpha }
	return texture
end

local function PaintedText(parent, role, token)
	local text = parent:CreateFontString(nil, "ARTWORK", Font(role))
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

-- A one-pixel line in the theme's hairline colour.
local function Hairline(parent, alpha)
	return PaintedTexture(parent, "BORDER", "line", alpha)
end

-- A pill filling `owner`: two half discs for the round ends and a band between.
-- Its colour is set with SetPillColor, never with SetColorTexture.
local function Pill(owner, layer, sublevel)
	local height = owner:GetHeight()
	local pill = {}
	pill.left = owner:CreateTexture(nil, layer, nil, sublevel)
	pill.left:SetTexture(DISC)
	pill.left:SetTexCoord(0, 0.5, 0, 1)
	pill.left:SetPoint("TOPLEFT")
	pill.left:SetPoint("BOTTOMLEFT")
	pill.left:SetWidth(height / 2)
	pill.right = owner:CreateTexture(nil, layer, nil, sublevel)
	pill.right:SetTexture(DISC)
	pill.right:SetTexCoord(0.5, 1, 0, 1)
	pill.right:SetPoint("TOPRIGHT")
	pill.right:SetPoint("BOTTOMRIGHT")
	pill.right:SetWidth(height / 2)
	pill.middle = owner:CreateTexture(nil, layer, nil, sublevel)
	pill.middle:SetTexture(WHITE)
	pill.middle:SetPoint("TOPLEFT", pill.left, "TOPRIGHT")
	pill.middle:SetPoint("BOTTOMRIGHT", pill.right, "BOTTOMLEFT")
	return pill
end

local function SetPillColor(pill, token, alpha)
	local r, g, b = ns.Token(token)
	for _, part in ipairs({ pill.left, pill.middle, pill.right }) do
		part:SetVertexColor(r, g, b, alpha or 1)
	end
end

-- A rounded button: a pill behind a centred label. Paint sets its colours
-- (accent fill for the primary button, the alternate panel for the other).
local function PillButton(parent, width, label, primary)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, BUTTON_H)
	button.pill = Pill(button, "BACKGROUND")
	button.hover = Pill(button, "HIGHLIGHT")
	button.label = button:CreateFontString(nil, "ARTWORK", Font(primary and "label" or "small"))
	button.label:SetPoint("CENTER")
	button.label:SetText(label)
	button.primary = primary
	return button
end

local function PaintPillButton(button)
	SetPillColor(button.pill, button.primary and "accent" or "alt")
	SetPillColor(button.hover, "text", 0.08)
	SetTextColor(button.label, button.primary and "onAccent" or "dim")
end

local function AbilityName(ability)
	if not ability then return "" end
	return ability.localName or ability.en or "?"
end

-- A small zone map (the detail panel's, the hidden pet page's): the zone art,
-- a pin, and a hint in place of the art when the client gives none.
local function NewMiniMap(parent)
	local mini = { tiles = {}, pin = {} }
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(MAP_W, MAP_H)
	local background = PaintedTexture(holder, "BACKGROUND", "alt")
	background:SetAllPoints()
	local edge = PaintedTexture(holder, "BACKGROUND", "line", nil, -1)
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	mini.frame = holder
	mini.hint = PaintedText(holder, "small", "muted")
	mini.hint:SetPoint("TOPLEFT", holder, "TOPLEFT", 8, -8)
	mini.hint:SetWidth(MAP_W - 16)
	mini.hint:SetJustifyH("LEFT")
	mini.hint:SetWordWrap(true)
	-- the pin: an accent ring, a hole of the background colour, an accent dot
	for _, part in ipairs({ { 14, 2, "accent" }, { 9, 3, "bg" }, { 5, 4, "accent" } }) do
		local disc = holder:CreateTexture(nil, "OVERLAY", nil, part[2])
		disc:SetTexture(DISC)
		disc:SetSize(part[1], part[1])
		disc:Hide()
		painters[#painters + 1] = { object = disc, kind = "vertex", token = part[3] }
		mini.pin[#mini.pin + 1] = disc
	end
	return mini
end

-----------------------------------------------------------------------------
-- Build
-----------------------------------------------------------------------------

local function BuildSidebar()
	local sidebar = CreateFrame("Frame", nil, frame)
	sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	sidebar:SetWidth(SIDEBAR_W - 1)
	local background = PaintedTexture(sidebar, "BACKGROUND", "sidebar")
	background:SetAllPoints()
	local edge = Hairline(sidebar)
	edge:SetPoint("TOPRIGHT")
	edge:SetPoint("BOTTOMRIGHT")
	edge:SetWidth(1)
	frame.sidebar = sidebar

	-- Pet card: a round portrait in an accent ring, name + level, then what the
	-- client knows.
	local portraitFrame = CreateFrame("Frame", nil, sidebar)
	portraitFrame:SetSize(42, 42)
	portraitFrame:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, -13)
	local ring = portraitFrame:CreateTexture(nil, "BACKGROUND")
	ring:SetTexture(DISC)
	ring:SetAllPoints()
	painters[#painters + 1] = { object = ring, kind = "vertex", token = "accent" }
	petPortrait = portraitFrame:CreateTexture(nil, "ARTWORK")
	petPortrait:SetPoint("TOPLEFT", 2, -2)
	petPortrait:SetPoint("BOTTOMRIGHT", -2, 2)
	-- Masks must come from CreateMaskTexture; without one the portrait stays square.
	if portraitFrame.CreateMaskTexture and petPortrait.AddMaskTexture then
		local mask = portraitFrame:CreateMaskTexture()
		mask:SetTexture(DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(petPortrait)
		pcall(petPortrait.AddMaskTexture, petPortrait, mask)
	end

	petName = PaintedText(sidebar, "name", "text")
	petName:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 66, -18)
	petName:SetWidth(150)
	petName:SetJustifyH("LEFT")
	petStats = PaintedText(sidebar, "small", "dim")
	petStats:SetPoint("TOPLEFT", petName, "BOTTOMLEFT", 0, -4)
	petStats:SetWidth(150)
	petStats:SetJustifyH("LEFT")
	petStats:SetWordWrap(true)

	local cardLine = Hairline(sidebar)
	cardLine:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -CARD_H)
	cardLine:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -1, -CARD_H)
	cardLine:SetHeight(1)

	-- Only when the hunter has no pet out: pick a family to browse.
	familyButton = PillButton(sidebar, SIDEBAR_W - 28, "", false)
	familyButton:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, -(CARD_H + 10))
	familyButton:SetScript("OnClick", function()
		if UI.ToggleFamilyMenu then UI.ToggleFamilyMenu() end
	end)

	emptyPetText = PaintedText(sidebar, "small", "muted")
	emptyPetText:SetPoint("TOPLEFT", familyButton, "BOTTOMLEFT", 0, -8)
	emptyPetText:SetWidth(SIDEBAR_W - 28)
	emptyPetText:SetJustifyH("LEFT")
	emptyPetText:SetWordWrap(true)
	emptyPetText:SetText(L["No pet out — bring out your pet to see what it can learn."])

	-- Rank groups; UI.LayoutSidebar stacks them from what each one shows.
	for _, definition in ipairs(GROUPS) do
		local group = { key = definition.key, rows = {} }
		group.header = PaintedText(sidebar, "label", "muted")
		group.header:SetText(L[definition.title])
		for index = 1, definition.max do
			local row = CreateFrame("Button", nil, sidebar)
			row:SetHeight(ROW_H)
			local hover = PaintedTexture(row, "HIGHLIGHT", "text", 0.05)
			hover:SetAllPoints()
			row.selected = row:CreateTexture(nil, "BACKGROUND")
			row.selected:SetAllPoints()
			row.selected:Hide()
			row.bar = row:CreateTexture(nil, "BACKGROUND", nil, 1)
			row.bar:SetPoint("TOPLEFT", 0, 0)
			row.bar:SetPoint("BOTTOMLEFT", 0, 0)
			row.bar:SetWidth(3)
			row.bar:Hide()
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetPoint("LEFT", 14, 0)
			row.icon:SetSize(15, 15)
			row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			row.suffix = row:CreateFontString(nil, "ARTWORK", Font("small"))
			row.suffix:SetPoint("RIGHT", -14, 0)
			row.suffix:SetJustifyH("RIGHT")
			-- The name takes all the room the suffix leaves.
			row.text = row:CreateFontString(nil, "ARTWORK", Font("body"))
			row.text:SetPoint("LEFT", 36, 0)
			row.text:SetPoint("RIGHT", row.suffix, "LEFT", -8, 0)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
			row:SetScript("OnClick", function(self)
				if self.entry and ns.SelectPlanEntry then ns.SelectPlanEntry(self.entry) end
			end)
			group.rows[index] = row
		end
		abilityGroups[#abilityGroups + 1] = group
	end
end

-- Stacks the rank groups under the pet card: a group without rows takes no room.
local function LayoutSidebar(browsing)
	local sidebar = frame.sidebar
	local y = -(CARD_H + 12)
	if browsing then y = -(CARD_H + 10 + BUTTON_H + 8 + 40) end
	for _, group in ipairs(abilityGroups) do
		local shown = 0
		for _, row in ipairs(group.rows) do
			if row.entry then shown = shown + 1 end
		end
		group.header:SetShown(shown > 0)
		if shown > 0 then
			group.header:ClearAllPoints()
			group.header:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, y - 5)
			y = y - GROUP_HEAD_H
			for _, row in ipairs(group.rows) do
				if row.entry then
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, y)
					row:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -1, y)
					y = y - ROW_H
				end
			end
			y = y - GROUP_GAP
		end
	end
end

local function BuildMain()
	local main = CreateFrame("Frame", nil, frame)
	main:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W, -1)
	main:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	frame.main = main

	-- Header band: sky fading into the window background.
	local header = CreateFrame("Frame", nil, main)
	header:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
	header:SetHeight(HEADER_H)
	headerGradient = header:CreateTexture(nil, "BACKGROUND")
	headerGradient:SetAllPoints()
	headerGradient:SetColorTexture(1, 1, 1, 1) -- white base, tinted by SetGradient in Paint
	frame.header = header

	titleName = PaintedText(header, "title", "text")
	titleName:SetPoint("TOPLEFT", header, "TOPLEFT", 16, -12)
	titleName:SetJustifyH("LEFT")
	titleRank = PaintedText(header, "title", "accent")
	titleRank:SetPoint("LEFT", titleName, "RIGHT", 7, 0)
	titleRank:SetJustifyH("LEFT")
	subtitle = PaintedText(header, "small", "dim")
	subtitle:SetPoint("TOPLEFT", titleName, "BOTTOMLEFT", 0, -6)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetWidth(480)
	subtitle:SetWordWrap(true)
	learnedBadge = PaintedText(header, "label", "ok")
	learnedBadge:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -3)
	learnedBadge:SetWidth(480)
	learnedBadge:SetJustifyH("LEFT")
	learnedBadge:Hide()

	-- Gear and close: flat glyphs in the theme's colours, brighter on hover.
	local function HeaderIcon(offsetX)
		local button = CreateFrame("Button", nil, header)
		button:SetSize(22, 22)
		button:SetPoint("TOPRIGHT", header, "TOPRIGHT", offsetX, -10)
		button.hover = Pill(button, "HIGHLIGHT")
		return button
	end
	gearButton = HeaderIcon(-38)
	gearButton.icon = gearButton:CreateTexture(nil, "ARTWORK")
	gearButton.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	gearButton.icon:SetPoint("CENTER")
	gearButton.icon:SetSize(14, 14)
	if gearButton.icon.SetDesaturated then gearButton.icon:SetDesaturated(true) end
	painters[#painters + 1] = { object = gearButton.icon, kind = "vertex", token = "dim" }
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

	closeButton = HeaderIcon(-12)
	closeButton.label = PaintedText(closeButton, "name", "dim")
	closeButton.label:SetPoint("CENTER", 0, 1)
	closeButton.label:SetText("×")
	closeButton:SetScript("OnClick", function() ns.Close() end)

	-- Tabs, right-aligned before the gear: the last one sits closest to it.
	local anchor, anchorPoint, offsetX = gearButton, "LEFT", -12
	for index = #VIEWS, 1, -1 do
		local definition = VIEWS[index]
		local tab = CreateFrame("Button", nil, header)
		tab.key = definition.key
		tab:SetHeight(24) -- before the pill, which takes its ends from the height
		tab.hover = Pill(tab, "HIGHLIGHT")
		tab.label = tab:CreateFontString(nil, "ARTWORK", Font("label"))
		tab.label:SetPoint("CENTER", 0, 1)
		tab.label:SetText(L[definition.label])
		tab:SetWidth(math.floor((tab.label:GetStringWidth() or 0) + 20))
		tab:SetPoint("RIGHT", anchor, anchorPoint, offsetX, 0)
		tab.underline = tab:CreateTexture(nil, "ARTWORK")
		tab.underline:SetPoint("BOTTOMLEFT", 6, -2)
		tab.underline:SetPoint("BOTTOMRIGHT", -6, -2)
		tab.underline:SetHeight(2)
		tab:SetScript("OnClick", function(self) UI.SelectView(self.key) end)
		table.insert(tabs, 1, tab)
		anchor, anchorPoint, offsetX = tab, "LEFT", -2
	end

	-- Filter chips: pills sized to their label.
	local chipRow = CreateFrame("Frame", nil, main)
	chipRow:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -HEADER_H)
	chipRow:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, -HEADER_H)
	chipRow:SetHeight(CHIPS_H)
	frame.chipRow = chipRow
	local showFaction = ns.Planner.HasZoneFactions()
	local x = 16
	for _, definition in ipairs(CHIPS) do
		-- Without any zone faction in the data the filter could not change anything.
		if definition.key ~= "faction" or showFaction then
			local chip = CreateFrame("Button", nil, chipRow)
			chip:SetHeight(CHIP_H)
			chip.key = definition.key
			chip.pill = Pill(chip, "BACKGROUND")
			chip.hover = Pill(chip, "HIGHLIGHT")
			chip.label = chip:CreateFontString(nil, "ARTWORK", Font("label"))
			chip.label:SetPoint("CENTER", 0, 0)
			chip.label:SetText(L[definition.label])
			local width = math.max(definition.width, math.floor((chip.label:GetStringWidth() or 0) + 26))
			chip:SetWidth(width)
			chip:SetPoint("LEFT", chipRow, "LEFT", x, 0)
			chip:SetScript("OnClick", function(self)
				if ns.ToggleFilter then ns.ToggleFilter(self.key) end
			end)
			chips[#chips + 1] = chip
			x = x + width + 6
		end
	end
	local chipLine = Hairline(main)
	chipLine:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -(HEADER_H + CHIPS_H))
	chipLine:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, -(HEADER_H + CHIPS_H))
	chipLine:SetHeight(1)

	-- Beast table: a header row on the panel colour, then the rows.
	local tableTop = HEADER_H + CHIPS_H + 1
	local tableHead = PaintedTexture(main, "BACKGROUND", "panel", nil, 1)
	tableHead:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -tableTop)
	tableHead:SetPoint("TOPRIGHT", main, "TOPLEFT", TABLE_W, -tableTop)
	tableHead:SetHeight(TABLE_HEAD_H)
	local headLine = Hairline(main)
	headLine:SetPoint("TOPLEFT", tableHead, "BOTTOMLEFT")
	headLine:SetPoint("TOPRIGHT", tableHead, "BOTTOMRIGHT")
	headLine:SetHeight(1)
	headName = PaintedText(main, "label", "muted")
	headName:SetPoint("LEFT", tableHead, "LEFT", 16, 0)
	headName:SetText(L["Beast"])
	headLevel = PaintedText(main, "label", "muted")
	headLevel:SetPoint("LEFT", tableHead, "LEFT", 182, 0)
	headLevel:SetWidth(40)
	headLevel:SetJustifyH("RIGHT")
	headLevel:SetText(L["Level"])
	headZone = PaintedText(main, "label", "muted")
	headZone:SetPoint("LEFT", tableHead, "LEFT", 234, 0)
	headZone:SetText(L["Zone"])

	scroll = CreateFrame("ScrollFrame", nil, main)
	scroll:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -(tableTop + TABLE_HEAD_H + 1))
	scroll:SetPoint("BOTTOMRIGHT", main, "BOTTOMLEFT", TABLE_W, 0)
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
		local hover = PaintedTexture(row, "HIGHLIGHT", "text", 0.05)
		hover:SetAllPoints()
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:Hide()
		local rule = Hairline(row, 0.45)
		rule:SetPoint("BOTTOMLEFT", 0, 0)
		rule:SetPoint("BOTTOMRIGHT", 0, 0)
		rule:SetHeight(1)
		row.name = row:CreateFontString(nil, "ARTWORK", Font("strong"))
		row.name:SetPoint("LEFT", 16, 0)
		row.name:SetWidth(164)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.level = row:CreateFontString(nil, "ARTWORK", Font("body"))
		row.level:SetPoint("LEFT", 182, 0)
		row.level:SetWidth(40)
		row.level:SetJustifyH("RIGHT")
		row.zone = row:CreateFontString(nil, "ARTWORK", Font("body"))
		row.zone:SetPoint("LEFT", 234, 0)
		row.zone:SetWidth(TABLE_W - 234 - 10)
		row.zone:SetJustifyH("LEFT")
		row.zone:SetWordWrap(false)
		row:SetScript("OnClick", function(self)
			if self.entry and ns.SelectBeast then ns.SelectBeast(self.entry.id) end
		end)
		row:SetScript("OnMouseWheel", OnWheel)
		beastRows[index] = row
	end

	tableEmpty = PaintedText(scrollChild, "small", "muted")
	tableEmpty:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -10)
	tableEmpty:SetWidth(TABLE_W - 32)
	tableEmpty:SetJustifyH("LEFT")
	tableEmpty:SetWordWrap(true)
	tableEmpty:Hide()

	-- Detail panel: selected beast, its map and the waypoint buttons.
	local detailPanel = PaintedTexture(main, "BACKGROUND", "panel", nil, 1)
	detailPanel:SetPoint("TOPLEFT", main, "TOPLEFT", TABLE_W, -tableTop)
	detailPanel:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
	local separator = Hairline(main)
	separator:SetPoint("TOPLEFT", detailPanel, "TOPLEFT")
	separator:SetPoint("BOTTOMLEFT", detailPanel, "BOTTOMLEFT")
	separator:SetWidth(1)

	local detail = CreateFrame("Frame", nil, main)
	detail:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 12, -12)
	detail:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -12, 12)
	frame.detail = detail

	detailMap = NewMiniMap(detail)
	detailMap.frame:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)

	detailName = PaintedText(detail, "name", "npc")
	detailName:SetPoint("TOPLEFT", detailMap.frame, "BOTTOMLEFT", 0, -12)
	detailName:SetWidth(MAP_W)
	detailName:SetJustifyH("LEFT")
	detailZone = PaintedText(detail, "small", "place")
	detailZone:SetPoint("TOPLEFT", detailName, "BOTTOMLEFT", 0, -4)
	detailZone:SetWidth(MAP_W)
	detailZone:SetJustifyH("LEFT")
	detailZone:SetWordWrap(true)
	detailHint = PaintedText(detail, "small", "muted")
	detailHint:SetPoint("TOPLEFT", detailZone, "BOTTOMLEFT", 0, -8)
	detailHint:SetWidth(MAP_W)
	detailHint:SetJustifyH("LEFT")
	detailHint:SetWordWrap(true)
	detailHint:SetText(L["Other beasts are sorted by level."])

	waypointButton = PillButton(detail, MAP_W, L["Arrow + pin"], true)
	waypointButton:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, BUTTON_H + 8)
	waypointButton:SetScript("OnClick", function() UI.PlaceWaypoint(ns.state and ns.state.beast) end)

	mapButton = PillButton(detail, MAP_W, L["Show on map"], false)
	mapButton:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
	mapButton:SetScript("OnClick", function() UI.OpenMap(ns.state and ns.state.beast) end)
end

-- The hidden pets page: a list over the sidebar, the chosen pet's steps and
-- map over the rest. Both cover what they hide, mouse included.
local function Cover(owner, token)
	local cover = CreateFrame("Frame", nil, owner)
	cover:SetFrameLevel((owner:GetFrameLevel() or 1) + 30)
	cover:EnableMouse(true)
	if cover.EnableMouseWheel then cover:EnableMouseWheel(true) end
	local background = PaintedTexture(cover, "BACKGROUND", token)
	background:SetAllPoints()
	cover:Hide()
	return cover
end

local function BuildSecrets()
	local list = ns.secrets or {}

	secretList = Cover(frame, "sidebar")
	secretList:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT")
	secretList:SetPoint("BOTTOMRIGHT", frame.sidebar, "BOTTOMRIGHT")
	local edge = Hairline(secretList)
	edge:SetPoint("TOPRIGHT")
	edge:SetPoint("BOTTOMRIGHT")
	edge:SetWidth(1)
	local listHead = PaintedText(secretList, "label", "muted")
	listHead:SetPoint("TOPLEFT", secretList, "TOPLEFT", 14, -16)
	listHead:SetText(L["Found on Forever"])
	secretRows = {}
	for index, secret in ipairs(list) do
		local row = CreateFrame("Button", nil, secretList)
		row:SetHeight(44)
		row:SetPoint("TOPLEFT", secretList, "TOPLEFT", 0, -(36 + (index - 1) * 46))
		row:SetPoint("TOPRIGHT", secretList, "TOPRIGHT", -1, -(36 + (index - 1) * 46))
		row.secret = secret
		local hover = PaintedTexture(row, "HIGHLIGHT", "text", 0.05)
		hover:SetAllPoints()
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.bar = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.bar:SetPoint("TOPLEFT")
		row.bar:SetPoint("BOTTOMLEFT")
		row.bar:SetWidth(3)
		row.name = PaintedText(row, "name", "npc")
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -7)
		row.info = PaintedText(row, "small", "muted")
		row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.info:SetWidth(SIDEBAR_W - 28)
		row.info:SetJustifyH("LEFT")
		row:SetScript("OnClick", function(self)
			secretSelected = self.secret
			UI.RenderSecrets()
		end)
		secretRows[index] = row
	end
	secretSelected = list[1]

	secretBody = Cover(frame.main, "bg")
	secretBody:SetPoint("TOPLEFT", frame.main, "TOPLEFT", 0, -HEADER_H)
	secretBody:SetPoint("BOTTOMRIGHT", frame.main, "BOTTOMRIGHT")
	local headLine = Hairline(secretBody)
	headLine:SetPoint("TOPLEFT")
	headLine:SetPoint("TOPRIGHT")
	headLine:SetHeight(1)
	local columnW = W - SIDEBAR_W - 1 - SECRET_PANEL_W - 32

	secretName = PaintedText(secretBody, "name", "npc")
	secretName:SetPoint("TOPLEFT", secretBody, "TOPLEFT", 16, -14)
	secretName:SetWidth(columnW)
	secretName:SetJustifyH("LEFT")
	secretTitle = PaintedText(secretBody, "small", "muted")
	secretTitle:SetPoint("TOPLEFT", secretName, "BOTTOMLEFT", 0, -3)
	secretTitle:SetWidth(columnW)
	secretTitle:SetJustifyH("LEFT")
	secretZone = PaintedText(secretBody, "small", "place")
	secretZone:SetPoint("TOPLEFT", secretTitle, "BOTTOMLEFT", 0, -3)
	secretZone:SetWidth(columnW)
	secretZone:SetJustifyH("LEFT")

	-- Requirement pills: the hunter's level, the item in the bags.
	local previous
	for index = 1, 2 do
		local pill = CreateFrame("Frame", nil, secretBody)
		pill:SetHeight(CHIP_H)
		pill.pill = Pill(pill, "BACKGROUND")
		pill.label = pill:CreateFontString(nil, "ARTWORK", Font("label"))
		pill.label:SetPoint("CENTER")
		if previous then
			pill:SetPoint("LEFT", previous, "RIGHT", 6, 0)
		else
			pill:SetPoint("TOPLEFT", secretZone, "BOTTOMLEFT", 0, -10)
		end
		secretPills[index] = pill
		previous = pill
	end

	-- Numbered steps, each under the one before so wrapped lines push the next.
	secretSteps = {}
	local above = secretPills[1]
	for index = 1, SECRET_STEPS_MAX do
		local step = {}
		step.text = PaintedText(secretBody, "body", "dim")
		step.text:SetPoint("TOPLEFT", above, "BOTTOMLEFT", index == 1 and 28 or 0, index == 1 and -14 or -10)
		step.text:SetWidth(columnW - 28)
		step.text:SetJustifyH("LEFT")
		step.text:SetWordWrap(true)
		step.disc = secretBody:CreateTexture(nil, "BORDER")
		step.disc:SetTexture(DISC)
		painters[#painters + 1] = { object = step.disc, kind = "vertex", token = "alt" }
		step.disc:SetSize(20, 20)
		step.disc:SetPoint("TOPRIGHT", step.text, "TOPLEFT", -8, 3)
		step.number = PaintedText(secretBody, "label", "text")
		step.number:SetPoint("CENTER", step.disc, "CENTER", 0, 0)
		step.number:SetText(tostring(index))
		secretSteps[index] = step
		above = step.text
	end

	-- Right panel: the map, what the pet knows, the source, the two buttons.
	local panel = PaintedTexture(secretBody, "BACKGROUND", "panel", nil, 1)
	panel:SetPoint("TOPLEFT", secretBody, "TOPRIGHT", -SECRET_PANEL_W, -1)
	panel:SetPoint("BOTTOMRIGHT")
	local separator = Hairline(secretBody)
	separator:SetPoint("TOPLEFT", panel, "TOPLEFT")
	separator:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
	separator:SetWidth(1)
	secretMap = NewMiniMap(secretBody)
	secretMap.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
	local knows = PaintedText(secretBody, "label", "muted")
	knows:SetPoint("TOPLEFT", secretMap.frame, "BOTTOMLEFT", 0, -12)
	knows:SetText(L["It knows"])
	secretAbilities = PaintedText(secretBody, "body", "spell")
	secretAbilities:SetPoint("TOPLEFT", knows, "BOTTOMLEFT", 0, -5)
	secretAbilities:SetWidth(MAP_W)
	secretAbilities:SetJustifyH("LEFT")
	secretAbilities:SetSpacing(3)
	secretSource = PaintedText(secretBody, "small", "muted")
	secretSource:SetPoint("TOPLEFT", secretAbilities, "BOTTOMLEFT", 0, -10)
	secretSource:SetWidth(MAP_W)
	secretSource:SetJustifyH("LEFT")
	secretSource:SetWordWrap(true)

	local waypoint = PillButton(secretBody, MAP_W, L["Arrow + pin"], true)
	waypoint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12 + BUTTON_H + 8)
	waypoint:SetScript("OnClick", function() UI.PlaceWaypoint(UI.SecretTarget(secretSelected)) end)
	local show = PillButton(secretBody, MAP_W, L["Show on map"], false)
	show:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
	show:SetScript("OnClick", function() UI.OpenMap(UI.SecretTarget(secretSelected)) end)
	secretButtons = { waypoint, show }
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

	-- Explicit sublevels: on the same sublevel the game may draw the translucent
	-- border over the background, which tinted the whole window.
	local border = PaintedTexture(frame, "BACKGROUND", "line", nil, -8)
	border:SetAllPoints()
	local background = PaintedTexture(frame, "BACKGROUND", "bg", nil, -7)
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)
	frame.background = background
	frame.border = border

	BuildSidebar()
	BuildMain()
	BuildSecrets()

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
	for _, painter in ipairs(painters) do
		if painter.kind == "text" then
			SetTextColor(painter.object, painter.token)
		elseif painter.kind == "vertex" then
			-- A shaped texture (disc, icon): tint it, keep its shape.
			local r, g, b = ns.Token(painter.token)
			painter.object:SetVertexColor(r, g, b, painter.alpha or 1)
		else
			SetTextureColor(painter.object, painter.token, painter.alpha)
		end
	end
	-- The current theme stands out in the theme menu.
	for _, row in ipairs(themeRowList or {}) do
		SetTextColor(row.text, row.key == ns.theme and "accent" or "dim")
	end
	-- The menus can be open without the window (minimap button).
	if not frame then return end

	-- SetGradientAlpha is gone from this client. VERTICAL takes the bottom colour first,
	-- so the sky sits at the top and fades into the background below.
	local skyR, skyG, skyB = ns.Token("sky")
	local bgR, bgG, bgB = ns.Token("bg")
	headerGradient:SetGradient("VERTICAL", CreateColor(bgR, bgG, bgB, 1), CreateColor(skyR, skyG, skyB, 1))

	-- Filter chips: pressed ones are filled with the accent colour.
	for _, chip in ipairs(chips) do
		local pressed = ns.state and ns.state.filters and ns.state.filters[chip.key]
		SetPillColor(chip.pill, pressed and "accent" or "alt")
		SetPillColor(chip.hover, "text", 0.08)
		SetTextColor(chip.label, pressed and "onAccent" or "dim")
	end
	for _, button in ipairs({ waypointButton, mapButton, familyButton }) do
		PaintPillButton(button)
	end
	SetPillColor(gearButton.hover, "text", 0.08)
	SetPillColor(closeButton.hover, "text", 0.08)

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

	-- Header tabs: the open one in full text over an accent underline.
	for _, tab in ipairs(tabs) do
		local open = tab.key == view
		SetTextColor(tab.label, open and "text" or "dim")
		tab.underline:SetShown(open)
		SetTextureColor(tab.underline, "accent")
		SetPillColor(tab.hover, "text", 0.06)
	end

	-- Hidden pets: the chosen one carries the accent bar; requirement pills
	-- are green when met, red when not.
	for _, row in ipairs(secretRows or {}) do
		local selected = row.secret == secretSelected
		row.selected:SetShown(selected)
		row.bar:SetShown(selected)
		SetTextureColor(row.selected, "accent", 0.10)
		SetTextureColor(row.bar, "accent")
	end
	for _, pill in ipairs(secretPills) do
		SetPillColor(pill.pill, "alt")
		SetTextColor(pill.label, pill.met and "ok" or "danger")
	end
	for _, button in ipairs(secretButtons) do PaintPillButton(button) end
end

-----------------------------------------------------------------------------
-- Beast card of the right panel
-----------------------------------------------------------------------------

-- The zone map is a grid of tiles (row by row, usually 256 px) covering a
-- layer of layerWidth x layerHeight (1002 x 668). Each tile is scaled into the
-- mini map; the last column and row are cropped to the layer's edge.
-- Draws the tiles of `layer` into `mini`; false when there is nothing to draw.
local function DrawMapArt(mini, layer, textures)
	local layerW, layerH = tonumber(layer.layerWidth), tonumber(layer.layerHeight)
	local tileW, tileH = tonumber(layer.tileWidth), tonumber(layer.tileHeight)
	if not (layerW and layerH and tileW and tileH) or layerW <= 0 or layerH <= 0 or tileW <= 0 or tileH <= 0 then
		return false
	end
	local columns = math.ceil(layerW / tileW)
	local scaleX, scaleY = MAP_W / layerW, MAP_H / layerH
	for index, fileID in ipairs(textures) do
		local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
		local shownW = math.min(tileW, layerW - column * tileW)
		local shownH = math.min(tileH, layerH - row * tileH)
		if shownW > 0 and shownH > 0 then
			local tile = mini.tiles[index]
			if not tile then
				tile = mini.frame:CreateTexture(nil, "BORDER")
				mini.tiles[index] = tile
			end
			tile:SetTexture(fileID)
			tile:SetTexCoord(0, shownW / tileW, 0, shownH / tileH)
			tile:SetSize(shownW * scaleX, shownH * scaleY)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", mini.frame, "TOPLEFT", column * tileW * scaleX, -row * tileH * scaleY)
			tile:Show()
		end
	end
	return true
end

-- entry = { map, x, y (0-100), zoneName } or nil.
local function ShowMiniMap(mini, entry)
	for _, tile in ipairs(mini.tiles) do tile:Hide() end
	for _, part in ipairs(mini.pin) do part:Hide() end
	mini.hint:Show()
	if not entry then
		mini.hint:SetText(L["No map for this beast."])
		return
	end
	mini.hint:SetText(entry.zoneName or "")
	if not (entry.map and entry.x and entry.y) then return end
	if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return end
	local okLayers, layers = pcall(C_Map.GetMapArtLayers, entry.map)
	if not okLayers or type(layers) ~= "table" or not layers[1] then return end
	local okTiles, tiles = pcall(C_Map.GetMapArtLayerTextures, entry.map, 1)
	if not okTiles or type(tiles) ~= "table" or not tiles[1] then return end
	if not DrawMapArt(mini, layers[1], tiles) then return end
	mini.hint:Hide()
	local px = math.floor((entry.x / 100) * MAP_W + 0.5)
	local py = math.floor((entry.y / 100) * MAP_H + 0.5)
	for _, part in ipairs(mini.pin) do
		part:ClearAllPoints()
		part:SetPoint("CENTER", mini.frame, "TOPLEFT", px, -py)
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
		local text = L["%d → %d"]:format(entry.known, entry.rank)
		-- The game font has no "→": without Inter, use a glyph it draws.
		if not ns.fontReady then text = text:gsub("→", "»") end
		return text
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
		familyButton.label:SetText(L["Family"] .. " : " .. ns.Pet.DisplayName(state.familyId))
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
	LayoutSidebar(state.browsing)

	-- Title: the chosen rank.
	local ability = state.selection and state.selection.ability
	local rankRecord = state.rank
	if ability and rankRecord then
		titleName:SetText(AbilityName(ability))
		titleRank:SetText(L["rank %s"]:format(rankRecord.rank or (state.selection and state.selection.rank) or "?"))
		subtitle:SetText(RankSubtitle(rankRecord))
	else
		titleName:SetText(L["Hunter's Atlas"])
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
		detailHint:SetText(beast.seenPosition and L["Position you saw"]
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
	ShowMiniMap(detailMap, beast)

	UI.RenderSecrets()
	UI.Paint()
end

-----------------------------------------------------------------------------
-- Hidden pets page
-----------------------------------------------------------------------------

-- The record's text in the client's language; English clients get no line
-- when only French is known.
local function Pick(record)
	if type(record) ~= "table" then return nil end
	if ns.french then return record.fr or record.en end
	return record.en
end

local function Readable(value)
	if value == nil or (issecretvalue and issecretvalue(value)) then return nil end
	return value
end

local function ItemName(item)
	if C_Item and C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, item.id)
		name = ok and Readable(name)
		if type(name) == "string" and name ~= "" then return name end
	end
	return Pick(item) or ("item " .. tostring(item.id))
end

local function ItemCount(itemID)
	local reader = (C_Item and C_Item.GetItemCount) or GetItemCount
	if type(reader) ~= "function" then return nil end
	local ok, count = pcall(reader, itemID)
	count = ok and Readable(count)
	return type(count) == "number" and count or nil
end

local function SecretAbilityName(ability)
	local name = C_Spell and C_Spell.GetSpellName and Readable(C_Spell.GetSpellName(ability.spell))
	if type(name) ~= "string" or name == "" then name = Pick(ability) or "?" end
	if ability.rank then name = L["%s %s"]:format(name, tostring(ability.rank)) end
	return name
end

-- The point the map buttons take: { map, x, y, name, zoneName }.
function UI.SecretTarget(secret)
	if not (secret and secret.spot) then return nil end
	return {
		map = secret.spot.map, x = secret.spot.x, y = secret.spot.y,
		name = Pick(secret.name) or "?",
		zoneName = ns.Planner.ZoneName(secret.spot.map, secret.zoneEn),
	}
end

function UI.SelectView(key)
	if key == view then return end
	view = key
	UI.CloseThemeMenu()
	UI.Render()
end

function UI.RenderSecrets()
	if not secretBody then return end
	local open = view == "secrets"
	secretList:SetShown(open)
	secretBody:SetShown(open)
	if not open then return end

	titleName:SetText(L["Hidden pets"])
	titleRank:SetText("")
	subtitle:SetText(L["Beasts that only appear after a hidden step."])
	learnedBadge:Hide()

	for _, row in ipairs(secretRows) do
		local secret = row.secret
		row.name:SetText(Pick(secret.name) or "?")
		row.info:SetText(table.concat({
			ns.Pet.DisplayName(secret.family),
			L["level %d"]:format(secret.level),
			ns.Planner.ZoneName(secret.spot and secret.spot.map, secret.zoneEn) or "",
		}, " · "))
	end

	local secret = secretSelected
	local target = UI.SecretTarget(secret)
	secretName:SetText(secret and Pick(secret.name) or L["No hidden pet known yet."])
	local title = secret and Pick(secret.title)
	secretTitle:SetText(title and ("<" .. title .. ">") or "")
	secretTitle:SetShown(title ~= nil)
	secretZone:SetText(target and (target.zoneName .. " · " .. ns.Coord(target.x) .. " " .. ns.Coord(target.y)) or "")

	local level = ns.PlayerLevel and ns.PlayerLevel() or nil
	local item = secret and secret.item
	local count = item and ItemCount(item.id)
	local itemName = item and ItemName(item)
	local pills = {
		secret and { text = L["Level %d / %d"]:format(level or 0, secret.level), met = (level or 0) >= secret.level },
		item and {
			text = ("%s %s / %d"):format(itemName, count and tostring(count) or "?", item.count),
			met = (count or 0) >= item.count,
		},
	}
	for index, pill in ipairs(secretPills) do
		local want = pills[index]
		pill:SetShown(want ~= nil)
		if want then
			pill.label:SetText(want.text)
			pill:SetWidth(math.floor((pill.label:GetStringWidth() or 0) + 22))
			pill.met = want.met
		end
	end

	local steps = secret and secret.steps or {}
	for index, step in ipairs(secretSteps) do
		local text = Pick(steps[index])
		if text and itemName then text = text:gsub("%%ITEM%%", itemName) end
		step.text:SetText(text or "")
		for _, part in ipairs({ step.text, step.disc, step.number }) do part:SetShown(text ~= nil) end
	end

	local names = {}
	for _, ability in ipairs(secret and secret.abilities or {}) do names[#names + 1] = SecretAbilityName(ability) end
	secretAbilities:SetText(table.concat(names, "\n"))
	secretSource:SetText(secret and secret.source and L["Source: %s"]:format(secret.source) or "")
	for _, button in ipairs(secretButtons) do button:SetShown(target ~= nil) end
	ShowMiniMap(secretMap, target)
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

-----------------------------------------------------------------------------
-- Show on map: the world map opens on the beast's zone with the Atlas's own
-- point on it. Forever's user waypoint is not reliable on the map, so the
-- point is a frame on the map canvas, as ForeverDungeonJournal does. It is
-- placed again while the map is open and shows on the beast's zone only.
-----------------------------------------------------------------------------

local WORLD_PIN = 36
local mapTarget -- { map, x, y (0-1), name, place } of the last beast shown
local worldPin  -- { driver, pin } once built

local function MapCanvas()
	if not WorldMapFrame then return nil end
	if type(WorldMapFrame.GetCanvas) == "function" then
		local ok, canvas = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
		if ok and canvas then return canvas end
	end
	local scroll = WorldMapFrame.ScrollContainer
	return scroll and (scroll.Child or scroll) or nil
end

local function ShownMapID()
	if not (WorldMapFrame and type(WorldMapFrame.GetMapID) == "function") then return nil end
	local ok, mapID = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
	return ok and mapID or nil
end

-- The point is created on the map canvas itself, as ForeverDungeonJournal's
-- pins are: a frame made elsewhere and moved there keeps a strata below the
-- map and is never seen. Its size is in canvas units, so it zooms with the map.
local function CreateWorldPin(canvas)
	local pin = CreateFrame("Button", nil, canvas)
	pin:SetSize(WORLD_PIN, WORLD_PIN)
	pin:SetFrameLevel(10000)
	pin:EnableMouse(true)
	pin:RegisterForClicks("RightButtonUp")
	for _, part in ipairs({ { 34, "bg", 0.6 }, { 24, "accent" }, { 15, "bg" }, { 8, "accent" } }) do
		local disc = pin:CreateTexture(nil, "OVERLAY")
		disc:SetTexture(DISC)
		disc:SetSize(part[1], part[1])
		disc:SetPoint("CENTER")
		painters[#painters + 1] = { object = disc, kind = "vertex", token = part[2], alpha = part[3] }
	end
	pin:SetScript("OnEnter", function(self)
		if not (GameTooltip and mapTarget) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(mapTarget.name or "")
		if mapTarget.place then GameTooltip:AddLine(mapTarget.place, 1, 1, 1) end
		GameTooltip:AddLine(L["Right-click: remove the point"], 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	pin:SetScript("OnClick", function(self)
		mapTarget = nil
		self:Hide()
		if GameTooltip then GameTooltip:Hide() end
	end)
	UI.Paint()
	return pin
end

function UI.UpdateWorldPin()
	if not worldPin then return end
	local canvas = MapCanvas()
	local pin = worldPin.pin
	if not (mapTarget and mapTarget.x and canvas and ShownMapID() == mapTarget.map) then
		if pin then pin:Hide() end
		return
	end
	if not pin or pin:GetParent() ~= canvas then
		if pin then pin:Hide() end
		pin = CreateWorldPin(canvas)
		worldPin.pin = pin
	end
	-- The map's own pin placement when the client has it, else canvas size x spot.
	local placed = false
	if type(WorldMapFrame.SetPinPosition) == "function" then
		placed = pcall(WorldMapFrame.SetPinPosition, WorldMapFrame, pin, mapTarget.x, mapTarget.y)
	end
	if not placed then
		local width, height = canvas:GetWidth() or 0, canvas:GetHeight() or 0
		if width <= 1 or height <= 1 then
			pin:Hide()
			return
		end
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", canvas, "TOPLEFT", width * mapTarget.x, -height * mapTarget.y)
	end
	pin:Show()
end

local function BuildWorldPin()
	-- Parented to the world map, so it only runs while the map is open: the
	-- player may zoom, pan or change zone.
	local driver = CreateFrame("Frame", nil, WorldMapFrame)
	-- Asked for in combat: the map turns to the beast's zone when the player opens it.
	driver:SetScript("OnShow", function()
		if mapTarget and mapTarget.pending and type(WorldMapFrame.SetMapID) == "function" then
			mapTarget.pending = nil
			pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapTarget.map)
		end
	end)
	local wait = 0
	driver:SetScript("OnUpdate", function(_, elapsed)
		wait = wait - (elapsed or 0)
		if wait > 0 then return end
		wait = 0.05
		UI.UpdateWorldPin()
	end)
	worldPin = { driver = driver }
end

function UI.OpenMap(entry)
	if not entry or not entry.map then return end
	local place = entry.zoneName
	if entry.x and entry.y then
		place = (place and place ~= "" and (place .. " · ") or "") .. ns.Coord(entry.x) .. " " .. ns.Coord(entry.y)
	end
	mapTarget = {
		map = entry.map, name = entry.name, place = place,
		x = entry.x and entry.x / 100, y = entry.y and entry.y / 100,
	}

	-- Opening the map is blocked in combat; the point then waits for the player
	-- to open it (M).
	local inCombat = type(InCombatLockdown) == "function" and InCombatLockdown()
	if not inCombat then
		if C_Map and type(C_Map.OpenWorldMap) == "function" then
			pcall(C_Map.OpenWorldMap, entry.map)
		elseif type(OpenWorldMap) == "function" then
			pcall(OpenWorldMap, entry.map)
		end
		if WorldMapFrame and not WorldMapFrame:IsShown() and type(ShowUIPanel) == "function" then
			pcall(ShowUIPanel, WorldMapFrame)
		end
	end
	if not WorldMapFrame then return end
	if WorldMapFrame:IsShown() and type(WorldMapFrame.SetMapID) == "function" then
		pcall(WorldMapFrame.SetMapID, WorldMapFrame, entry.map)
	end
	if not worldPin then BuildWorldPin() end
	UI.UpdateWorldPin()
	if not mapTarget.x then return end
	if WorldMapFrame:IsShown() then
		ns.Print(L["%s shown on the map."]:format(entry.name or ""))
	else
		mapTarget.pending = true
		ns.Print(L["Open the map (M) to see %s: the map cannot open during combat."]:format(entry.name or ""))
	end
end

-----------------------------------------------------------------------------
-- Theme menu (gear button, right-click on the minimap button, /atlas theme)
-----------------------------------------------------------------------------

local function BuildThemeMenu()
	themeMenu = CreateFrame("Frame", "AtlasDeChasseThemeMenu", UIParent)
	themeMenu:SetFrameStrata("FULLSCREEN_DIALOG")
	themeMenu:SetSize(180, 18 + #ns.themeList * 20 + 8)
	local border = PaintedTexture(themeMenu, "BACKGROUND", "line", nil, -8)
	border:SetAllPoints()
	local background = PaintedTexture(themeMenu, "BACKGROUND", "panel", nil, -7)
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)

	local title = PaintedText(themeMenu, "label", "muted")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText(L["Themes"])
	themeRowList = {}
	for index, theme in ipairs(ns.themeList) do
		local row = CreateFrame("Button", nil, themeMenu)
		row:SetPoint("TOPLEFT", 4, -(8 + index * 20))
		row:SetPoint("TOPRIGHT", -4, -(8 + index * 20))
		row:SetHeight(18)
		row.key = theme.key
		local hover = PaintedTexture(row, "HIGHLIGHT", "alt")
		hover:SetAllPoints()
		row.text = row:CreateFontString(nil, "ARTWORK", Font("body"))
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
	local border = PaintedTexture(familyMenu, "BACKGROUND", "line", nil, -8)
	border:SetAllPoints()
	familyMenu.border = border
	local background = PaintedTexture(familyMenu, "BACKGROUND", "panel", nil, -7)
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)
	familyMenu.background = background
	familyMenuRows = {}
	local order = ns.FamilyOrder()
	local columns = #order > 14 and 2 or 1
	local rows = math.ceil(#order / columns)
	familyMenu:SetSize(columns * 110 + 8, rows * 18 + 8)
	for index, familyId in ipairs(order) do
		local column = math.floor((index - 1) / rows)
		local line = (index - 1) % rows
		local row = CreateFrame("Button", nil, familyMenu)
		row:SetPoint("TOPLEFT", 4 + column * 110, -(4 + line * 18))
		row:SetSize(106, 18)
		row.familyId = familyId
		local hover = PaintedTexture(row, "HIGHLIGHT", "alt")
		hover:SetAllPoints()
		row.text = PaintedText(row, "body", "dim")
		row.text:SetPoint("LEFT", 6, 0)
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
	UI.Paint()
end
