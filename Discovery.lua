-- Atlas de chasse · what the hunter sees in the world teaches the atlas.
--
-- The generated data has no French name for some teachers and no coordinate at
-- all for others. Both are learned while playing: a beast the hunter targets or
-- points at, close enough that the hunter's own position stands for its own,
-- leaves its localized name and the place it was seen.
--
-- Account-wide, two kinds of fact:
--   AtlasDeChasseDB.seen[npcId] =
--     { name = "<localized>", locale = "frFR", family = 5,
--       levelMin = 7, levelMax = 8, class = "rare",
--       spots = { { map, x, y, t } } }
--   AtlasDeChasseDB.tamed[npcId] =
--     { ranks = { spellId, ... }, family = 5, level = 7, t = <time> }
--
-- The name and the position need the hunter to stand next to the beast; its
-- family, its level and how rare it is are read from any distance. A tame says
-- one thing more: a freshly tamed beast knows the ranks it teaches, so reading
-- its spellbook tells what that beast can give.
--
-- Nothing here reads a secret value: every client read is guarded and skipped
-- silently, so a target in combat or in an instance simply teaches nothing.
local _, ns = ...

local Discovery = {}
ns.Discovery = Discovery

local Guard = ns.Pet.Guard

local MERGE_DISTANCE = 3   -- map units: a zone is 100 wide
local MAX_SPOTS = 5
local TAME_BEAST = 1515    -- the Tame Beast spell
local TAME_WINDOW = 90     -- seconds a finished tame still counts as ours
-- A pet's spellbook can fill a moment after the pet itself appears.
local RETRY_DELAYS = { 1, 3 }

-- The classifications worth remembering: a "normal" beast teaches the data
-- nothing, a rare one is exactly what the hunter hunts.
local KEPT_CLASSES = { rare = true, rareelite = true, elite = true, worldboss = true }

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

-- Seconds since the client started: the clock to measure a tame with, since a
-- timer and the cast share it (time() may jump with the system clock).
local function Uptime()
	if type(GetTime) ~= "function" then return nil end
	local ok, value = pcall(GetTime)
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

-- The tames the account has done, created on first use (EnsureDB also makes it).
function Discovery.TamedStore()
	local db = ns.db
	if type(db) ~= "table" then return nil end
	if type(db.tamed) ~= "table" then db.tamed = {} end
	return db.tamed
end

function Discovery.Tamed(npcId)
	local store = Discovery.TamedStore()
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
-- adding another, and past MAX_SPOTS the oldest goes. The family, the level and
-- the classification are kept the widest way round: a beast met at 7 and at 9
-- was seen at 7-9. Returns what was new.
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

	local learnedFacts = false
	if sighting.family and record.family ~= sighting.family then
		record.family, learnedFacts = sighting.family, true
	end
	if sighting.levelMin and sighting.levelMax then
		if type(record.levelMin) ~= "number" or sighting.levelMin < record.levelMin then
			record.levelMin, learnedFacts = sighting.levelMin, true
		end
		if type(record.levelMax) ~= "number" or sighting.levelMax > record.levelMax then
			record.levelMax, learnedFacts = sighting.levelMax, true
		end
	end
	if sighting.class and record.class ~= sighting.class then
		record.class, learnedFacts = sighting.class, true
	end

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
	return learnedName, learnedSpot, learnedFacts
end

-----------------------------------------------------------------------------
-- Reading the world
-----------------------------------------------------------------------------

-- The npc id inside a creature or pet GUID, or nil when there is none. The id
-- sits right before the spawn id, the last field, in both shapes:
--   Creature-0-<server>-<instance>-<zone>-<npc>-<spawn>
--   Pet-0-<server>-<instance>-<zone>-<npc>-<spawn>
local function GuidNpcId(guid, prefix)
	if type(guid) ~= "string" or not guid:match(prefix) then return nil end
	local fields = {}
	for field in guid:gmatch("[^-]+") do fields[#fields + 1] = field end
	if #fields < 3 then return nil end
	return tonumber(fields[#fields - 1])
end

-- The npc id of a creature unit, or nil for anything else.
function Discovery.NpcId(unit)
	if type(UnitGUID) ~= "function" then return nil end
	local guid = Guard(UnitGUID, unit)
	if type(guid) ~= "string" or not guid:match("^Creature%-") then return nil end
	return GuidNpcId(guid, "^Creature%-")
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

-- Family id of a creature, only when the data knows that family: UnitCreatureFamily
-- answers the localized name first and the numeric id second.
local function UnitFamily(unit)
	local _, second = Guard(UnitCreatureFamily, unit)
	if type(second) == "number" and ns.families and ns.families[second] then return second end
	return nil
end

-- The level the client shows; a skull (-1) or a hidden unit says nothing.
local function UnitLevelOf(unit)
	local level = Guard(UnitLevel, unit)
	if type(level) == "number" and level > 0 then return level end
	return nil
end

local function Classification(unit)
	local class = Guard(UnitClassification, unit)
	if type(class) == "string" and KEPT_CLASSES[class] then return class end
	return nil
end

-- What the client tells about a beast wherever it stands. Each read is guarded:
-- a secret value or a missing one simply records nothing.
local function UnitFacts(unit)
	local family = UnitFamily(unit)
	local level = UnitLevelOf(unit)
	local class = Classification(unit)
	if not family and not level and not class then return nil end
	return { family = family, levelMin = level, levelMax = level, class = class }
end

-----------------------------------------------------------------------------
-- A tame: what the fresh pet arrived knowing
-----------------------------------------------------------------------------

-- The tame being waited for, and the pet we last looked at: the pair is what
-- tells a pet we just tamed from the one that was already out.
local pending    -- { npcId = <beast>, t = <uptime>, retries = n }
local lastPetGuid

local function Spellbook()
	local spells = ns.Pet and ns.Pet.Spells and ns.Pet.Spells()
	if type(spells) ~= "table" then return {} end
	return spells
end

-- The pet the hunter has out, its npc id and its GUID: nil nil when there is no
-- pet, and a nil id for a pet the client does not name a creature.
local function PetNpcId()
	local guid = Guard(UnitGUID, "pet")
	if type(guid) ~= "string" or guid == "" then return nil, nil end
	return GuidNpcId(guid, "^Pet%-"), guid
end

-- Tame Beast started by the player: remember which beast, since the pet that
-- follows is how we learn what it teaches.
function Discovery.TameStart(spellID)
	if spellID ~= TAME_BEAST then return end
	local npcId = Discovery.NpcId("target")
	if not npcId or type(ns.beasts) ~= "table" or not ns.beasts[npcId] then return end
	local t = Uptime()
	if not t then return end
	pending = { npcId = npcId, t = t }
end

-- Records the ranks, the family and the level of the fresh pet. A beast tamed
-- twice overwrites its record: the latest tame is the one that counts.
local function RememberTame(npcId, spells)
	local store = Discovery.TamedStore()
	if not store then return end
	-- only the spells a pet ability really carries: Attack or Growl teach nothing
	local planner = ns.Planner
	local ranks = {}
	for _, spell in ipairs(spells) do
		local spellID = type(spell) == "table" and spell.spellID or nil
		if type(spellID) == "number" and planner and planner.RankOf(spellID) then
			ranks[#ranks + 1] = spellID
		end
	end
	table.sort(ranks)

	local family
	if ns.Pet and ns.Pet.Family then family = ns.Pet.Family() end
	if type(family) ~= "number" then family = nil end
	local level = UnitLevelOf("pet")

	store[npcId] = { ranks = ranks, family = family, level = level, t = Now() }
end

-- A pet appeared: if it is the beast we just tamed, its spellbook says which
-- ranks that beast teaches. Called on UNIT_PET and on SPELLS_CHANGED, because
-- the spellbook can fill after the pet itself; returns true when recorded.
function Discovery.TameCheck()
	local npcId, guid = PetNpcId()
	if not guid then
		-- no pet out: the one we knew is gone, the next one is new
		lastPetGuid = nil
		return false
	end

	local t = Uptime()
	if not pending or not t or t - pending.t > TAME_WINDOW then
		pending, lastPetGuid = nil, guid
		return false
	end
	-- the pet we already looked at, the one that was out before the cast
	if guid == lastPetGuid then return false end
	-- never record a wrong beast: a pet that names another beast is not the one
	if npcId and npcId ~= pending.npcId then
		pending, lastPetGuid = nil, guid
		return false
	end

	local spells = Spellbook()
	if #spells == 0 then
		-- a moment late on this client: try again shortly, then give up
		local delay = RETRY_DELAYS[(pending.retries or 0) + 1]
		if delay and C_Timer and C_Timer.After then
			pending.retries = (pending.retries or 0) + 1
			C_Timer.After(delay, Discovery.TameCheck)
		else
			pending, lastPetGuid = nil, guid
		end
		return false
	end

	RememberTame(pending.npcId, spells)
	pending, lastPetGuid = nil, guid
	return true
end

-----------------------------------------------------------------------------
-- One unit, and the merge the window reads
-----------------------------------------------------------------------------

-- Watches one unit ("target", "mouseover") and stores what it teaches. The name
-- and the position need the unit close by; the family, the level and the
-- classification are read from any distance. Returns what was new, nil when the
-- unit is not a beast of the data or teaches nothing new.
function Discovery.Watch(unit)
	local store = Discovery.Store()
	local beasts = ns.beasts
	if not store or type(beasts) ~= "table" then return nil end
	local npcId = Discovery.NpcId(unit)
	local beast = npcId and beasts[npcId]
	if not beast then return nil end

	local name
	local map, x, y
	local facts = UnitFacts(unit) or {}
	-- The hunter's position stands for the beast's, so a distant or hidden unit
	-- would place it where the hunter stands: only a close one is placed, and
	-- only a close one leaves its name. Its family, level and rarity are read
	-- wherever it stands.
	if Discovery.Close(unit) then
		name = Guard(UnitName, unit)
		if type(name) ~= "string" or name == "" then name = nil end
		map, x, y = Discovery.Position()
	end
	if not name and not map and not facts.family and not facts.levelMin and not facts.class then
		return nil
	end

	local before = SpotCount((Discovery.Seen(npcId) or {}).spots)
	local learnedName, learnedSpot, learnedFacts = Remember(store, npcId, {
		name = name,
		locale = name and ClientLocale() or nil,
		family = facts.family,
		levelMin = facts.levelMin, levelMax = facts.levelMax,
		class = facts.class,
		map = map, x = x, y = y, t = Now(),
	})
	if not learnedName and not learnedSpot and not learnedFacts then return nil end

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
		-- a French client with a French name returned above: everyone else reads
		-- the data's English name
		name = beast.en or fr or ""
	end

	local spots = beast.spots
	if SpotCount(spots) > 0 then return name, spots, false end
	local remembered = record and record.spots
	if SpotCount(remembered) > 0 then return name, remembered, true end
	return name, {}, false
end

-- Everything the hunter has learned about one beast, for the window to read
-- later: where it was seen, and what its tame said it teaches. A level read off
-- the pet is a level of the beast too, when no sighting gave one.
function Discovery.Facts(npcId)
	local record = Discovery.Seen(npcId)
	local tamed = Discovery.Tamed(npcId)
	local family = (tamed and tamed.family) or (record and record.family)
	local levelMin = record and record.levelMin
	local levelMax = record and record.levelMax
	if not levelMin and tamed and tamed.level then levelMin, levelMax = tamed.level, tamed.level end
	local class = record and record.class
	local ranks = tamed and tamed.ranks
	if not family and not levelMin and not class and not ranks then return nil end
	return {
		family = family,
		levelMin = levelMin,
		levelMax = levelMax,
		class = class,
		tamedRanks = ranks,
	}
end
