-- Atlas de chasse · what the client actually tells us about the hunter's pet.
--
-- Verified on the real client (French, cat out):
--   UnitCreatureFamily("pet")  -> "Félin", 2      (the numeric id IS returned)
--   GetPetIcon()               -> 132185          (a fileID, not a path)
--   GetPetLoyalty()            -> nil
--   GetPetTrainingPoints()     -> nil
--   C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Pet) -> table
--   the global GetSpellBookItemInfo is nil
-- Pet slots are sparse: iterate to a bound and skip what is not a spell.
--
-- Every read is guarded: some values are "secret" in combat or instances and
-- must never be indexed or compared.
local _, ns = ...

local Pet = {}
ns.Pet = Pet

local MAX_PET_SLOTS = 30

-- Family ids the client hands over are matched against the data's English name
-- and against every language's name (ns.familyNames, Locale.lua), so a name any
-- client prints resolves even when the numeric id does not.

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value) and true or false
end

-- Calls a client function, never lets an error or a secret escape.
local function Guard(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	if Secret(a) then return nil end
	return a, b, c
end
Pet.Guard = Guard

local function Normalize(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("^%s+", ""):gsub("%s+$", ""):lower()
	if text == "" then return nil end
	return text
end

local familyByName   -- [normalized localized or English name] = family id

-- Built from the generated data, so the ids are the ones the data file uses.
-- Every language's name is registered, so a name any client hands over resolves.
function Pet.BuildFamilyNames()
	familyByName = {}
	for id, family in pairs(ns.families or {}) do
		if type(family) == "table" then
			-- built one by one: a nil in the middle would truncate the list
			local names = {}
			if type(family.en) == "string" then names[#names + 1] = family.en end
			if type(family.fr) == "string" then names[#names + 1] = family.fr end
			for _, localized in pairs(ns.familyNames or {}) do
				local name = localized[family.en]
				if name then names[#names + 1] = name end
			end
			for _, name in ipairs(names) do
				local key = Normalize(name)
				if key then familyByName[key] = id end
			end
		end
	end
end

local function FamilyNameIndex()
	if not familyByName then Pet.BuildFamilyNames() end
	return familyByName
end

-- A family's name for display: the client's language on a localized client,
-- English otherwise. The game's own name wins when the game is asked for it
-- (Pet.Family returns it); this is the one drawn from the data.
function Pet.DisplayName(familyId)
	local family = ns.families and ns.families[familyId]
	if type(family) ~= "table" then return tostring(familyId or "?") end
	local names = ns.lang and ns.familyNames and ns.familyNames[ns.lang]
	if names then
		local own = family[ns.lang]
		if type(own) == "string" and own ~= "" then return own end
		local localized = names[family.en]
		if localized then return localized end
	end
	return family.en or tostring(familyId)
end

function Pet.FamilyFromName(name)
	local key = Normalize(name)
	if not key then return nil end
	local id = FamilyNameIndex()[key]
	if id and ns.families and ns.families[id] then return id end
	-- a name another way of resolving already taught us
	local db = ns.db
	local remembered = db and db.familyNames and db.familyNames[key]
	if type(remembered) == "number" and ns.families and ns.families[remembered] then return remembered end
	return nil
end

-- GetPetIcon gives a fileID on this client and a path on others.
function Pet.FamilyFromIcon(icon)
	if type(icon) == "number" then
		for id, family in pairs(ns.families or {}) do
			if type(family) == "table" and family.iconId == icon then return id end
		end
		return nil
	end
	if type(icon) ~= "string" or icon == "" then return nil end
	local wanted = icon:lower()
	local fileID = tonumber(icon:match("(%d+)$"))
	for id, family in pairs(ns.families or {}) do
		if type(family) == "table" then
			if family.icon and family.icon:lower() == wanted then return id end
			if fileID and family.iconId == fileID then return id end
		end
	end
	return nil
end

-- Family id of the current pet: numeric id first, then its icon, then the
-- localized name. Whatever we learn from a name is remembered account-wide.
function Pet.Family()
	local name, second = Guard(UnitCreatureFamily, "pet")
	local id
	if type(second) == "number" and ns.families and ns.families[second] then
		id = second
	elseif type(name) == "number" and ns.families and ns.families[name] then
		id = name
	end
	if not id then id = Pet.FamilyFromIcon(Guard(GetPetIcon)) end
	local named = Pet.FamilyFromName(name)
	if not id then id = named end
	local db = ns.db
	if id and not named and db and db.familyNames then
		local key = Normalize(name)
		if key then db.familyNames[key] = id end
	end
	return id, (type(name) == "string" and name ~= "") and name or nil
end

-- Pet spellbook: sparse slots, tables from C_SpellBook, name+rank fallback for
-- clients that only have GetSpellBookItemName. Unknown spells are kept as they
-- are, the planner ignores the ones no ability teaches.
function Pet.Spells()
	local spells = {}
	local count
	if C_SpellBook and C_SpellBook.HasPetSpells then
		count = Guard(C_SpellBook.HasPetSpells)
	else
		count = Guard(HasPetSpells)
	end
	if type(count) ~= "number" or count <= 0 then count = MAX_PET_SLOTS end
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
	for i = 1, math.min(count, MAX_PET_SLOTS) do
		local spell = { slot = i }
		local info
		if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and bank then
			info = Guard(C_SpellBook.GetSpellBookItemInfo, i, bank)
		end
		if type(info) == "table" then
			local ok, spellID, name, sub = pcall(function()
				return info.spellID or info.actionID, info.name, info.subName
			end)
			if ok and not Secret(spellID) then
				if type(spellID) == "number" then spell.spellID = spellID end
				if type(name) == "string" then spell.name = name end
				if type(sub) == "string" then spell.sub = sub end
			end
		end
		if not spell.spellID then
			-- Older shape: the item info tells the kind, the name tells the rest.
			local kind, actionID = Guard(GetSpellBookItemInfo, i, "pet")
			local name, sub, spellID = Guard(GetSpellBookItemName, i, "pet")
			if not spellID and type(actionID) == "number" and (kind == nil or kind == "SPELL" or kind == "PETACTION") then
				spellID = actionID
			end
			if type(spellID) == "number" then spell.spellID = spellID end
			if type(name) == "string" then spell.name = name end
			if type(sub) == "string" then spell.sub = sub end
		end
		if spell.spellID or spell.name then spells[#spells + 1] = spell end
	end
	return spells
end

-- "PD 34 / 75" when the client has the numbers, nothing when it does not:
-- on the verified client both reads return nil.
function Pet.TrainingPoints()
	local points, pointsMax = Guard(GetPetTrainingPoints)
	if type(points) ~= "number" then return nil end
	if type(pointsMax) ~= "number" then pointsMax = nil end
	return points, pointsMax
end

function Pet.Loyalty()
	local loyalty = Guard(GetPetLoyalty)
	if type(loyalty) == "string" and loyalty ~= "" then return loyalty end
	if type(loyalty) == "number" then return tostring(loyalty) end
	return nil
end

function Pet.Info()
	local info = { exists = Guard(UnitExists, "pet") and true or false, spells = {} }
	if not info.exists then return info end
	info.name = Guard(UnitName, "pet")
	local level = Guard(UnitLevel, "pet")
	if type(level) == "number" and level > 0 then info.level = level end
	info.familyId, info.familyName = Pet.Family()
	info.points, info.pointsMax = Pet.TrainingPoints()
	info.loyalty = Pet.Loyalty()
	info.spells = Pet.Spells()
	return info
end

Pet.BuildFamilyNames()
