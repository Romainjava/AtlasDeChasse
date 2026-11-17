#!/usr/bin/env bun
"use strict";

// Checks the generated Data/Data.lua against the facts the addon relies on:
// the build is reproducible, the file loads through the "local _, ns = ..." vararg,
// key ranks carry the spell ids the forever client showed, the beasts a hunter
// has to tame are in the database with their French name and coordinates, and each
// zone carries the faction warcraft.wiki.gg gives it.
//
//   bun tools/build-data.test.js      (exits non-zero on failure)
//
// Every assertion below was verified against the live client or read off the sources:
// 17257/16830/14917/4190/24551 were checked in a level 25 cat's pet spellbook, 1263104
// is "Attaque rapide IV" there, 628 is "Ravageur noir" at 67.4/31.8 in Duskwood, and the
// zone factions are the bar colours of warcraft.wiki.gg's "Zones by level (original)".

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const ROOT = path.resolve(__dirname, "..");
const DATA_FILE = path.join(ROOT, "Data", "Data.lua");
const BUILD_SCRIPT = path.join(__dirname, "build-data.js");

let failures = 0;
let checks = 0;

function check(label, condition, detail) {
  checks++;
  if (condition) return;
  failures++;
  process.stdout.write(`FAIL ${label}${detail === undefined ? "" : ` -> ${detail}`}\n`);
}

// Builds through the real script (no mocks) and compares bytes with the committed file.
function assertReproducible() {
  const outFile = path.join(os.tmpdir(), `atlas-de-chasse-${process.pid}.lua`);
  const first = spawnSync(process.execPath, [BUILD_SCRIPT, "--out", outFile], { encoding: "utf8" });
  check("build runs", first.status === 0, first.stderr);
  if (first.status !== 0) return;
  const firstBytes = fs.readFileSync(outFile);
  const second = spawnSync(process.execPath, [BUILD_SCRIPT, "--out", outFile], { encoding: "utf8" });
  check("second build runs", second.status === 0, second.stderr);
  const secondBytes = fs.readFileSync(outFile);
  fs.rmSync(outFile, { force: true });

  check("two builds are byte-identical", firstBytes.equals(secondBytes), `${firstBytes.length} vs ${secondBytes.length} bytes`);
  const committed = fs.readFileSync(DATA_FILE);
  check("Data/Data.lua is up to date", committed.equals(firstBytes), "rerun bun tools/build-data.js");
}

function loadData() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  // Same contract as the addon: the chunk gets ("AtlasDeChasse", <shared table>) and fills it.
  lua.lua_newtable(L);
  lua.lua_pushvalue(L, -1);
  lua.lua_setglobal(L, to_luastring("ns"));
  lua.lua_pop(L, 1);

  const source = fs.readFileSync(DATA_FILE, "utf8");
  if (lauxlib.luaL_loadbuffer(L, to_luastring(source), null, to_luastring("Data.lua")) !== lua.LUA_OK) {
    throw new Error(`Data.lua does not parse: ${lua.lua_tojsstring(L, -1)}`);
  }
  lua.lua_pushstring(L, to_luastring("AtlasDeChasse"));
  lua.lua_getglobal(L, to_luastring("ns"));
  if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) throw new Error(`Data.lua failed: ${lua.lua_tojsstring(L, -1)}`);

  const json = lauxlib.luaL_loadbuffer(
    L,
    to_luastring(`
      local function esc(s)
        return '"' .. s:gsub('[%z\\1-\\31\\\\"]', function(c)
          if c == '"' then return '\\\\"' elseif c == '\\\\' then return '\\\\\\\\'
          elseif c == '\\n' then return '\\\\n' elseif c == '\\r' then return '\\\\r'
          elseif c == '\\t' then return '\\\\t' else return string.format('\\\\u%04x', c:byte()) end
        end) .. '"'
      end
      local function enc(v)
        local t = type(v)
        if t == 'nil' then return 'null'
        elseif t == 'boolean' then return tostring(v)
        elseif t == 'number' then
          if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format('%d', v) end
          return string.format('%.17g', v)
        elseif t == 'string' then return esc(v)
        elseif t == 'table' then
          local n, count = #v, 0
          for _ in pairs(v) do count = count + 1 end
          if count == 0 then return '[]' end
          local parts = {}
          if n > 0 and n == count then
            for i = 1, n do parts[i] = enc(v[i]) end
            return '[' .. table.concat(parts, ',') .. ']'
          end
          for k, val in pairs(v) do parts[#parts + 1] = esc(tostring(k)) .. ':' .. enc(val) end
          return '{' .. table.concat(parts, ',') .. '}'
        end
        return 'null'
      end
      return enc(ns)
    `),
    null,
    to_luastring("encode")
  );
  if (json !== lua.LUA_OK) throw new Error(`encode chunk: ${lua.lua_tojsstring(L, -1)}`);
  if (lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) throw new Error(`encode failed: ${lua.lua_tojsstring(L, -1)}`);
  const text = lua.lua_tojsstring(L, -1);
  lua.lua_close(L);
  return JSON.parse(text);
}

function abilityByName(ns, name) {
  return (ns.abilities || []).find((ability) => ability.en === name) || null;
}

function rank(ability, number) {
  return ability && ability.ranks ? ability.ranks.find((r) => r.rank === number) || null : null;
}

function teacherIds(ability, number) {
  const entry = rank(ability, number);
  return entry && entry.teachers ? entry.teachers.map(Number) : [];
}

// The spell id the client showed must land on the ability and rank the client showed.
function assertSpellMap(ns, spell, abilityName, rankNumber) {
  const ability = abilityByName(ns, abilityName);
  check(`${abilityName} exists`, ability !== null);
  if (!ability) return;
  const entry = rank(ability, rankNumber);
  check(`${abilityName} rank ${rankNumber} exists`, entry !== null, JSON.stringify(ability.ranks));
  if (!entry) return;
  check(
    `${spell} is ${abilityName} ${rankNumber}`,
    Number(entry.spell) === spell,
    `found ${entry.spell} on ${abilityName} rank ${entry.rank}`
  );
}

assertReproducible();
const ns = loadData();

// Shape of the data the runtime worker codes against.
check("families table", ns.families && Object.keys(ns.families).length > 10);
check("zones table", ns.zones && Object.keys(ns.zones).length > 10);
check("abilities is an array", Array.isArray(ns.abilities), typeof ns.abilities);
check("beasts table", ns.beasts && Object.keys(ns.beasts).length > 300);
check(
  "abilities sorted by en",
  ns.abilities.every((ability, i) => i === 0 || ns.abilities[i - 1].en <= ability.en)
);

// Family ids come from the client: a cat is family 2 and its icon is 132185.
check('family 2 is Cat', ns.families[2] && ns.families[2].en === "Cat", JSON.stringify(ns.families[2]));
check("family 2 icon id", ns.families[2] && Number(ns.families[2].iconId) === 132185, ns.families[2] && ns.families[2].iconId);

// Bite rank 4: level 24, 10 training points, spell 17257, taught by the Duskwood wolves.
const bite = abilityByName(ns, "Bite");
const bite4 = rank(bite, 4);
check("Bite 4 pet level", bite4 && Number(bite4.petLevel) === 24, bite4 && bite4.petLevel);
check("Bite 4 training points", bite4 && Number(bite4.tp) === 10, bite4 && bite4.tp);
check("Bite 4 spell", bite4 && Number(bite4.spell) === 17257, bite4 && bite4.spell);
check("Bite 4 taught by 628", teacherIds(bite, 4).includes(628), teacherIds(bite, 4).join(","));
check("Bite 4 taught by 1258", teacherIds(bite, 4).includes(1258), teacherIds(bite, 4).join(","));

const blackRavager = ns.beasts[628];
check("628 exists", Boolean(blackRavager));
check("628 English name", blackRavager && blackRavager.en === "Black Ravager", blackRavager && blackRavager.en);
check("628 French name", blackRavager && blackRavager.fr === "Ravageur noir", blackRavager && blackRavager.fr);
check("628 family is Wolf", blackRavager && Number(blackRavager.family) === 1, blackRavager && blackRavager.family);
check(
  "628 levels",
  blackRavager && Number(blackRavager.minLevel) === 24 && Number(blackRavager.maxLevel) === 25,
  blackRavager && `${blackRavager.minLevel}-${blackRavager.maxLevel}`
);
check("628 zone", blackRavager && blackRavager.zoneEn === "Duskwood", blackRavager && blackRavager.zoneEn);
check(
  "628 spot on map 1431 near 67.4/31.8",
  blackRavager &&
    (blackRavager.spots || []).some(
      (spot) => Number(spot.map) === 1431 && Math.abs(spot.x - 67.4) < 0.2 && Math.abs(spot.y - 31.8) < 0.2
    ),
  blackRavager && JSON.stringify(blackRavager.spots)
);

// Cower rank 3 is taught by the Crag Stalker, a cat of Thousand Needles.
const cower = abilityByName(ns, "Cower");
check("Cower 3 taught by 4126", teacherIds(cower, 3).includes(4126), teacherIds(cower, 3).join(","));
const cragStalker = ns.beasts[4126];
check("4126 exists", Boolean(cragStalker));
check("4126 English name", cragStalker && cragStalker.en === "Crag Stalker", cragStalker && cragStalker.en);
check("4126 French name", cragStalker && cragStalker.fr === "Traqueur des combes", cragStalker && cragStalker.fr);
check(
  "4126 has a Thousand Needles spot",
  cragStalker && (cragStalker.spots || []).some((spot) => Number(spot.map) === 1441),
  cragStalker && JSON.stringify(cragStalker.spots)
);

// Wowhead spots: Petopia and HunterPetJournal name a zone for these teachers but never place
// them, so the hand-read wowhead.com/forever NPC pages are the only source of a dot to walk to.
// Each map below is the zone the page shows: Ghost Saber prowls Darkshore, Vuldren the Zephras
// Isle, Ombassa the Riverglades and the Bloodtalon Matriarch Durotar.
const wowheadPlaced = [
  [3619, "Ghost Saber", 1439],
  [250868, "Vuldren", 2521],
  [263315, "Ombassa", 2548],
  [268530, "Bloodtalon Matriarch", 1411],
];
const unplaced = wowheadPlaced.filter(([id, name, map]) => {
  const beast = ns.beasts[id];
  const spots = (beast && beast.spots) || [];
  return (
    !beast ||
    beast.en !== name ||
    beast.spotsSrc !== "wowhead" ||
    !spots.some((spot) => Number(spot.map) === map)
  );
});
check(
  "Wowhead places those teachers in their zone",
  unplaced.length === 0,
  unplaced.map(([id, name]) => `${id} ${name}`).join(", ")
);

// Wowhead is a fallback, never an override: a beast HunterPetJournal already placed keeps its
// point, and no spot list may grow a second source. 3241 shares its teaches line with Wowhead.
const patriarch = ns.beasts[3241];
const patriarchSpots = (patriarch && patriarch.spots) || [];
check(
  "3241 keeps its HunterPetJournal spot",
  patriarchSpots.length === 1 &&
    Number(patriarchSpots[0].map) === 1413 &&
    Math.abs(patriarchSpots[0].x - 44.4) < 0.2 &&
    Math.abs(patriarchSpots[0].y - 15.8) < 0.2 &&
    patriarch.spotsSrc === undefined,
  patriarch && JSON.stringify([patriarch.spotsSrc, patriarch.spots])
);

// Wowhead's page for the Forest Stalker exists but has no spawn data, so the beast stays without
// coordinates instead of getting one nobody saw.
const forestStalker = ns.beasts[120];
check(
  "120 stays without spots",
  forestStalker && (forestStalker.spots || []).length === 0 && forestStalker.spotsSrc === undefined,
  forestStalker && JSON.stringify([forestStalker.spotsSrc, forestStalker.spots])
);

// Wowhead lists up to a hundred spawn points per beast; the build keeps at most three cluster
// centres per map, which is what keeps the file small and the map readable.
const wowheadBeasts = Object.entries(ns.beasts).filter(([, beast]) => beast.spotsSrc === "wowhead");
const crowded = wowheadBeasts.filter(([, beast]) => {
  const perMap = new Map();
  for (const spot of beast.spots) perMap.set(Number(spot.map), (perMap.get(Number(spot.map)) || 0) + 1);
  return [...perMap.values()].some((count) => count > 3);
});
check(
  "Wowhead keeps at most three spots per map",
  wowheadBeasts.length >= 20 && crowded.length === 0,
  `${wowheadBeasts.length} beasts, crowded: ${crowded.map(([id]) => id).join(",")}`
);

// French accents must survive the pipeline intact.
check(
  "French accents kept",
  ns.beasts[3825] && ns.beasts[3825].fr === "Alpha Patte-fantôme",
  ns.beasts[3825] && ns.beasts[3825].fr
);

// Spell ids read in the pet spellbook of a level 25 cat on the live client.
assertSpellMap(ns, 16830, "Claw", 4);
assertSpellMap(ns, 14917, "Growl", 3);
assertSpellMap(ns, 4190, "Great Stamina", 4);
assertSpellMap(ns, 24551, "Natural Armor", 4);
assertSpellMap(ns, 17257, "Bite", 4);
assertSpellMap(ns, 1263104, "Faster Attack", 4);
const fasterAttack = abilityByName(ns, "Faster Attack");
check("Faster Attack uses Roman ranks", fasterAttack && fasterAttack.roman === true, fasterAttack && fasterAttack.roman);

// General abilities are trainer-taught, family abilities are learned by taming.
const growl = abilityByName(ns, "Growl");
check("Growl is trainer-taught", growl && growl.src === "trainer", growl && growl.src);
check("Growl ranks have no teachers", growl.ranks.every((r) => r.teachers.length === 0));

// Every rank Petopia lists has the spell id HunterPetJournal carries.
const ranksWithoutSpell = ns.abilities.flatMap((ability) =>
  ability.ranks.filter((r) => !Number.isInteger(Number(r.spell))).map((r) => `${ability.en} ${r.rank}`)
);
check("every rank has a spell id", ranksWithoutSpell.length === 0, ranksWithoutSpell.join(", "));

// Teachers always resolve to a beast record, and every beast is referenced by a rank.
const referenced = new Set(ns.abilities.flatMap((ability) => ability.ranks.flatMap((r) => r.teachers.map(Number))));
const missingBeasts = [...referenced].filter((id) => !ns.beasts[id]);
check("every teacher has a beast record", missingBeasts.length === 0, missingBeasts.join(","));
const orphans = Object.keys(ns.beasts).filter((id) => !referenced.has(Number(id)));
check("no beast without a rank", orphans.length === 0, orphans.join(","));

// Spots always point at a known map and a plausible coordinate.
const badSpots = [];
for (const [id, beast] of Object.entries(ns.beasts)) {
  for (const spot of beast.spots || []) {
    if (!ns.zones[spot.map] || spot.x < 0 || spot.x > 100 || spot.y < 0 || spot.y > 100) {
      badSpots.push(`${id} ${JSON.stringify(spot)}`);
    }
  }
}
check("spots are inside a known zone", badSpots.length === 0, badSpots.slice(0, 5).join("; "));

// Zone factions decide whether "My faction" hides a beast, so the three colours the wiki legend
// names must land as Alliance, Horde, and nil (a contested zone is open to both sides). The wiki
// spells "The Barrens" as "Barrens", which also exercises the name matching.
const zoneFaction = (id) => ns.zones[id] && ns.zones[id].faction;

check("Westfall (1436) is Alliance", zoneFaction(1436) === "Alliance", zoneFaction(1436));
check("The Barrens (1413) is Horde", zoneFaction(1413) === "Horde", zoneFaction(1413));
check("Duskwood (1431) is contested", ns.zones[1431] && zoneFaction(1431) === undefined, zoneFaction(1431));
check(
  "Zephras Isle (2521) has no faction",
  ns.zones[2521] && zoneFaction(2521) === undefined,
  zoneFaction(2521)
);

process.stdout.write(
  `\n${checks - failures}/${checks} checks passed${failures ? `, ${failures} failed` : ""}\n`
);
process.exit(failures ? 1 : 0);
