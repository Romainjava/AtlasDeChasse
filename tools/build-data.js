#!/usr/bin/env bun
"use strict";

// Generates Data/Data.lua for AtlasDeChasse from the cached Petopia Forever abilities page,
// HunterPetJournal's data files, Polestar_frFR's French NPC names, warcraft.wiki.gg's
// zone territory colours and the hand-collected Wowhead NPC pages.
//
//   bun tools/build-data.js            # build from tools/cache/
//   bun tools/build-data.js --refresh  # fetch each page once, then build
//   bun tools/build-data.js --out x.lua
//
// The output only depends on its inputs: same cache files, same HunterPetJournal files and
// same Polestar file produce byte-identical Lua. The dates in the header are the dates the
// pages were cached, not the date of the build.

const fs = require("node:fs");
const path = require("node:path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const ROOT = path.resolve(__dirname, "..");
const CACHE_FILE = path.join(ROOT, "tools", "cache", "petopia-abilities.html");
const WIKI_CACHE_FILE = path.join(ROOT, "tools", "cache", "warcraft-wiki-zones.json");
const WOWHEAD_CACHE_FILE = path.join(ROOT, "tools", "cache", "wowhead-npcs.json");
const OUT_FILE = path.join(ROOT, "Data", "Data.lua");
const REPORT_FILE = path.join(ROOT, "tools", "build-report.txt");
const PETOPIA_URL = "https://www.wow-petopia.com/forever/abilities.php";
const WIKI_URL =
  "https://warcraft.wiki.gg/api.php?action=parse&page=Zones_by_level_(original)&prop=wikitext&format=json";
const USER_AGENT = "AtlasDeChasse-build/1.0 (static data generator)";

// Read-only game and addon data. Override with WOW_ADDONS_DIR when the client lives elsewhere.
const WOW_ADDONS = process.env.WOW_ADDONS_DIR
  ? process.env.WOW_ADDONS_DIR
  : "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns";
const HPJ_DIR = path.join(WOW_ADDONS, "HunterPetJournal", "Data");
const POLESTAR_NAMES = path.join(WOW_ADDONS, "Polestar_frFR", "Names.lua");

// Petopia's family slugs, as used in family.php links, mapped to HunterPetJournal family names.
const FAMILY_SLUGS = {
  bat: "Bat",
  bear: "Bear",
  birdofprey: "Bird of Prey",
  boar: "Boar",
  carrionbird: "Carrion Bird",
  cat: "Cat",
  corehound: "Core Hound",
  crab: "Crab",
  crocolisk: "Crocolisk",
  fox: "Fox",
  gorilla: "Gorilla",
  hyena: "Hyena",
  raptor: "Raptor",
  scorpid: "Scorpid",
  spider: "Spider",
  tallstrider: "Tallstrider",
  turtle: "Turtle",
  windserpent: "Wind Serpent",
  wolf: "Wolf",
};

// Classic pet family icons follow "Ability_Hunter_Pet_<family>", with four names that do not.
// Same convention as BeastTrainingTracker/Rares.lua. Fox and Core Hound have no family icon
// in the client, so they only get the iconId HunterPetJournal carries.
const FAMILY_ICON_NAMES = {
  "Bird of Prey": "Ability_Hunter_Pet_Owl",
  "Carrion Bird": "Ability_Hunter_Pet_Vulture",
  Tallstrider: "Ability_Hunter_Pet_TallStrider",
  "Wind Serpent": "Ability_Hunter_Pet_WindSerpent",
};
const FAMILIES_WITHOUT_ICON = new Set(["Fox", "Core Hound"]);

// Ranks read off the live Forever client that neither Petopia nor HunterPetJournal list.
// Only add a rank here when someone has seen it in the client: ids are never guessed.
// Faster Attack ranks are shown with Roman numerals ("Attaque rapide IV" in French).
const CLIENT_VERIFIED_ABILITIES = [
  {
    key: "fasterattack",
    en: "Faster Attack",
    icon: null,
    roman: true,
    src: "beast",
    families: "all",
    ranks: [{ rank: 4, spell: 1263104, petLevel: null, tp: null, desc: null }],
  },
];

const DANGLING_SOURCE = "No known training source.";

// Wowhead lists every spawn point of a beast (past a hundred for the busiest ones), which would
// bloat Data.lua and paint a cloud of dots on the map. Points no further apart than 5 map units
// are merged greedily in sorted order, and only the three largest clusters of each map survive.
const WOWHEAD_CLUSTER_UNITS = 5;
const WOWHEAD_SPOTS_PER_MAP = 3;

async function main() {
  const args = process.argv.slice(2);
  const refresh = args.includes("--refresh");
  const outFile = argValue(args, "--out") || OUT_FILE;

  if (refresh || !fs.existsSync(CACHE_FILE)) await fetchPetopia(refresh);
  if (refresh || !fs.existsSync(WIKI_CACHE_FILE)) await fetchWiki(refresh);

  const html = fs.readFileSync(CACHE_FILE, "utf8");
  const cachedOn = fs.statSync(CACHE_FILE).mtime.toISOString().slice(0, 10);
  const wikiCachedOn = fs.statSync(WIKI_CACHE_FILE).mtime.toISOString().slice(0, 10);
  const log = createLog();

  const wiki = parseWikiZones(fs.readFileSync(WIKI_CACHE_FILE, "utf8"), log);
  const petopia = parsePetopia(html, log);
  const hpj = loadHpj(log);
  const french = loadFrenchNpcNames();
  const wowhead = loadWowhead(log);
  const model = merge(petopia, hpj, french, wiki, wowhead, log);

  const text = renderLua(model, cachedOn, wikiCachedOn);
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, text, "utf8");

  const report = renderReport(model, log, text);
  fs.writeFileSync(REPORT_FILE, report, "utf8");
  process.stdout.write(report);
  process.stdout.write(`\nwrote ${path.relative(ROOT, outFile)} (${byteSize(text)})\n`);
}

function argValue(args, flag) {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : null;
}

function byteSize(text) {
  return `${(Buffer.byteLength(text, "utf8") / 1024).toFixed(1)} KB`;
}

async function fetchPetopia(force) {
  if (!force && fs.existsSync(CACHE_FILE)) return;
  process.stdout.write(`fetching ${PETOPIA_URL}\n`);
  const res = await fetch(PETOPIA_URL, { headers: { "User-Agent": USER_AGENT } });
  if (!res.ok) throw new Error(`Petopia answered ${res.status}`);
  const body = await res.text();
  fs.mkdirSync(path.dirname(CACHE_FILE), { recursive: true });
  fs.writeFileSync(CACHE_FILE, body, "utf8");
}

// The zone page is cached as the raw API JSON: the wikitext is what carries the bar colours and
// the legend, and it is a sixth of the rendered HTML. Identity encoding: Bun's fetch comes back
// empty on this host's compressed responses.
async function fetchWiki(force) {
  if (!force && fs.existsSync(WIKI_CACHE_FILE)) return;
  process.stdout.write(`fetching ${WIKI_URL}\n`);
  const res = await fetch(WIKI_URL, { headers: { "User-Agent": USER_AGENT, "Accept-Encoding": "identity" } });
  if (!res.ok) throw new Error(`warcraft.wiki.gg answered ${res.status}`);
  const body = await res.text();
  if (!body.trim()) throw new Error("warcraft.wiki.gg answered an empty body");
  fs.mkdirSync(path.dirname(WIKI_CACHE_FILE), { recursive: true });
  fs.writeFileSync(WIKI_CACHE_FILE, body, "utf8");
}

/* ------------------------------------------------------------------ log */

function createLog() {
  return {
    petopiaAbilities: 0,
    petopiaRanks: 0,
    petopiaTeacherLinks: 0,
    wowheadNpcs: 0,
    wowheadWithSpots: 0,
    wowheadNoSpawns: [],
    wowheadSpotsMerged: [],
    wowheadPoints: 0,
    wowheadSpotsRefused: [],
    wowheadNameMismatches: [],
    wowheadZonesAdded: [],
    wowheadZonesWithoutName: [],
    wowheadTeachAgreements: [],
    wowheadTeachDisagreements: [],
    wikiZoneRows: 0,
    wikiLegend: [],
    unknownZoneColors: [],
    zonesWithoutWikiFaction: [],
    wikiZonesWithoutMap: [],
    ranksWithoutSpell: [],
    teacherGaps: [],
    teacherDisagreements: [],
    hpjOnlyTeachers: [],
    petopiaTeachersMissingFromHpj: [],
    teachersWithoutCoords: [],
    levelMismatches: [],
    tpMismatches: [],
    familyMismatches: [],
    unknownHpjSpells: [],
    rankCountMismatches: [],
    oddLines: [],
  };
}

/* -------------------------------------------------------------- parsing */

// Decodes the handful of HTML entities the page could contain, strips tags, collapses spaces.
function cleanText(html) {
  return html
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0*39;|&apos;/g, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(Number(dec)))
    .replace(/\s+/g, " ")
    .trim();
}

// "ability_druid_ferociousbite" -> "Ability_Druid_Ferociousbite" (texture paths are case-insensitive).
function iconPath(petopiaSrc) {
  const base = petopiaSrc.split("/").pop().replace(/\.png$/i, "");
  const name = base
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join("_");
  return `Interface\\Icons\\${name}`;
}

function parsePetopia(html, log) {
  const headingRe = /<h3 class='guide_heading[^']*' id='([^']+)'>(.*?)<\/h3>/g;
  const headings = [...html.matchAll(headingRe)];
  const abilities = [];

  for (let i = 0; i < headings.length; i++) {
    const heading = headings[i];
    const blockEnd = i + 1 < headings.length ? headings[i + 1].index : html.length;
    const block = html.slice(heading.index, blockEnd);
    const familyList = block.match(/<span class='ability_family_list(?: classic forever)?'>([\s\S]*?)<\/span>/);

    const ability = {
      key: heading[1].replace(/[^a-z0-9]/g, ""),
      en: cleanText(heading[2]),
      icon: iconPath((heading[2].match(/src='([^']+)'/) || [, ""])[1]),
      families: [],
      allFamilies: false,
      ranks: [],
    };

    if (familyList) {
      const text = familyList[1];
      if (/All Families/.test(text)) {
        ability.allFamilies = true;
      } else {
        for (const m of text.matchAll(/family\.php\?id=([a-z]+)/g)) {
          const name = FAMILY_SLUGS[m[1]];
          if (name && !ability.families.includes(name)) ability.families.push(name);
        }
      }
    }

    for (const rank of parseRanks(block, log)) ability.ranks.push(rank);

    log.petopiaAbilities++;
    log.petopiaRanks += ability.ranks.length;
    abilities.push(ability);
  }
  return abilities;
}

function parseRanks(block, log) {
  const rankStartRe = /<li id='[^']+' class='abilityrank[^']*'>/g;
  const starts = [...block.matchAll(rankStartRe)];
  const ranks = [];

  for (let i = 0; i < starts.length; i++) {
    const chunk = block.slice(starts[i].index, i + 1 < starts.length ? starts[i + 1].index : block.length);
    const name = cleanText((chunk.match(/abilityrankname[^']*'>([\s\S]*?)<\/span>/) || [, ""])[1]);
    const levelCost = chunk.match(/Pet Level (\d+), Cost (\d+) TP\./);
    const descStart = chunk.search(/abilityrankdesc[^']*'>/);
    let desc = null;
    if (descStart >= 0) {
      const from = chunk.indexOf(">", descStart) + 1;
      const to = chunk.indexOf("<span class='abilitysourceheading", from);
      desc = cleanText(chunk.slice(from, to < 0 ? chunk.length : to))
        .replace(/\s*\.$/, "")
        .trim();
    }

    const sources = [...chunk.matchAll(/<span class='abilitysourceheading[^']*'>([\s\S]*?)<\/span>/g)].map((m) =>
      cleanText(m[1])
    );

    const teachers = [];
    for (const npc of chunk.matchAll(/<a class='npclink[^']*' href='[^']*npc=(\d+)'>([\s\S]*?)<\/a>\s*\(([\s\S]*?)\)<\/li>/g)) {
      const id = Number(npc[1]);
      if (teachers.some((t) => t.id === id)) continue;
      const spec = npc[3];
      const parts = spec.split(", ");
      if (parts.length < 3) {
        log.oddLines.push(`npc ${id}: (${spec})`);
        continue;
      }
      const levels = parseLevels(parts[1]);
      teachers.push({
        id,
        en: cleanText(npc[2]),
        family: parts[0],
        min: levels.min,
        max: levels.max,
        zones: parts.slice(2).join(", ").split("; ").map((z) => z.trim()),
      });
    }
    log.petopiaTeacherLinks += teachers.length;

    const rankNumber = Number((name.match(/(\d+)\s*$/) || [, ""])[1]);
    ranks.push({
      rank: Number.isFinite(rankNumber) ? rankNumber : ranks.length + 1,
      en: name,
      petLevel: levelCost ? Number(levelCost[1]) : null,
      tp: levelCost ? Number(levelCost[2]) : null,
      desc,
      trainer: sources.some((s) => /trainers/i.test(s)),
      noSource: sources.length > 0 && sources.every((s) => s === DANGLING_SOURCE),
      teachers,
    });
  }
  return ranks;
}

function parseLevels(text) {
  const m = text.match(/^(\d+)(?:\s*-\s*(\d+))?$/);
  if (!m) return { min: null, max: null };
  return { min: Number(m[1]), max: Number(m[2] || m[1]) };
}

/* ------------------------------------------------ warcraft.wiki.gg zones */

// The colours are named by the page's own legend, so it decides what they mean. Only the two
// territory colours give a faction: contested and combat zones stay nil, otherwise the "my
// faction" filter would hide zones that are open to both sides.
const TERRITORY_FACTIONS = {
  "Alliance territory": "Alliance",
  "Horde territory": "Horde",
};

function parseWikiZones(cached, log) {
  let wikitext;
  try {
    wikitext = JSON.parse(cached).parse.wikitext["*"];
  } catch (error) {
    throw new Error(`warcraft.wiki.gg cache is not the parse API response: ${error.message}`);
  }

  const legend = new Map();
  for (const m of wikitext.matchAll(/background-color:#([0-9A-Fa-f]{6})[^>]*>([^<]+)<\/span>/g)) {
    legend.set(m[1].toUpperCase(), cleanText(m[2]));
  }
  log.wikiLegend = [...legend.entries()].map(([color, territory]) => `${color} ${territory}`);

  const rows = [];
  for (const line of wikitext.split(/\r?\n/)) {
    if (!line.startsWith("{{Zone level|")) continue;
    const link = line.match(/\[\[([^\]|]+)(?:\|([^\]]*))?\]\]/);
    if (!link) {
      log.oddLines.push(`wiki zone row without a link: ${line.slice(0, 60)}`);
      continue;
    }
    const name = cleanText(link[2] || link[1]);
    const color = String(line.slice("{{Zone level|".length).split("|")[2] || "").toUpperCase();
    const territory = legend.get(color);
    if (!territory) log.unknownZoneColors.push(`${name} (${color || "no colour"})`);
    rows.push({ en: name, faction: TERRITORY_FACTIONS[territory] || null });
  }
  log.wikiZoneRows = rows.length;
  return rows;
}

// "Barrens" on the wiki and "The Barrens" in HunterPetJournal are the same zone.
function zoneKey(name) {
  return normalize(String(name).replace(/^the\s+/i, ""));
}

/* ------------------------------------------------------- HunterPetJournal */

function loadHpj(log) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  lua.lua_newtable(L);
  lua.lua_pushvalue(L, -1);
  lua.lua_setglobal(L, to_luastring("HPJ"));

  for (const file of ["Abilities.lua", "Beasts.lua", "Families.lua"]) {
    const full = path.join(HPJ_DIR, file);
    const code = fs.readFileSync(full, "utf8");
    if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(file)) !== lua.LUA_OK) {
      throw new Error(`${file}: ${lua.lua_tojsstring(L, -1)}`);
    }
    lua.lua_pushstring(L, to_luastring("AtlasDeChasse"));
    lua.lua_getglobal(L, to_luastring("HPJ"));
    if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) throw new Error(`${file}: ${lua.lua_tojsstring(L, -1)}`);
  }

  const bridge = `
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
    return enc({ abilities = HPJ.Abilities, beasts = HPJ.Beasts, families = HPJ.Families })
  `;
  if (lauxlib.luaL_loadbuffer(L, to_luastring(bridge), null, to_luastring("bridge")) !== lua.LUA_OK) {
    throw new Error(`bridge: ${lua.lua_tojsstring(L, -1)}`);
  }
  if (lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) throw new Error(`bridge: ${lua.lua_tojsstring(L, -1)}`);
  const json = lua.lua_tojsstring(L, -1);
  lua.lua_close(L);

  const data = JSON.parse(json);
  if (!data.abilities || !data.beasts || !data.families) {
    log.oddLines.push("HunterPetJournal data is missing a table");
  }
  return data;
}

/* --------------------------------------------- French names (Polestar) */

function decodePercent(name) {
  const bytes = [];
  for (let i = 0; i < name.length; i++) {
    if (name[i] === "%" && /^[0-9A-Fa-f]{2}$/.test(name.slice(i + 1, i + 3))) {
      bytes.push(Buffer.from([parseInt(name.slice(i + 1, i + 3), 16)]));
      i += 2;
    } else {
      bytes.push(Buffer.from(name[i], "utf8"));
    }
  }
  return Buffer.concat(bytes).toString("utf8");
}

function loadFrenchNpcNames() {
  const text = fs.readFileSync(POLESTAR_NAMES, "utf8");
  const names = new Map();
  for (const chunk of text.matchAll(/R\("npc",\s*\d+,\s*\d+,\s*\[\[([\s\S]*?)\]\]\)/g)) {
    for (const line of chunk[1].split(/\r?\n/)) {
      const tab = line.indexOf("\t");
      if (tab <= 0) continue;
      const id = Number(line.slice(0, tab));
      if (!Number.isInteger(id)) continue;
      const name = decodePercent(line.slice(tab + 1)).trim();
      if (name) names.set(id, name);
    }
  }
  return names;
}

/* ------------------------------------------------ Wowhead NPC spawn data */

// Hand-read from wowhead.com/forever/npc=<id> in a real browser: the site serves a bot check to
// scripts, so the file is a cache like the others and is never fetched or written here.
function loadWowhead(log) {
  if (!fs.existsSync(WOWHEAD_CACHE_FILE)) {
    log.oddLines.push("tools/cache/wowhead-npcs.json is missing, no Wowhead spawn point merged");
    return new Map();
  }
  const data = JSON.parse(fs.readFileSync(WOWHEAD_CACHE_FILE, "utf8"));
  const npcs = new Map();
  for (const [id, npc] of Object.entries(data.npcs || {})) {
    npcs.set(Number(id), npc);
    if (listOf(npc.spots).length > 0) log.wowheadWithSpots++;
  }
  log.wowheadNpcs = npcs.size;
  return npcs;
}

// Wowhead's per-zone spawn points reduced to at most WOWHEAD_SPOTS_PER_MAP cluster centres,
// rounded to 0.1 like HunterPetJournal's coordinates. Sorted by map then position so the output
// never depends on the order the points appear in the cache.
function wowheadSpots(npc) {
  const pointsByMap = new Map();
  for (const area of listOf(npc.spots)) {
    const map = Number(area.map);
    if (!Number.isInteger(map) || map <= 0) continue;
    if (!pointsByMap.has(map)) pointsByMap.set(map, { name: area.name || null, points: [] });
    const { points } = pointsByMap.get(map);
    for (const pair of listOf(area.coords)) {
      const x = Number(pair[0]);
      const y = Number(pair[1]);
      if (Number.isFinite(x) && Number.isFinite(y)) points.push([x, y]);
    }
  }

  const spots = [];
  for (const map of [...pointsByMap.keys()].sort((a, b) => a - b)) {
    const { name, points } = pointsByMap.get(map);
    const clusters = [];
    for (const [x, y] of points.sort((a, b) => a[0] - b[0] || a[1] - b[1])) {
      const near = clusters.find((c) => Math.hypot(c.x / c.n - x, c.y / c.n - y) <= WOWHEAD_CLUSTER_UNITS);
      if (!near) {
        clusters.push({ x, y, n: 1 });
        continue;
      }
      near.x += x;
      near.y += y;
      near.n++;
    }
    clusters.sort((a, b) => b.n - a.n || a.x / a.n - b.x / b.n || a.y / a.n - b.y / b.n);
    for (const cluster of clusters.slice(0, WOWHEAD_SPOTS_PER_MAP)) {
      spots.push({ map, name, x: round1(cluster.x / cluster.n), y: round1(cluster.y / cluster.n) });
    }
  }
  return spots.sort((a, b) => a.map - b.map || a.x - b.x || a.y - b.y);
}

function round1(value) {
  return Math.round(value * 10) / 10;
}

// Wowhead only gives uiMapIDs. A map no HunterPetJournal beast stands on is missing from ns.zones,
// so it is added when the cache names it; without a name the spot is dropped rather than pointing
// at a zone the addon cannot draw.
function knownZone(zones, spot, log) {
  if (zones.has(spot.map)) return true;
  if (spot.name) {
    zones.set(spot.map, { en: spot.name, faction: null, dungeon: false });
    log.wowheadZonesAdded.push(`${spot.map} ${spot.name}`);
    return true;
  }
  if (!log.wowheadZonesWithoutName.includes(String(spot.map))) log.wowheadZonesWithoutName.push(String(spot.map));
  return false;
}

/* --------------------------------------------------------------- merging */

function merge(petopia, hpj, french, wiki, wowhead, log) {
  const hpjAbilities = new Map();
  for (const ability of Object.values(hpj.abilities)) {
    if (!ability || !ability.en) continue;
    hpjAbilities.set(normalize(ability.en), ability);
  }

  const familyByName = new Map();
  for (const [id, family] of Object.entries(hpj.families)) familyByName.set(normalize(family.en), Number(id));

  // spell id -> { ability, rank }
  const rankBySpell = new Map();

  const abilities = petopia.map((ability) => {
    const hpjAbility = hpjAbilities.get(normalize(ability.en)) || null;
    const hpjRanks = hpjAbility && hpjAbility.ranks ? hpjAbility.ranks : [];
    if (hpjAbility && hpjRanks.length !== ability.ranks.length) {
      log.rankCountMismatches.push(`${ability.en}: Petopia ${ability.ranks.length} ranks, HPJ ${hpjRanks.length}`);
    }

    const ranks = ability.ranks.map((rank) => {
      const hpjRank = hpjRanks[rank.rank - 1];
      const hpjSpell = hpjRank ? Number(at(hpjRank, 1)) : null;
      const hpjLevel = hpjRank ? at(hpjRank, 2) : null;
      const hpjTp = hpjRank ? at(hpjRank, 3) : null;
      const spell = Number.isInteger(hpjSpell) && hpjSpell > 0 ? hpjSpell : null;
      if (spell === null) log.ranksWithoutSpell.push(`${ability.en} ${rank.rank}`);
      else rankBySpell.set(spell, { ability: ability.en, rank: rank.rank });
      if (hpjRank) {
        if (hpjLevel !== undefined && hpjLevel !== null && rank.petLevel !== null && hpjLevel !== rank.petLevel) {
          log.levelMismatches.push(`${ability.en} ${rank.rank}: Petopia level ${rank.petLevel}, HPJ ${hpjLevel}`);
        }
        if (hpjTp !== undefined && hpjTp !== null && rank.tp !== null && hpjTp !== rank.tp) {
          log.tpMismatches.push(`${ability.en} ${rank.rank}: Petopia ${rank.tp} TP, HPJ ${hpjTp}`);
        }
      }
      return {
        rank: rank.rank,
        spell,
        petLevel: rank.petLevel,
        tp: rank.tp,
        desc: rank.desc,
        teachers: rank.teachers,
        trainer: rank.trainer,
        noSource: rank.noSource,
      };
    });

    const hasBeast = ranks.some((r) => r.teachers.length > 0);
    const hasTrainer = ranks.some((r) => r.trainer);
    const src = hasBeast && hasTrainer ? "both" : hasTrainer ? "trainer" : "beast";
    const families = ability.allFamilies
      ? "all"
      : ability.families
          .map((name) => familyByName.get(normalize(name)))
          .filter((id) => id !== undefined)
          .sort((a, b) => a - b);

    return {
      key: ability.key,
      en: ability.en,
      icon: ability.icon,
      src,
      families,
      roman: false,
      ranks,
    };
  });

  // Client-verified ranks for abilities the two sources do not carry.
  for (const verified of CLIENT_VERIFIED_ABILITIES) {
    const existing = abilities.find((a) => normalize(a.en) === normalize(verified.en));
    const ranks = verified.ranks
      .map((rank) => ({
        rank: rank.rank,
        spell: rank.spell,
        petLevel: rank.petLevel,
        tp: rank.tp,
        desc: rank.desc,
        teachers: [],
        trainer: false,
        noSource: false,
      }))
      .sort((a, b) => a.rank - b.rank);

    if (existing) {
      if (!ranks.some((r) => r.spell === existing.ranks.find((e) => e.rank === r.rank)?.spell)) {
        log.oddLines.push(`${verified.en}: client-verified rank missing from Petopia data`);
      }
      existing.roman = existing.roman || Boolean(verified.roman);
      continue;
    }

    for (const rank of ranks) rankBySpell.set(rank.spell, { ability: verified.en, rank: rank.rank });
    abilities.push({
      key: verified.key,
      en: verified.en,
      icon: verified.icon || null,
      src: verified.src,
      families: verified.families,
      roman: Boolean(verified.roman),
      ranks,
      clientVerified: true,
    });
  }

  abilities.sort((a, b) => (a.en < b.en ? -1 : a.en > b.en ? 1 : 0));

  // Teachers: Petopia decides who teaches a rank; HunterPetJournal adds the beasts it knows
  // that Petopia does not list, using the spell ids each beast learns.
  const teachers = new Map(); // npc id -> { petopia: {...}|null, hpj: ranked spells }
  const addTeacher = (id, info) => {
    if (!teachers.has(id)) teachers.set(id, { petopia: null, spells: new Set() });
    const entry = teachers.get(id);
    if (info) entry.petopia = entry.petopia || info;
    return entry;
  };

  for (const ability of abilities) {
    for (const rank of ability.ranks) {
      for (const npc of rank.teachers) addTeacher(npc.id, npc);
    }
  }

  for (const [id, beast] of sortedById(hpj.beasts)) {
    for (const spell of listOf(beast.t)) {
      const target = rankBySpell.get(Number(spell));
      if (!target) {
        log.unknownHpjSpells.push(`npc ${id} (${beast.en}) teaches ${spell}`);
        continue;
      }
      addTeacher(Number(id), null).spells.add(Number(spell));
    }
  }

  // Cross-check Petopia's teacher lists against HunterPetJournal's "teaches" lists.
  for (const ability of abilities) {
    for (const rank of ability.ranks) {
      for (const npc of rank.teachers) {
        const beast = hpj.beasts[npc.id];
        if (!beast) {
          log.petopiaTeachersMissingFromHpj.push(`npc ${npc.id} ${npc.en} (${ability.en} ${rank.rank})`);
          continue;
        }
        const known = (beast.t || []).map(Number);
        if (rank.spell !== null && !known.includes(rank.spell)) {
          const line = `${npc.en} (${npc.id}): Petopia says ${ability.en} ${rank.rank} (${rank.spell}), HPJ ${
            known.length === 0 ? "lists no taught spell" : `teaches [${known.join(", ")}]`
          }`;
          if (known.length === 0) log.teacherGaps.push(line);
          else log.teacherDisagreements.push(line);
        }
      }
    }
  }

  // HunterPetJournal-only teachers: added for abilities Petopia does not credit that beast with
  // at all. When Petopia lists the beast for another rank of the same ability, Petopia wins and
  // the HunterPetJournal claim is only reported (see "teacher disagreements" in the build log).
  const petopiaPairs = new Set();
  for (const ability of abilities) {
    for (const rank of ability.ranks) {
      for (const npc of rank.teachers) petopiaPairs.add(`${npc.id}:${ability.en}`);
    }
  }

  for (const [id, entry] of teachers) {
    for (const spell of entry.spells) {
      const target = rankBySpell.get(spell);
      if (!target) continue;
      const ability = abilities.find((a) => a.en === target.ability);
      if (petopiaPairs.has(`${id}:${ability.en}`)) continue;
      const rank = ability.ranks.find((r) => r.spell === spell);
      if (rank.teachers.some((t) => t.id === id)) continue;
      const beast = hpj.beasts[id];
      rank.teachers.push({ id, en: beast.en, family: null, min: null, max: null, zones: [], fromHpj: true });
      log.hpjOnlyTeachers.push(`${beast.en} (${id}) teaches ${ability.en} ${rank.rank} (${spell})`);
    }
  }

  // Zones: uiMapID -> name, taken from HunterPetJournal spot records. A map id can appear
  // under several zone names (subzones share the parent's map), so the most frequent name wins.
  const zoneNames = new Map();
  for (const [, beast] of sortedById(hpj.beasts)) {
    for (const spot of listOf(beast.z)) {
      const name = at(spot, 1);
      const map = Number(at(spot, 5));
      if (!name || !Number.isInteger(map) || map <= 0) continue;
      if (!zoneNames.has(map)) zoneNames.set(map, new Map());
      const names = zoneNames.get(map);
      names.set(name, (names.get(name) || 0) + 1);
    }
  }
  const zones = new Map();
  for (const [map, names] of [...zoneNames.entries()].sort((a, b) => a[0] - b[0])) {
    const best = [...names.entries()].sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))[0];
    zones.set(map, { en: best[0], faction: null, dungeon: false });
  }

  // Beasts: only the ones referenced as teachers.
  const beasts = new Map();
  for (const id of [...teachers.keys()].sort((a, b) => a - b)) {
    const entry = teachers.get(id);
    const hpjBeast = hpj.beasts[id] || null;
    const seen = entry.petopia;
    const petopiaFamily = seen ? familyByName.get(normalize(seen.family)) ?? null : null;

    const record = {
      en: hpjBeast?.en || seen?.en || `NPC ${id}`,
      fr: french.get(id) || null,
      family: hpjBeast?.f ? Number(hpjBeast.f) : petopiaFamily,
      minLevel: null,
      maxLevel: null,
      rare: false,
      elite: false,
      tame: hpjBeast?.tame || "T",
      src: seen ? "petopia" : "hpj",
      zoneEn: null,
      dungeonZone: null,
      spots: [],
    };

    if (hpjBeast && petopiaFamily !== null && record.family !== petopiaFamily) {
      log.familyMismatches.push(`${seen.en} (${id}): Petopia ${seen.family} (${petopiaFamily}), HPJ ${record.family}`);
    }

    if (hpjBeast) {
      const hpjLevels = parseLevels(String(hpjBeast.l || ""));
      record.minLevel = hpjLevels.min;
      record.maxLevel = hpjLevels.max;
      record.rare = String(hpjBeast.q || "").includes("R");
      record.elite = String(hpjBeast.q || "").includes("E");
      for (const spot of listOf(hpjBeast.z)) {
        const map = Number(at(spot, 5));
        if (!Number.isInteger(map) || map <= 0) {
          const zoneName = at(spot, 1);
          if (zoneName && !record.dungeonZone) record.dungeonZone = stripInstanceSuffix(zoneName);
          continue;
        }
        if (!record.zoneEn) record.zoneEn = at(spot, 1);
        const x = Number(at(spot, 2));
        const y = Number(at(spot, 3));
        if (Number.isFinite(x) && Number.isFinite(y)) record.spots.push({ map, x, y });
      }
    } else if (seen) {
      record.minLevel = seen.min;
      record.maxLevel = seen.max;
    }

    // Petopia fills what HunterPetJournal leaves empty (the Forever-only NPCs it does not carry).
    if (seen) {
      if (record.minLevel === null && seen.min !== null) {
        record.minLevel = seen.min;
        record.maxLevel = seen.max;
      }
      for (const zone of seen.zones) {
        const dungeon = instanceOf(zone);
        if (dungeon) {
          if (!record.dungeonZone) record.dungeonZone = dungeon;
        } else if (!record.zoneEn) {
          record.zoneEn = zone;
        }
      }
    }

    // Wowhead is the last resort for spawn points: Petopia and HunterPetJournal name a zone but
    // place nothing there for these beasts, so a hunter had no dot to walk to. It never overrides
    // a source that already placed the beast.
    const npc = wowhead.get(id);
    if (npc) {
      if (npc.name && normalize(npc.name) !== normalize(record.en)) {
        log.wowheadNameMismatches.push(`${id}: Wowhead ${npc.name}, our data ${record.en}`);
      }
      if (npc.found === false) {
        log.wowheadNoSpawns.push(`${record.en} (${id})`);
      } else if (record.spots.length === 0) {
        const spots = wowheadSpots(npc).filter((spot) => knownZone(zones, spot, log));
        if (spots.length > 0) {
          record.spots = spots;
          record.spotsSrc = "wowhead";
          log.wowheadPoints += listOf(npc.spots).reduce((sum, area) => sum + listOf(area.coords).length, 0);
          log.wowheadSpotsMerged.push(
            `${record.en} (${id}): ${spots.map((spot) => `${spot.map} ${spot.x}/${spot.y}`).join(", ")}`
          );
        }
      } else if (listOf(npc.spots).length > 0) {
        log.wowheadSpotsRefused.push(`${record.en} (${id}) keeps its own spots`);
      }
    }

    record.spots.sort((a, b) => a.map - b.map || a.x - b.x || a.y - b.y);
    if (!record.zoneEn && record.spots.length > 0) record.zoneEn = zones.get(record.spots[0].map)?.en || null;
    if (record.spots.length === 0) log.teachersWithoutCoords.push(`${record.en} (${id})`);

    beasts.set(id, record);
  }

  // Zone faction from warcraft.wiki.gg, once every zone is known: HunterPetJournal's maps plus the
  // ones Wowhead introduced. Zones the page does not list (capital cities, battlegrounds,
  // Forever-only zones) keep faction = nil, as do contested zones.
  const wikiByKey = new Map();
  for (const row of wiki) if (!wikiByKey.has(zoneKey(row.en))) wikiByKey.set(zoneKey(row.en), row);
  const matchedWiki = new Set();
  for (const [map, zone] of zones) {
    const row = wikiByKey.get(zoneKey(zone.en));
    if (!row) {
      log.zonesWithoutWikiFaction.push(`${map} ${zone.en}`);
      continue;
    }
    matchedWiki.add(zoneKey(zone.en));
    zone.faction = row.faction;
  }
  for (const row of wiki) {
    if (!matchedWiki.has(zoneKey(row.en))) log.wikiZonesWithoutMap.push(row.en);
  }

  // Wowhead's "teaches" list is a third opinion on which rank a beast carries. Petopia stays the
  // source of the teacher lists, so this only feeds the report: a disagreement means one of the
  // two pages credits the beast with a rank the other does not.
  const petopiaRanks = new Map();
  for (const ability of abilities) {
    for (const rank of ability.ranks) {
      for (const npc of rank.teachers) {
        if (npc.fromHpj) continue;
        if (!petopiaRanks.has(npc.id)) petopiaRanks.set(npc.id, new Set());
        petopiaRanks.get(npc.id).add(`${ability.en} ${rank.rank}`);
      }
    }
  }

  for (const [id, npc] of [...wowhead.entries()].sort((a, b) => a[0] - b[0])) {
    const name = beasts.get(id)?.en || npc.name || `NPC ${id}`;
    const credited = petopiaRanks.get(id) || new Set();
    for (const teaches of listOf(npc.teaches)) {
      const spell = Number(teaches[0]);
      const target = rankBySpell.get(spell);
      const ours = target ? `${target.ability} ${target.rank}` : null;
      const says = `${teaches[1]} ${String(teaches[2]).replace(/^Rank\s*/, "")}`;
      if (ours && normalize(says) === normalize(ours) && credited.has(ours)) {
        log.wowheadTeachAgreements.push(`${name} (${id}): ${ours} (${spell})`);
        continue;
      }
      log.wowheadTeachDisagreements.push(
        `${name} (${id}): Wowhead says ${says} (${spell}), that spell maps to ${
          ours || "no rank here"
        }, Petopia credits ${[...credited].sort().join(", ") || "no rank"}`
      );
    }
  }

  // Teachers sorted by the level a hunter can tame them at, then by id.
  for (const ability of abilities) {
    for (const rank of ability.ranks) {
      rank.teachers = rank.teachers
        .map((t) => t.id)
        .filter((id, i, all) => all.indexOf(id) === i)
        .sort((a, b) => (beasts.get(a).minLevel ?? 999) - (beasts.get(b).minLevel ?? 999) || a - b);
    }
  }

  const families = Object.entries(hpj.families)
    .map(([id, family]) => ({ id: Number(id), en: family.en, iconId: family.icon ?? null }))
    .sort((a, b) => a.id - b.id);

  return { families, zones, abilities, beasts };
}

function normalize(text) {
  return String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
}

// Lua sequences cross the fengari bridge either as 0-based arrays or, when the table also
// carries named keys (v = true, lv = true), as objects keyed by the 1-based Lua index.
function at(sequence, index) {
  if (!sequence) return undefined;
  return Array.isArray(sequence) ? sequence[index - 1] : sequence[String(index)];
}

function listOf(sequence) {
  if (!sequence) return [];
  return Array.isArray(sequence) ? sequence : Object.values(sequence);
}

function sortedById(object) {
  return Object.entries(object).sort((a, b) => Number(a[0]) - Number(b[0]));
}

// "Blackfathom Deeps (Dungeon)" -> "Blackfathom Deeps"; null when not an instance.
function instanceOf(zone) {
  const m = String(zone).match(/^(.*?)\s*\((Dungeon|Raid)\)$/i);
  return m ? m[1] : null;
}

function stripInstanceSuffix(zone) {
  return instanceOf(zone) || zone;
}

/* --------------------------------------------------------------- writing */

function luaString(value) {
  return (
    '"' +
    String(value)
      .replace(/\\/g, "\\\\")
      .replace(/"/g, '\\"')
      .replace(/\n/g, "\\n")
      .replace(/\r/g, "\\r")
      .replace(/\t/g, "\\t") +
    '"'
  );
}

function luaNumber(value) {
  if (!Number.isFinite(value)) return "nil";
  return Number.isInteger(value) ? String(value) : String(Number(value.toFixed(4)));
}

function luaValue(value) {
  if (value === null || value === undefined) return "nil";
  if (typeof value === "number") return luaNumber(value);
  if (typeof value === "boolean") return value ? "true" : "false";
  return luaString(value);
}

function luaFields(pairs) {
  return pairs
    .filter(([, value]) => value !== null && value !== undefined)
    .map(([key, value]) => `${key} = ${luaValue(value)}`)
    .join(", ");
}

function renderLua(model, cachedOn, wikiCachedOn) {
  const out = [];
  out.push(
    "-- AtlasDeChasse static data. Do not edit by hand.",
    `-- Generated by tools/build-data.js on ${cachedOn} from tools/cache/petopia-abilities.html`,
    "-- (Petopia Forever abilities.php, fetched once), HunterPetJournal data (spell ids, families,",
    "-- coordinates, uiMapID), Polestar_frFR NPC names, warcraft.wiki.gg",
    `-- (Zones by level (original) wikitext, cached ${wikiCachedOn}), for zone factions, and`,
    "-- Wowhead NPC pages (spawn points of the open-world teachers HunterPetJournal omits).",
    "--",
    "-- Conventions:",
    "--   src = \"beast\" when the ability is learned by taming a beast, \"trainer\" when a pet",
    "--         trainer teaches it, \"both\" when both apply.",
    "--   families = \"all\" for general abilities, else a list of family ids.",
    "--   family icon is the client texture name; it is nil for Fox and Core Hound, which have",
    "--          no family icon, so fall back to iconId (always set) for those two.",
    "--   teachers = npc ids from ns.beasts, sorted by the level they can be tamed at.",
    "--   zoneEn is the open world zone HunterPetJournal lists first, nil for dungeon-only",
    "--          beasts (their instance name is in dungeonZone).",
    "--   spots are map/x/y points: one per zone from HunterPetJournal, and up to three cluster",
    "--          centres per zone from Wowhead for the open-world teachers it does not place.",
    "--          spotsSrc = \"wowhead\" marks the beasts whose spots come from there.",
    "--   zone faction is \"Alliance\" or \"Horde\" from warcraft.wiki.gg's bar colours; nil for",
    "--          contested and combat zones, and for zones the page does not list.",
    "--   Faster Attack is built from ranks read off the live client only; its other ranks",
    "--          and teachers are unknown, so its rank list is incomplete by design.",
    "local _, ns = ...",
    ""
  );

  out.push("ns.families = {");
  for (const family of model.families) {
    const icon = FAMILIES_WITHOUT_ICON.has(family.en)
      ? null
      : `Interface\\Icons\\${FAMILY_ICON_NAMES[family.en] || `Ability_Hunter_Pet_${family.en.replace(/\s/g, "")}`}`;
    out.push(`  [${family.id}] = { ${luaFields([["en", family.en], ["icon", icon], ["iconId", family.iconId]])} },`);
  }
  out.push("}", "");

  out.push("ns.zones = {");
  for (const [id, zone] of [...model.zones.entries()].sort((a, b) => a[0] - b[0])) {
    out.push(`  [${id}] = { ${luaFields([["en", zone.en], ["faction", zone.faction], ["dungeon", false]])} },`);
  }
  out.push("}", "");

  out.push("ns.abilities = {");
  for (const ability of model.abilities) {
    const head = luaFields([
      ["key", ability.key],
      ["en", ability.en],
      ["icon", ability.icon],
      ["src", ability.src],
    ]);
    const families = ability.families === "all" ? '"all"' : `{ ${ability.families.join(", ")} }`;
    const roman = ability.roman ? ", roman = true" : "";
    out.push(`  { ${head},`);
    out.push(`    families = ${families}${roman},`);
    out.push("    ranks = {");
    for (const rank of ability.ranks) {
      const fields = luaFields([
        ["rank", rank.rank],
        ["spell", rank.spell],
        ["petLevel", rank.petLevel],
        ["tp", rank.tp],
        ["desc", rank.desc],
      ]);
      out.push(`      { ${fields}, teachers = { ${rank.teachers.join(", ")} } },`);
    }
    out.push("    } },");
  }
  out.push("}", "");

  out.push("ns.beasts = {");
  for (const [id, beast] of [...model.beasts.entries()].sort((a, b) => a[0] - b[0])) {
    const head = luaFields([
      ["en", beast.en],
      ["fr", beast.fr],
      ["family", beast.family],
      ["minLevel", beast.minLevel],
      ["maxLevel", beast.maxLevel],
      ["rare", beast.rare],
      ["elite", beast.elite],
      ["tame", beast.tame],
      ["src", beast.src],
      ["zoneEn", beast.zoneEn],
      ["dungeonZone", beast.dungeonZone],
      ["spotsSrc", beast.spotsSrc],
    ]);
    const spots = beast.spots.map((s) => `{ ${luaFields([["map", s.map], ["x", s.x], ["y", s.y]])} }`);
    out.push(`  [${id}] = { ${head}, spots = { ${spots.join(", ")} } },`);
  }
  out.push("}");
  return out.join("\n") + "\n";
}

/* ---------------------------------------------------------------- report */

function renderReport(model, log, luaText) {
  const rankCount = model.abilities.reduce((sum, a) => sum + a.ranks.length, 0);
  const spellCount = model.abilities.reduce((sum, a) => sum + a.ranks.filter((r) => r.spell !== null).length, 0);
  const teacherCount = model.abilities.reduce(
    (sum, a) => sum + a.ranks.reduce((s, r) => s + r.teachers.length, 0),
    0
  );
  const spotCount = [...model.beasts.values()].reduce((sum, b) => sum + b.spots.length, 0);
  const frCount = [...model.beasts.values()].filter((b) => b.fr).length;

  const beastList = [...model.beasts.values()];
  const fromWowhead = beastList.filter((b) => b.spotsSrc === "wowhead");
  const openWithout = beastList.filter((b) => b.spots.length === 0 && !b.dungeonZone).length;
  const dungeonWithout = beastList.filter((b) => b.spots.length === 0 && b.dungeonZone).length;
  const openBefore = openWithout + fromWowhead.filter((b) => !b.dungeonZone).length;

  const lines = [];
  lines.push("AtlasDeChasse build report");
  lines.push("");
  lines.push("Inputs");
  lines.push(`  Petopia abilities : ${log.petopiaAbilities}`);
  lines.push(`  Petopia ranks     : ${log.petopiaRanks}`);
  lines.push(`  Petopia teacher links: ${log.petopiaTeacherLinks}`);
  lines.push(`  warcraft.wiki.gg zone rows: ${log.wikiZoneRows}`);
  lines.push(`  Wowhead NPC pages : ${log.wowheadNpcs} (${log.wowheadWithSpots} with spawn points)`);
  lines.push(`  Enriched with ${CLIENT_VERIFIED_ABILITIES.length} client-verified ability (Faster Attack)`);
  lines.push("");
  lines.push("Output");
  lines.push(`  abilities         : ${model.abilities.length}`);
  lines.push(`  ranks             : ${rankCount} (${spellCount} with a spell id)`);
  lines.push(`  teacher entries   : ${teacherCount}`);
  lines.push(`  beasts            : ${model.beasts.size} (${frCount} with a French name)`);
  lines.push(`  spots             : ${spotCount}`);
  lines.push(`  families          : ${model.families.length}`);
  const zoneCount = (faction) => [...model.zones.values()].filter((zone) => zone.faction === faction).length;
  lines.push(
    `  zones             : ${model.zones.size} (${zoneCount("Alliance")} Alliance, ${zoneCount("Horde")} Horde, ${
      model.zones.size - zoneCount("Alliance") - zoneCount("Horde")
    } nil/contested)`
  );
  lines.push(`  Data/Data.lua     : ${byteSize(luaText)}`);
  lines.push("");
  lines.push("Coordinates");
  lines.push(
    `  open-world teachers without a spot: ${openBefore} before Wowhead, ${openWithout} after (${fromWowhead.length} placed)`
  );
  lines.push(
    `  ${log.wowheadPoints} Wowhead spawn points reduced to ${
      fromWowhead.reduce((sum, beast) => sum + beast.spots.length, 0)
    } cluster centres`
  );
  lines.push(`  dungeon-only teachers without a spot: ${dungeonWithout} (Wowhead cannot help, no open world spot)`);
  lines.push("");
  lines.push("Notes");
  lines.push(`  ${frCount} of ${model.beasts.size} teachers have a French name: Polestar_frFR/Names.lua`);
  lines.push("  only registers 500 NPC ids per chunk, the rest stay nil (the UI falls back to en).");
  lines.push(`  Zone factions come from warcraft.wiki.gg bar colours, legend: ${log.wikiLegend.join(", ")}.`);
  lines.push("  Zones the page does not list (capital cities, battlegrounds, Forever-only zones) stay nil.");
  lines.push(`  Faster Attack ships only the rank seen in the client (1263104, rank 4, Roman numerals);`);
  lines.push("  its other ranks and teachers are unknown to every source here.");
  lines.push("  Wowhead spawn points never override HunterPetJournal or Petopia; each zone keeps at most");
  lines.push(`  ${WOWHEAD_SPOTS_PER_MAP} cluster centres, merged within ${WOWHEAD_CLUSTER_UNITS} map units and rounded to 0.1.`);
  lines.push("");

  const section = (title, items, extra) => {
    lines.push(`${title}: ${items.length}${extra ? ` (${extra})` : ""}`);
    for (const item of items.slice(0, 12)) lines.push(`    ${item}`);
    if (items.length > 12) lines.push(`    ... ${items.length - 12} more`);
    lines.push("");
  };

  section("Ranks without a spell id", log.ranksWithoutSpell, "Petopia rank unknown to HunterPetJournal");
  section("Petopia teachers missing from HunterPetJournal", log.petopiaTeachersMissingFromHpj, "absent from HunterPetJournal");
  section("Petopia teachers without coordinates", log.teachersWithoutCoords, "dungeon or coordinate-less NPC");
  section("Wowhead spawn points merged", log.wowheadSpotsMerged, "spotsSrc = wowhead");
  section("Wowhead pages without spawn data", log.wowheadNoSpawns, "beast stays without coordinates");
  section("Wowhead spawn points refused", log.wowheadSpotsRefused, "HunterPetJournal or Petopia placed the beast");
  section("Wowhead teaches agreements", log.wowheadTeachAgreements, "same rank as Petopia");
  section("Wowhead teaches disagreements", log.wowheadTeachDisagreements, "Petopia wins, teachers unchanged");
  section("Wowhead names that differ from ours", log.wowheadNameMismatches, "the id may be wrong");
  section("Zones added from Wowhead spots", log.wowheadZonesAdded, "not carried by HunterPetJournal");
  section("Wowhead zones without a name", log.wowheadZonesWithoutName, "their spots are dropped");
  section("HunterPetJournal-only teachers added", log.hpjOnlyTeachers, "src = hpj");
  section("Petopia teachers HunterPetJournal does not credit", log.teacherGaps, "HPJ lists no taught spell for that beast");
  section("Petopia/HPJ teacher disagreements", log.teacherDisagreements, "Petopia wins, kept for review");
  section("Rank count mismatches", log.rankCountMismatches);
  section("Pet level mismatches", log.levelMismatches);
  section("Training point mismatches", log.tpMismatches);
  section("Family mismatches", log.familyMismatches);
  section("HunterPetJournal spells outside our rank list", log.unknownHpjSpells);
  section("Zones with no wiki row", log.zonesWithoutWikiFaction, "capital cities, battlegrounds, Forever-only zones stay nil");
  section("Wiki zones with no map here", log.wikiZonesWithoutMap, "not carried by HunterPetJournal spots");
  section("Wiki zone rows with an unknown colour", log.unknownZoneColors, "treated as contested, faction stays nil");
  section("Unparsed Petopia lines", log.oddLines);

  return lines.join("\n") + "\n";
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`build failed: ${error && error.stack ? error.stack : error}\n`);
    process.exit(1);
  });
}
