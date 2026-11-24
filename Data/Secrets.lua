-- Atlas de chasse · hidden pets: beasts that only appear after a hidden step.
-- Written by hand (not generated), one record per pet, from the sources named
-- in `source`. Names the client can give (spells, items, zones) are read from
-- it at display time; the strings here are the fallback.
--
--   item    = { id, count, en, fr }: the item the hunter must carry (count to bring)
--   steps   = { en, fr } lines, in order; %ITEM% is replaced by the item's name
--   level   = the hunter level to come at (the beast's highest level, so it can always be tamed)
--   spot    = where the beast appears: { map = uiMapID, x, y } in 0-100
--   itemSpot = where the item lies, same shape; label on either names it on the page's chips
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
    -- Ta'shkal appears at level 57 or 58: at 58 the hunter can tame either.
    level = 58,
    zoneEn = "Mount Hyjal",
    spot = { map = 2482, x = 26.6, y = 64.9, label = { en = "Lantern", fr = "Lanterne" } },
    -- the middle of the 13 spawn points Wowhead lists for the figurine (object 660432)
    itemSpot = { map = 2482, x = 45.5, y = 78.5, label = { en = "Figurine", fr = "Figurine" } },
    item = { id = 276909, count = 2, en = "Corrupted Cat Figurine", fr = "Figurine de chat corrompue" },
    steps = {
      {
        en = "Come at level 58: Ta'shkal appears at level 57 or 58, and at 57 you may not be able to tame it.",
        fr = "Viens niveau 58 : Ta'shkal apparaît niveau 57 ou 58, et au niveau 57 tu risques de ne pas pouvoir le dompter.",
      },
      {
        en = "Pick up a %ITEM% in the fel pools of southern Mount Hyjal, around 45.5 78.5 (Figurine on the map). Bring 2: the lantern sometimes uses one up without the cat showing.",
        fr = "Ramasse une %ITEM% dans les bassins gangrenés de Balafre Gangresang, vers 45,5 78,5 (Figurine sur la carte). Prends-en 2 : la lanterne en consomme parfois une sans que le félin apparaisse.",
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
    source = "Mamytwink / Petopia (Zsawylde), Wowhead (figurine), 2026-11-24",
  },
}
