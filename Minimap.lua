-- Atlas de chasse · minimap button: drag it around the minimap, left-click
-- opens the window, right-click opens the theme menu. /atlas minimap hides it.
local _, ns = ...
local L = ns.L

local BUTTON_NAME = "AtlasDeChasseMinimapButton"
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local button

local function UpdatePosition()
	if not button or not Minimap then return end
	local db = ns.db
	local angle = math.rad((db and db.minimap and db.minimap.angle) or 200)
	local radius = (Minimap:GetWidth() / 2) + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
	if not Minimap or not button then return end
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	if not (mx and my and scale and scale > 0 and cx and cy) then return end
	cx, cy = cx / scale, cy / scale
	if ns.db and ns.db.minimap then
		ns.db.minimap.angle = math.deg(atan2(cy - my, cx - mx))
	end
	UpdatePosition()
end

local function Tooltip(owner)
	if not GameTooltip then return end
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:AddLine(L["Hunter's Atlas"])
	GameTooltip:AddLine(L["Click: open or close Hunter's Atlas"], 1, 1, 1)
	GameTooltip:AddLine(L["Right-click: themes"], 1, 1, 1)
	GameTooltip:AddLine(L["Drag: move around the minimap"], 1, 1, 1)
	GameTooltip:AddLine(L["/atlas minimap: show or hide the minimap button"], 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function Create()
	button = CreateFrame("Button", BUTTON_NAME, Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(20, 20)
	background:SetPoint("CENTER")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
	icon:SetSize(18, 18)
	icon:SetPoint("CENTER")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			if ns.ui and ns.ui.ToggleThemeMenu then ns.ui.ToggleThemeMenu(button) end
		else
			ns.Toggle()
		end
	end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self) Tooltip(self) end)
	button:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
end

function ns.UpdateMinimapButton()
	if not Minimap then return end
	if not button then Create() end
	if not button then return end
	UpdatePosition()
	local hidden = ns.db and ns.db.minimap and ns.db.minimap.hide
	button:SetShown(not hidden)
end

function ns.SetupMinimap()
	if not ns.isHunter then return end
	local ok, err = pcall(ns.UpdateMinimapButton)
	if not ok then ns.Print(L["error: %s"]:format(tostring(err))) end
end
