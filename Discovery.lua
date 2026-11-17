-- Atlas de chasse · what the hunter sees in the world teaches the atlas.
--
-- The generated data has no French name for some teachers and no coordinate at
-- all for others. Both are learned while playing: a beast the hunter targets or
-- points at, close enough that the hunter's own position stands for its own,
-- leaves its localized name and the place it was seen.
--
-- Account-wide: AtlasDeChasseDB.seen[npcId] =
--   { name = "<localized>", locale = "frFR", spots = { { map, x, y, t } } }
--
-- Nothing here reads a secret value: every client read is guarded and skipped
-- silently, so a target in combat or in an instance simply teaches nothing.
local _, ns = ...

local Discovery = {}
ns.Discovery = Discovery

local Guard = ns.Pet.Guard

local MERGE_DISTANCE = 3   -- map units: a zone is 100 wide
local MAX_SPOTS = 5

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value) and true or false
end

local function ClientLocale()
	if type(GetLocale) ~= "function" then return nil end
	local ok, locale = pcall(GetLocale)
	if ok and type(locale) == "string" and locale ~= "" then return locale end
	return nil
end

local function Now()
	if type(time) ~= "function" then return nil end
	local ok, value = pcall(time)
	if ok and type(value) == "number" then return value end
	return nil
end

local function Distance(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return math.sqrt(dx * dx + dy * dy)
end

-----------------------------------------------------------------------------
-- The saved sightings
-----------------------------------------------------------------------------

-- The account-wide store, created on first use (EnsureDB also makes it).
function Discovery.Store()
	local db = ns.db
	if type(db) ~= "table" then return nil end
	if type(db.seen) ~= "table" then db.seen = {} end
	return db.seen
end

function Discovery.Seen(npcId)
	local store = Discovery.Store()
	local record = store and store[npcId]
	if type(record) == "table" then return record end
	return nil
end

local function SpotCount(spots)
	if type(spots) ~= "table" then return 0 end
	return #spots
end

-- One sighting in the store: the name replaces the remembered one, a spot within
-- MERGE_DISTANCE of a remembered one on the same map refreshes it instead of
-- adding another, and past MAX_SPOTS the oldest goes. Returns what was new.
local function Remember(store, npcId, sighting)
	local record = store[npcId]
	if type(record) ~= "table" then
		record = { spots = {} }
		store[npcId] = record
	end
	if type(record.spots) ~= "table" then record.spots = {} end

	local learnedName = false
	if sighting.name and sighting.name ~= record.name then
		record.name, learnedName = sighting.name, true
	end
	if sighting.locale then record.locale = sighting.locale end

	local learnedSpot = false
	if sighting.map and sighting.x and sighting.y then
		local spots = record.spots
		local near
		for _, spot in ipairs(spots) do
			if spot.map == sighting.map
				and Distance(spot.x, spot.y, sighting.x, sighting.y) <= MERGE_DISTANCE then
				near = spot
				break
			end
		end
		if near then
			near.x, near.y, near.t = sighting.x, sighting.y, sighting.t
		else
			spots[#spots + 1] = { map = sighting.map, x = sighting.x, y = sighting.y, t = sighting.t }
			learnedSpot = true
			if #spots > MAX_SPOTS then
				local oldest = 1
				for index = 2, #spots do
					if (spots[index].t or 0) < (spots[oldest].t or 0) then oldest = index end
				end
				table.remove(spots, oldest)
			end
		end
	end
	return learnedName, learnedSpot
end

-----------------------------------------------------------------------------
-- Reading the world
-----------------------------------------------------------------------------

-- The npc id of a creature unit, or nil for anything else. The id sits right
-- before the spawn id in "Creature-0-<server>-<instance>-<zone>-<npc>-<spawn>".
function Discovery.NpcId(unit)
	if type(UnitGUID) ~= "function" then return nil end
	local guid = Guard(UnitGUID, unit)
	if type(guid) ~= "string" or not guid:match("^Creature%-") then return nil end
	local fields = {}
	for field in guid:gmatch("[^-]+") do fields[#fields + 1] = field end
	if #fields < 3 then return nil end
	return tonumber(fields[#fields - 1])
end

-- Whether the unit is close enough for the hunter's position to mean something:
-- interact distance first, plain visibility when the client has no such read.
function Discovery.Close(unit)
	if type(CheckInteractDistance) == "function" then
		local ok, value = pcall(CheckInteractDistance, unit, 4)
		if ok and type(value) == "boolean" and not Secret(value) then return value end
	end
	if type(UnitIsVisible) == "function" then
		local ok, value = pcall(UnitIsVisible, unit)
		if ok and type(value) == "boolean" and not Secret(value) then return value end
	end
	return false
end

-- Where the hunter stands, in the 0-100 coordinates the data uses. nil when the
-- client keeps the position to itself, as it does in instances.
function Discovery.Position()
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
	local map = Guard(C_Map.GetBestMapForUnit, "player")
	if type(map) ~= "number" then return nil end
	local vector = Guard(C_Map.GetPlayerMapPosition, map, "player")
	if vector == nil then return nil end
	local ok, x, y = pcall(function() return vector:GetXY() end)
	if not ok or Secret(x) or Secret(y) then return nil end
	if type(x) ~= "number" or type(y) ~= "number" then return nil end
	-- GetXY answers 0, 0 where the client has no position at all
	if x == 0 and y == 0 then return nil end
	return map, x * 100, y * 100
end

-----------------------------------------------------------------------------
-- One unit, and the merge the window reads
-----------------------------------------------------------------------------

-- Watches one unit ("target", "mouseover") and stores what it teaches. Returns
-- what was new, nil when the unit is not a beast of the data, is too far for its
-- position to mean anything, or teaches nothing new.
function Discovery.Watch(unit)
	local store = Discovery.Store()
	local beasts = ns.beasts
	if not store or type(beasts) ~= "table" then return nil end
	local npcId = Discovery.NpcId(unit)
	local beast = npcId and beasts[npcId]
	if not beast then return nil end
	-- The hunter's position stands for the beast's, so a distant or hidden unit
	-- would place it where the hunter stands: only a close one is recorded.
	if not Discovery.Close(unit) then return nil end

	local name = Guard(UnitName, unit)
	if type(name) ~= "string" or name == "" then name = nil end
	local map, x, y = Discovery.Position()
	if not name and not map then return nil end

	local before = SpotCount((Discovery.Seen(npcId) or {}).spots)
	local learnedName, learnedSpot = Remember(store, npcId, {
		name = name,
		locale = name and ClientLocale() or nil,
		map = map, x = x, y = y, t = Now(),
	})
	if not learnedName and not learnedSpot then return nil end

	return {
		id = npcId,
		name = name,
		learnedName = learnedName,
		-- the first position this beast will ever show
		firstSpot = learnedSpot and before == 0 and SpotCount(beast.spots) == 0,
	}
end

-- The name and the spots the window shows for one beast, merged in one place:
-- the data's French name on a French client, then the name the hunter learned
-- for this locale, then the data's English name; the data's spots, and the seen
-- ones only when the data has none, flagged so the window can say where they
-- come from. Returns name, spots, fromSights.
function Discovery.Merge(npcId, beast)
	local record = Discovery.Seen(npcId)
	local fr = type(beast.fr) == "string" and beast.fr ~= "" and beast.fr or nil
	local locale = ClientLocale()
	local name
	if locale == "frFR" and fr then
		name = fr
	elseif record and type(record.name) == "string" and record.name ~= ""
		and (record.locale == nil or record.locale == locale) then
		name = record.name
	else
		name = fr or beast.en or ""
	end

	local spots = beast.spots
	if SpotCount(spots) > 0 then return name, spots, false end
	local remembered = record and record.spots
	if SpotCount(remembered) > 0 then return name, remembered, true end
	return name, {}, false
end
