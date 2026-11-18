-- Atlas de chasse · hidden pets: beasts that only appear after a hidden step.
-- Written by hand (not generated), one record per pet, from the sources named
-- in `source`. Names the client can give (spells, items, zones) are read from
-- it at display time; the strings here are the fallback.
--
--   item    = { id, count, en, fr }: the item the hunter must carry (count to bring)
--   steps   = { en, fr } lines, in order; %ITEM% is replaced by the item's name
--   spot    = where the beast appears: { map = uiMapID, x, y } in 0-100
--   abilities = { spell, rank, en, fr } it teaches; rank is appended to the
--               client's name when the name carries none
local _, ns = ...

ns.secrets = {
  {
    key = "tashkal",
    name = { en = "Ta'shkal", fr = "Ta'shkal" },
    -- the English title is not known yet: no line on English clients
    title = { fr = "Expérience fugitive" },
    family = 2, -- Cat
    level = 57,
    zoneEn = "Mount Hyjal",
    spot = { map = 2482, x = 26.6, y = 64.9 },
    item = { id = 276909, count = 2, en = "Corrupted Cat Figurine", fr = "Figurine de chat corrompue" },
    steps = {
      {
        en = "Find a %ITEM% in the fel pools of Mount Hyjal (French guide: « Balafre Gangresang »). It has no fixed spot: search the tainted water. Bring 2: the lantern can use one up without the cat showing.",
        fr = "Trouve une %ITEM% dans les bassins gangrenés de Balafre Gangresang. Pas de point fixe : fouille l'eau gangrenée. Prends-en 2 : la lanterne peut en consommer une sans que le félin apparaisse.",
      },
      {
        en = "Leave your current pet at the stable.",
        fr = "Range ton familier actuel à l'écurie.",
      },
      {
        en = "Climb to the ledge behind the trees at 26.6 64.9 and set a Freezing Trap next to the lantern.",
        fr = "Monte sur la corniche derrière les arbres, en 26,6 64,9, et pose un Piège givrant près de la lanterne.",
      },
      {
        en = "Click the lone lantern (« Lanterne solitaire »): Ta'shkal appears at once. Tame it.",
        fr = "Clique sur la Lanterne solitaire : Ta'shkal apparaît tout de suite. Dompte-le.",
      },
    },
    abilities = {
      { spell = 16697, rank = 6, en = "Cower", fr = "Dérobade" },
      { spell = 24453, rank = 3, en = "Prowl", fr = "Rôder" },
      { spell = 1263110, en = "Faster Attack VII", fr = "Attaque rapide VII" },
    },
    source = "Mamytwink / Petopia (Zsawylde), 2026-11-18",
  },
}
