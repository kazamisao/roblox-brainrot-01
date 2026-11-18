# Brainrot Island

[![roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/kazamisao/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/kazamisao/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

A 3D Roblox brainrot game on a tropical island, built for make.fun's
**roblox-brainrot-01** bounty. Play it here: https://www.roblox.com/games/133336026902889

## The game

Brainrot characters ride a conveyor belt across the plaza of a sunny island. Buy one as it
passes, and it glides to your base, stands on a slot, and pays you cash every second. Richer
characters cost more and pay more, so you climb the ladder from a sleepy mouse-deer to the
legendary sambal dragon. Other players can snatch characters off your base and carry them
home — lock your base for 30 seconds to stop them — and every 90 seconds a **Hujan Meteor
Sambal** (sambal meteor rain) drops bonus cash on the plaza. The island runs on a day/night
cycle: at night the rare tiers ride the belt twice as often, and once per night a free golden
brainrot appears somewhere on the island under a pillar of light — first to reach it, with a
free base slot, claims it. Rebirth costs cash only (your cast stays) and adds a permanent
+25% income per level, up to 5 levels.

### The cast (all original)

| Character | Rarity | Price | Income |
| --- | --- | --- | --- |
| Kancil Ngantuk | Common | $25 | $1/dtk |
| Kerupuk Terbang | Common | $75 | $3/dtk |
| Sate Berjalan | Rare | $250 | $8/dtk |
| Bakso Raksasa | Epic | $1.000 | $25/dtk |
| Rendang Sakti | Legendary | $5.000 | $80/dtk |
| Tungku Sate Emas | Mythic | $25.000 | $220/dtk |
| Naga Sambal Legendaris | Secret | $150.000 | $500/dtk |

Each is a real 3D model built from primitive Parts — a round little mouse-deer, a flat flying
cracker, a walking satay skewer, a giant meatball, a golden satay stove, a huge red sambal
dragon — with a nameplate showing its name, rarity (in the rarity colour) and $/second.

## How to play

1. Wait for a brainrot you can afford to ride down the plaza conveyor.
2. Use its **Beli** prompt to buy it; it glides to your base and starts paying $/second.
3. Fill your 6 slots, sell a brainrot back for half price from its **Jual** prompt when you
   need the room, and save for the next tier. Watch the meteor countdown: when the rain
   comes, stand near landed meteors for bonus cash.
4. Raid other bases with the **Curi** prompt (0,6 s hold) and carry the catch home — you
   walk 15% slower while carrying, and dying drops the catch, which glides home on its own.
5. Defend with the lock pad at your base or the HUD button: 30 seconds of protection, then
   a 60-second cooldown.
6. Rebirth at the purple stall on the plaza or from the HUD: each level costs four times
   the last and multiplies all income by +25%, and your brainrots stay where they are.
7. Stay up at night: rare spawns double, and the golden brainrot is free for whoever
   reaches it first.

## How it was built

- A **Rojo** project: the Luau sources under `src/` build the place with
  `rojo build default.project.json --output game.rbxl`. The world itself — island, plaza,
  conveyor, six bases, the rebirth stall, palm trees — is also built from Parts in code
  (`WorldBuilder`), so the whole game lives in this repository.
- Server-authoritative throughout: all state lives in one store (`PlayerState`), cash moves
  only on the server, and every client request (buy, steal, sell, lock, rebirth) is
  re-validated there.
- One responsibility per module: `BrainrotData` (the cast), `CharacterFactory` (the models
  and their glides), `ConveyorService` (the belt), `BaseService` (slots, income, lock),
  `StealService` (snatches and carries), `EventService` (the meteor rain, day/night and the
  golden visitor), `RebirthService` (rebirths), and one client script for the HUD. Cash and
  rebirth progress persist through a DataStore wrapped in `pcall`, so the game still runs
  session-only where store access is unavailable.
- `main.ts` (Node 22, standard library only) hands the entry in: it copies `game.rbxl`,
  `src/`, `screenshots/` and `PLAY.json` to the output directory and writes `dossier.json`
  with the vendored `vendor/makefun-roblox.ts`.

## Publishing

The experience was published from Roblox Studio on the same experience as before, set
Public, and its description carries this account's make.fun play code; `PLAY.json` names
its play link, place id and universe id. The finished place is published over the same
experience, and the screenshots in `screenshots/` are captures of the game running in
Studio — the first is also the experience's first thumbnail on Roblox.

Run the hand-in locally the way the grader does:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
