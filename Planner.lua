-- Atlas de chasse · the planner: pure Lua, no UI, no client reads.
-- Given a family, a pet level and the pet's spellbook it says which rank the
-- pet can learn now, which later, which the pet trainer sells, and which
-- beasts teach a given rank once the filters are applied.
local _, ns = ...

local Planner = {}
ns.Planner = Planner

local L = ns.L
-- merged in one place: the data and what the hunter saw (loaded before us, see
-- the toc)
local Discovery = ns.Discovery

local function Norm(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("^%s+", ""):gsub("%s+$", ""):lower()
	if text == "" then return nil end
	return text
end

-----------------------------------------------------------------------------
-- Rank indexes: spellID -> (ability, rank), localized name -> ability
-----------------------------------------------------------------------------

local spellIndex = {}   -- [spellID] = { ability = ability, rank = n }
local nameIndex = {}    -- [normalized name] = ability
-- the same facts the other way round: what each beast teaches
local beastIndex = {}   -- [npcId] = { { ability = ability, rank = n, record = <rank record> }, ... }

local ROMAN = { I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000 }

-- "IV" -> 4. Used for ranks the client writes inside the name
-- ("Attaque rapide IV") instead of the sub name.
function Planner.Roman(text)
	if type(text) ~= "string" then return nil end
	text = text:upper()
	if not text:match("^[IVXLCDM]+$") then return nil end
	local total, previous = 0, 0
	for i = #text, 1, -1 do
		local value = ROMAN[text:sub(i, i)]
		if not value then return nil end
		if value < previous then
			total = total - value
		else
			total = total + value
			previous = value
		end
	end
	if total <= 0 then return nil end
	return total
end

function Planner.BuildIndexes()
	spellIndex, nameIndex, beastIndex = {}, {}, {}
	for _, ability in ipairs(ns.abilities or {}) do
		local first
		for index, record in ipairs(ability.ranks or {}) do
			-- the rank NUMBER, not its position: Faster Attack holds its only
			-- rank (4) in the first slot of the array
			local number = record.rank or index
			if type(record.spell) == "number" then
				spellIndex[record.spell] = { ability = ability, rank = number }
			end
			-- so the window can ask a beast, not only a rank, what it teaches
			for _, teacherID in ipairs(record.teachers or {}) do
				local list = beastIndex[teacherID]
				if not list then
					list = {}
					beastIndex[teacherID] = list
				end
				list[#list + 1] = { ability = ability, rank = number, record = record }
			end
			if not first then first = record end
		end
		local key = Norm(ability.en)
		if key then nameIndex[key] = ability end
		-- The client names abilities in its own language ("Griffe"): ask the
		-- client for the name of the first rank, never compare English names.
		if first and type(first.spell) == "number" and C_Spell and C_Spell.GetSpellName then
			local ok, name = pcall(C_Spell.GetSpellName, first.spell)
			if ok and type(name) == "string" and name ~= "" then
				local localized = Norm(name)
				if localized then
					nameIndex[localized] = ability
					ability.localName = name
				end
			end
		end
		-- The generated data has no icon for a few abilities (Faster Attack):
		-- ask the client for one.
		if not ability.icon and first and type(first.spell) == "number"
			and C_Spell and C_Spell.GetSpellTexture then
			local ok, texture = pcall(C_Spell.GetSpellTexture, first.spell)
			if ok and texture ~= nil then ability.icon = texture end
		end
	end
end

-- What one beast teaches: { { ability, rank, record }, ... } read off the
-- reverse index above, so a tooltip can ask a beast instead of a rank. Empty
-- when the data names it as no teacher.
function Planner.Teaches(npcId)
	if type(npcId) ~= "number" then return {} end
	return beastIndex[npcId] or {}
end

-- The rank numbers an ability really has, in order (usually 1..n).
function Planner.RankNumbers(ability)
	local numbers = {}
	for index, record in ipairs(ability and ability.ranks or {}) do
		numbers[#numbers + 1] = record.rank or index
	end
	table.sort(numbers)
	return numbers
end

-- The rank record of an ability for a rank NUMBER (ranks are not always the
-- array index: Faster Attack's rank 4 is its first record).
function Planner.RankAt(ability, rankNumber)
	if type(ability) ~= "table" or type(rankNumber) ~= "number" then return nil end
	for _, record in ipairs(ability.ranks or {}) do
		if (record.rank or 0) == rankNumber then return record end
	end
	return nil
end

-- "Bite the enemy, causing 31 to 37 damage" in the client's language when the
-- client can tell us, the data's English sentence otherwise.
function Planner.Description(rankRecord)
	if type(rankRecord) ~= "table" then return nil end
	if type(rankRecord.spell) == "number" and C_Spell and C_Spell.GetSpellDescription then
		local ok, text = pcall(C_Spell.GetSpellDescription, rankRecord.spell)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	return ns.Effect(rankRecord.desc)
end

-- Whether any zone of the data carries a faction. The generated data has none,
-- so the window does not offer a filter that cannot work.
function Planner.HasZoneFactions()
	for _, zone in pairs(ns.zones or {}) do
		if type(zone) == "table" and zone.faction then return true end
	end
	return false
end

-- Ability and rank number a pet spellbook entry stands for, or nil.
function Planner.RankOf(spellID)
	local entry = type(spellID) == "number" and spellIndex[spellID] or nil
	if not entry then return nil end
	return entry.ability, entry.rank
end

-- Fallback for a spellID the data does not carry: the client's own name plus
-- the rank ("Rang 4" in subName, or a Roman numeral at the end of the name).
function Planner.RankOfName(name, sub)
	local key = Norm(name)
	if not key then return nil end
	local ability = nameIndex[key]
	local wanted = tonumber(tostring(sub or ""):match("(%d+)"))
	if not ability then
		local base, roman = key:match("^(.-)%s+([ivxlcdm]+)$")
		if base then
			ability = nameIndex[base]
			if ability then wanted = Planner.Roman(roman) end
		end
	end
	if not ability then return nil end
	local numbers = Planner.RankNumbers(ability)
	if #numbers == 0 then return nil end
	wanted = wanted or numbers[1]
	-- the highest rank number the ability really has, up to the wanted one
	local chosen = numbers[1]
	for _, number in ipairs(numbers) do
		if number <= wanted then chosen = number end
	end
	return ability, chosen
end

function Planner.RankOfSpell(spell)
	if type(spell) ~= "table" then return nil end
	local ability, rank = Planner.RankOf(spell.spellID)
	if not ability then ability, rank = Planner.RankOfName(spell.name, spell.sub) end
	return ability, rank
end

-----------------------------------------------------------------------------
-- Families
-----------------------------------------------------------------------------

function Planner.FamilyHas(ability, familyId)
	local families = ability.families
	if families == "all" then return true end
	if type(families) ~= "table" or not familyId then return false end
	if families[familyId] == true or families[familyId] == familyId then return true end
	for _, id in ipairs(families) do
		if id == familyId then return true end
	end
	return false
end

local function ByRankThenName(a, b)
	local left = Planner.RankAt(a.ability, a.rank)
	local right = Planner.RankAt(b.ability, b.rank)
	local leftLevel = (left and left.petLevel) or 99
	local rightLevel = (right and right.petLevel) or 99
	if leftLevel ~= rightLevel then return leftLevel < rightLevel end
	local leftName = a.ability.en or ""
	local rightName = b.ability.en or ""
	if leftName ~= rightName then return leftName < rightName end
	return a.rank < b.rank
end
ns.Planner.ByRankThenName = ByRankThenName

-- Whether any rank of an ability names a teacher.
local function HasTeachers(ability)
	for _, record in ipairs(ability.ranks or {}) do
		if record.teachers and #record.teachers > 0 then return true end
	end
	return false
end

-----------------------------------------------------------------------------
-- The plan
-----------------------------------------------------------------------------
-- [ability.key] = highest rank the pet's spellbook holds: the one read the
-- plan, the tooltip and the zone list all need. A spell the data does not
-- carry, or one whose name and rank resolve to nothing, teaches nothing here.
function Planner.Known(spells)
	local known = {}
	if type(spells) ~= "table" then return known end
	for _, spell in ipairs(spells) do
		local ability, rank = Planner.RankOfSpell(spell)
		if ability then
			local best = known[ability.key] or 0
			if rank > best then known[ability.key] = rank end
		end
	end
	return known
end

-- opts = { familyId, petLevel, spells = pet spellbook, learned = hunter ranks }
-- Returns { now = {...}, later = {...}, trainer = {...}, maxed = {...} } where
-- each entry is { ability, rank, known = highest rank the pet has }.
function Planner.Plan(opts)
	opts = opts or {}
	local plan = { now = {}, later = {}, trainer = {}, maxed = {} }
	local familyId = opts.familyId
	if not familyId then return plan end
	local petLevel = opts.petLevel or 0

	local known = Planner.Known(opts.spells)

	for _, ability in ipairs(ns.abilities or {}) do
		local numbers = Planner.RankNumbers(ability)
		if Planner.FamilyHas(ability, familyId) and #numbers > 0 then
			local have = known[ability.key] or 0
			-- the lowest rank number the pet does not have yet
			local nextRank
			for _, number in ipairs(numbers) do
				if number > have then
					nextRank = number
					break
				end
			end
			-- A rank written in Roman numerals that the data only knows from
			-- the client (Faster Attack) cannot be learned from a beast: show it
			-- only when the pet already has it.
			local unknownSource = ability.roman and not HasTeachers(ability)
			local skip = nextRank ~= nil and unknownSource and have == 0
			if not skip then
				local entry = { ability = ability, rank = nextRank or numbers[#numbers], known = have }
				if not nextRank then
					plan.maxed[#plan.maxed + 1] = entry
				elseif ability.src == "trainer" then
					plan.trainer[#plan.trainer + 1] = entry
				elseif (Planner.RankAt(ability, nextRank).petLevel or 0) <= petLevel then
					plan.now[#plan.now + 1] = entry
				else
					plan.later[#plan.later + 1] = entry
				end
			end
		end
	end

	for _, group in ipairs({ plan.now, plan.later, plan.trainer, plan.maxed }) do
		table.sort(group, ByRankThenName)
	end
	return plan
end

-----------------------------------------------------------------------------
-- Teachers of one rank
-----------------------------------------------------------------------------

local zoneByName

local function ZoneIndex()
	if zoneByName then return zoneByName end
	zoneByName = {}
	for id, zone in pairs(ns.zones or {}) do
		if type(zone) == "table" and type(zone.en) == "string" then
			local key = Norm(zone.en)
			if key then zoneByName[key] = id end
		end
	end
	return zoneByName
end

function Planner.ZoneFaction(mapID, zoneEn)
	if type(mapID) == "number" and ns.zones and ns.zones[mapID] then
		return ns.zones[mapID].faction
	end
	if type(zoneEn) == "string" then
		local id = ZoneIndex()[Norm(zoneEn) or ""]
		local zone = id and ns.zones and ns.zones[id]
		if zone then return zone.faction end
	end
	return nil
end

-- The zone name the game prints, in the client's language.
function Planner.ZoneName(mapID, fallback)
	if type(mapID) == "number" and C_Map and C_Map.GetMapInfo then
		local ok, info = pcall(C_Map.GetMapInfo, mapID)
		if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
			return info.name
		end
	end
	return fallback
end

-- French beast names on a French client, English otherwise; a name the hunter
-- learned by seeing the beast comes between the two (Discovery merges them).
function Planner.BeastName(beast, id)
	if type(beast) ~= "table" then return "" end
	return Discovery.Merge(id, beast)
end

-- One teacher, with the filters applied, or nil when it must be hidden.
-- opts = { playerLevel, faction, currentMap, filters = {...} }
function Planner.Evaluate(id, beast, opts)
	if type(beast) ~= "table" then return nil end
	opts = opts or {}
	local filters = opts.filters or {}
	local faction = opts.faction

	if beast.dungeonZone and not filters.dungeons then return nil end

	if filters.tameable then
		local tame = beast.tame
		if tame == "N" then return nil end
		if tame == "H" and faction and faction ~= "Horde" then return nil end
		if tame == "A" and faction and faction ~= "Alliance" then return nil end
		if opts.playerLevel and (beast.minLevel or 0) > opts.playerLevel then return nil end
	end

	-- The data first; the spots the hunter found themselves only when it has none.
	local name, spots, fromSights = Discovery.Merge(id, beast)
	local kept = {}
	for _, spot in ipairs(spots) do
		local keep = true
		if filters.faction and faction then
			local zoneFaction = Planner.ZoneFaction(spot.map)
			if zoneFaction and zoneFaction ~= faction then keep = false end
		end
		if keep and filters.zone and opts.currentMap and spot.map ~= opts.currentMap then keep = false end
		if keep then kept[#kept + 1] = spot end
	end
	if #spots > 0 then
		if #kept == 0 then return nil end
	else
		-- No coordinates in the data: filter on the zone it names.
		if filters.zone and opts.currentMap then
			local zoneID = ZoneIndex()[Norm(beast.zoneEn) or ""]
			if zoneID ~= opts.currentMap then return nil end
		end
		if filters.faction and faction then
			local zoneFaction = Planner.ZoneFaction(nil, beast.zoneEn)
			if zoneFaction and zoneFaction ~= faction then return nil end
		end
	end

	local spot = kept[1]
	if filters.zone and opts.currentMap then
		for _, candidate in ipairs(kept) do
			if candidate.map == opts.currentMap then spot = candidate break end
		end
	end

	local minLevel = beast.minLevel or beast.maxLevel or 0
	local maxLevel = beast.maxLevel or minLevel
	local mapID = spot and spot.map
	local zoneName = Planner.ZoneName(mapID, beast.dungeonZone or beast.zoneEn)

	return {
		id = id,
		beast = beast,
		name = name,
		minLevel = minLevel,
		maxLevel = maxLevel,
		levelText = minLevel == maxLevel and tostring(minLevel) or (minLevel .. "-" .. maxLevel),
		high = (opts.playerLevel ~= nil and minLevel > opts.playerLevel) or false,
		map = mapID,
		x = spot and spot.x,
		y = spot and spot.y,
		-- the position is where the hunter saw it, not what the data says
		seenPosition = fromSights or nil,
		zoneName = zoneName or "",
		dungeon = beast.dungeonZone,
		rare = beast.rare,
		elite = beast.elite,
	}
end

-- opt.filters: tameable, faction, zone, dungeons (true = filter on).
function Planner.Teachers(rankRecord, opts)
	local list = {}
	for _, id in ipairs(rankRecord and rankRecord.teachers or {}) do
		local beast = ns.beasts and ns.beasts[id]
		local entry = beast and Planner.Evaluate(id, beast, opts)
		if entry then list[#list + 1] = entry end
	end
	table.sort(list, function(a, b)
		if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
		if a.name ~= b.name then return a.name < b.name end
		return (a.id or 0) < (b.id or 0)
	end)
	return list
end

-----------------------------------------------------------------------------
-- One beast against the hunter's pet
-----------------------------------------------------------------------------

-- Why one rank of one ability is, or is not, worth a tame. ctx = { familyId,
-- petLevel, known = Planner.Known(), learned = the hunter's learned table,
-- playerLevel, beast }. Returns the status and the gain in rank:
--   "family"    the ability is not for the pet's family (callers hide it)
--   "known"     the pet already holds this rank or a higher one
--   "learned"   the hunter learned it: it is in Beast Training, no tame needed
--   "petLevel"  the pet is too low for the rank (callers say which level)
--   "tooHigh"   the hunter cannot tame that beast yet, or never can
--   "tame"      worth taming that beast for that rank
function Planner.Verdict(ability, rankNumber, record, ctx)
	if type(ability) ~= "table" or type(record) ~= "table" then return nil, 0 end
	ctx = ctx or {}
	local rank = tonumber(rankNumber) or 0
	local have = (ctx.known or {})[ability.key] or 0
	local gain = rank - have
	-- No pet out: every family is worth a look, since one may be tamed later.
	if ctx.familyId ~= nil and not Planner.FamilyHas(ability, ctx.familyId) then
		return "family", gain
	end
	if have >= rank then return "known", gain end
	if type(record.spell) == "number" and (ctx.learned or {})[record.spell] then
		return "learned", gain
	end
	if (record.petLevel or 0) > (ctx.petLevel or 0) then return "petLevel", gain end
	local beast = ctx.beast
	if beast then
		-- a hunter level the client did not tell is no reason to hide a beast
		if ctx.playerLevel ~= nil and (beast.minLevel or 0) > ctx.playerLevel then
			return "tooHigh", gain
		end
		if beast.tame == "N" then return "tooHigh", gain end
	end
	return "tame", gain
end

-- Where a fact comes from, strongest first: a tame of that beast listed the
-- spell, the hunter saw the beast (one spot is enough), Wowhead placed it, the
-- data source named it.
function Planner.Source(npcId, spellID)
	if type(npcId) ~= "number" then return nil end
	local tamed = Discovery.Tamed and Discovery.Tamed(npcId)
	if type(tamed) == "table" then
		for _, spell in ipairs(tamed.ranks or {}) do
			if spell == spellID then return "verified" end
		end
	end
	local seen = Discovery.Seen and Discovery.Seen(npcId)
	if type(seen) == "table" and type(seen.spots) == "table" and #seen.spots > 0 then
		return "seen"
	end
	local beast = ns.beasts and ns.beasts[npcId]
	if type(beast) ~= "table" then return nil end
	-- the same two facts, gathered by the maintainer and shipped in the data
	if beast.verified then return "verified" end
	if beast.spotsSrc == "ingame" then return "seen" end
	if beast.spotsSrc == "wowhead" then return "wowhead" end
	return beast.src
end

-----------------------------------------------------------------------------
-- The zone the hunter stands in
-----------------------------------------------------------------------------

-- which list a status goes to; "family" is missing, so it is dropped
local HERE_GROUP = {
	tame = "now", petLevel = "later", tooHigh = "later",
	known = "done", learned = "done",
}

-- The level a "later" entry waits for: the pet level of the rank, or the level
-- the hunter must reach to tame the beast, whichever comes last.
local function WaitsFor(entry)
	return math.max(entry.record.petLevel or 0, entry.teacher.minLevel or 0)
end

local function SortNow(a, b)
	if a.gain ~= b.gain then return a.gain > b.gain end
	if (a.record.petLevel or 0) ~= (b.record.petLevel or 0) then
		return (a.record.petLevel or 0) < (b.record.petLevel or 0)
	end
	if (a.teacher.minLevel or 0) ~= (b.teacher.minLevel or 0) then
		return (a.teacher.minLevel or 0) < (b.teacher.minLevel or 0)
	end
	if a.teacher.name ~= b.teacher.name then return a.teacher.name < b.teacher.name end
	return (a.teacher.id or 0) < (b.teacher.id or 0)
end

local function SortLater(a, b)
	local left, right = WaitsFor(a), WaitsFor(b)
	if left ~= right then return left < right end
	if a.gain ~= b.gain then return a.gain > b.gain end
	if a.teacher.name ~= b.teacher.name then return a.teacher.name < b.teacher.name end
	return (a.teacher.id or 0) < (b.teacher.id or 0)
end

local function SortDone(a, b)
	local left, right = a.ability.en or "", b.ability.en or ""
	if left ~= right then return left < right end
	if a.rank ~= b.rank then return a.rank < b.rank end
	return (a.teacher.id or 0) < (b.teacher.id or 0)
end

-- Everything this zone can teach the hunter's pet, one entry per (rank, beast):
-- what to tame now, what waits for a level, what is already settled. Beasts of
-- the zone come from Evaluate, so the data's spots, the hunter's own sightings
-- and the zone name written in the data all count, and dungeons stay out.
-- ctx = { mapID, familyId, petLevel, spells, learned, playerLevel, faction }.
function Planner.Here(ctx)
	ctx = ctx or {}
	local here = { zoneName = nil, now = {}, later = {}, done = {} }
	local mapID = ctx.mapID
	if type(mapID) ~= "number" then return here end
	local zone = ns.zones and ns.zones[mapID]
	here.zoneName = Planner.ZoneName(mapID, type(zone) == "table" and zone.en or nil)

	-- the pet's side of the verdict, computed once for every beast of the zone
	local facts = {
		familyId = ctx.familyId,
		petLevel = ctx.petLevel,
		known = Planner.Known(ctx.spells),
		learned = ctx.learned,
		playerLevel = ctx.playerLevel,
	}
	for id, beast in pairs(ns.beasts or {}) do
		local teacher = Planner.Evaluate(id, beast, {
			playerLevel = ctx.playerLevel,
			faction = ctx.faction,
			currentMap = mapID,
			filters = { zone = true },
		})
		if teacher then
			facts.beast = beast
			for _, teach in ipairs(Planner.Teaches(id)) do
				local status, gain = Planner.Verdict(teach.ability, teach.rank, teach.record, facts)
				local group = status and HERE_GROUP[status]
				if group then
					local list = here[group]
					list[#list + 1] = {
						ability = teach.ability,
						rank = teach.rank,
						record = teach.record,
						teacher = teacher,
						status = status,
						gain = gain,
						source = Planner.Source(id, teach.record.spell),
					}
				end
			end
		end
	end
	table.sort(here.now, SortNow)
	table.sort(here.later, SortLater)
	table.sort(here.done, SortDone)
	return here
end

Planner.BuildIndexes()
