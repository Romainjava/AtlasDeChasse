# Changelog

Newest first. *Version française sous chaque version.*

## 0.2.2 - 2026-11-24

### Added

- **Rank strip**: under the window title, every rank of the chosen ability (`Ranks 1 2 3 4 [5] 6 7 8`), with the rank on show filled. Click a rank to look at it: the list shows the beasts that teach that rank. The colours say where your pet stands: known, next, or too low a pet level. Hover a pill for the pet level, the training points and the effect.
- **Hidden pets, two places**: on the Ta'shkal page, two chips over the map switch between where the figurine lies and where the cat appears; the map and both map buttons follow the chip. The page opens on the figurine while the bags hold fewer than needed.

### Changed

- **Every beast at first**: the filters start off, so the first list is every teacher of the rank. You narrow it down, and never wonder why it is short.
- **Taller window**: 34 pixels more, for the rank strip.

### Data

- Ta'shkal (Mount Hyjal, hidden cat): the Corrupted Cat Figurine lies at 45.5 78.5 in the fel pools, the page says to come at level 58, and the steps are rewritten around it.

### Fixed

- After the pet learns a rank, the window stays on the same ability (it used to jump to the first ability of the list).
- A card of the Here tab that points at a rank the pet already knows now opens that exact rank.

### Français

- **Bande de rangs** : sous le titre, tous les rangs de la compétence choisie (`Rangs 1 2 3 4 [5] 6 7 8`), le rang affiché rempli. Un clic sur un rang l'affiche : la liste montre les bêtes qui enseignent ce rang. Les couleurs disent où en est le familier : connu, prochain, ou niveau de familier trop bas. Le survol d'une pastille donne le niveau du familier, les points de dressage et l'effet.
- **Bêtes cachées, deux lieux** : sur la page de Ta'shkal, deux pastilles au-dessus de la carte basculent entre l'endroit de la figurine et celui où le félin apparaît ; la carte et les deux boutons de carte suivent la pastille. La page s'ouvre sur la figurine tant que les sacs en portent moins qu'il n'en faut.
- **Toutes les bêtes au départ** : les filtres sont coupés au lancement, la première liste montre donc tous les maîtres du rang. On la resserre, et on ne se demande plus pourquoi elle est courte.
- **Fenêtre plus haute** : 34 pixels de plus, pour la bande de rangs.
- **Données** : Ta'shkal (Mont Hyjal, félin caché), la Figurine de chat corrompue se trouve à 45,5 78,5 dans les bassins gangrenés, la page conseille de venir au niveau 58, et les étapes sont réécrites autour d'elle.
- **Corrigé** : après l'apprentissage d'un rang par le familier, la fenêtre reste sur la même compétence (elle sautait avant à la première compétence de la liste).
- **Corrigé** : une carte de l'onglet Ici qui pointe un rang que le familier connaît déjà ouvre maintenant ce rang exact.

## 0.2.1 - 2026-11-23

### Data

- Database update: 472 teaching beasts (+33) and 569 teacher links (+47).
- Two new zones, Mount Hyjal and Shen'dralas, with the beasts that live there.
- 19 beasts are now placed in every zone they live in, not only the first one.
- Ranks that had no teacher now have one, from Web 4 and Sonic Blast 4 to Swipe 3, Tendon Rip 5, Mine! 4, Savage Rend 5 and Pinch 3-4.
- Two families corrected: Vulgara the Insatiable is a Fox, Shriekling Fledgling a Bird of Prey.
- 10 beasts still have no location: Forever-only NPCs that no source places.

### Français

- **Données** : mise à jour de la base, 472 bêtes qui enseignent (+33) et 569 liens (+47).
- Deux nouvelles zones, le Mont Hyjal et Shen'dralas, avec les bêtes qui y vivent.
- 19 bêtes sont désormais placées dans toutes leurs zones, pas seulement la première.
- Des rangs qui n'avaient aucun maître en ont un (Web 4, Sonic Blast 4, Swipe 3, Tendon Rip 5, Mine! 4, Savage Rend 5, Pinch 3 et 4).
- Deux familles corrigées : Vulgara l'Insatiable est un Renard, Jeune criailleuse un Oiseau de proie.
- 10 bêtes n'ont toujours pas d'emplacement : des PNJ propres à Forever qu'aucune source ne place.

## 0.2.0 - 2026-11-21

### Added

- **Here tab**: everything the zone you stand in can teach your pet, sorted by interest. Tame now, when you have the level, already learned. A card opens its rank and beast.
- **Beast tooltip**: hovering a teaching beast tells you, rank by rank, whether to tame it, the pet level it needs, whether it is too high for you, or whether you already know it.
- **Beast alert**: a small banner when you target or hover a beast that teaches a rank your pet can take now. Once per beast and per session, never in combat, 5 seconds. Click it to open the atlas on that rank. `/atlas alerts` turns it off.
- **Sources shown**: each beast says where its information comes from (Verified, Seen in game, Petopia, HunterPetJournal, Wowhead). The Here tab shows the date of the data and the addon version.
- **Taming notes**: when you tame a beast, the addon notes the ranks the new pet arrives with. When you target a beast, it also notes its family, level and whether it is rare or elite, even from afar.

### Data

- 439 teaching beasts (+20), most of them in the new Riverglades, plus Ta'shkal in Mount Hyjal.
- 522 teacher links (+25) and 377 French names (+15).
- Drywallow Snapper now teaches Bite 5, following Petopia.
- The data now also takes in-game observations by the maintainer. A position is added only where no source places the beast, and ranks are confirmed by taming.

### Fixed

- On an English client, a beast seen in game no longer shows its French name.

### Français

- **Onglet Ici** : tout ce que la zone peut apprendre à votre familier, trié par intérêt.
- **Infobulle des bêtes** : un verdict par rang (à apprivoiser, familier niv. X requis, trop haute pour toi, déjà appris).
- **Alerte** : un petit bandeau quand une bête utile est ciblée, une fois par bête et par session, jamais en combat. `/atlas alerts` la coupe.
- **Sources affichées** : Vérifié, Vu en jeu, ou le site d'origine, avec la date des données.
- **Apprivoisement** : l'addon note les rangs du nouveau familier. Au ciblage, il note aussi la famille, le niveau et la rareté de la bête.
- **Données** : 439 bêtes (+20, surtout dans les Riverglades), 522 liens (+25), 377 noms français (+15).
- **Corrigé** : sur un client anglais, une bête vue en jeu ne s'affiche plus en français.

## 0.1.0 - 2026-11-18

First release: the pet's ranks (now, later, pet trainer), the beasts that teach each rank with filters, the map point, the arrow and pin, learned ranks, learning as you play, four themes and the hidden pets tab.
