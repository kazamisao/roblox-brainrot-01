# Warung Brainrot: Gerobak Gacor

[![roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/kazamisao/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/kazamisao/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

A 3D Roblox brainrot game set in an Indonesian night market (pasar malam), built for make.fun's
**roblox-brainrot-01** bounty. Play it here: https://www.roblox.com/games/133336026902889

## The game

Brainrot characters ride a conveyor belt down the middle of a neon night-market plaza. Buy one as
it passes, and it walks itself to your base, stands on a slot, and pays you cash every second.
Richer characters cost more and pay more, so you climb the ladder from a flying cracker to a golden
satay stove. Other players can snatch characters off your base and carry them home — lock your
base for 30 seconds to stop them — and every 90 seconds a **Hujan Meteor Sambal** (sambal meteor
rain) drops bonus cash on the plaza and knocks stolen brainrots loose. Rebirth resets your cash
and cast for a permanent +25% income per level, up to 5 levels.

### The cast (all original)

| Character | Rarity | Price | Income |
| --- | --- | --- | --- |
| Kerupuk Terbang | Common | $25 | $1/dtk |
| Es Teh Raksasa | Uncommon | $150 | $4/dtk |
| Gorengan Bernyanyi | Rare | $600 | $12/dtk |
| Bakso Meledak | Epic | $2.500 | $30/dtk |
| Nasi Padang Terbang | Legendary | $10.000 | $80/dtk |
| Rendang Raksasa | Mythic | $40.000 | $200/dtk |
| Tungku Sate Emas | Secret | $150.000 | $500/dtk |

Each is a real 3D model built from primitive Parts — a cracker disc with wings, a giant iced-tea
glass with ice cubes, a meatball with a lit fuse, a flying plate of nasi padang, a golden satay
stove with sparkles — with a nameplate showing its name, rarity and $/second.

## How to play

1. Wait for a brainrot you can afford to ride down the central conveyor.
2. Use its **Beli** prompt to buy it; it walks to your base and starts paying $/second.
3. Fill your 8 slots, then save for the next tier. Watch the meteor countdown: when the rain
   comes, touch landed meteors for bonus cash.
4. Raid other bases with the **Curi** prompt (0.6 s hold) and carry the catch home — you walk
   15% slower while carrying, and a meteor landing next to you knocks it loose.
5. Defend with the lock pad at your base or the HUD button: 30 seconds of protection, then a
   60-second cooldown.
6. Rebirth at the golden REBIRTH stall or from the HUD when the multiplier is worth the reset.

## How it was built

- A **Rojo** project: the Luau sources under `src/` build the place with
  `rojo build default.project.json --output game.rbxl`. The world itself — plaza, conveyor, six
  bases, stalls, string lights, trees — is also built from Parts in code (`WorldBuilder`), so the
  whole game lives in this repository.
- Server-authoritative throughout: all state lives in one store (`PlayerState`), cash moves only
  on the server, and every client request (buy, steal, lock, rebirth) is re-validated there.
- One responsibility per module: `BrainrotData` (the cast), `CharacterFactory` (the models),
  `ConveyorService` (the belt), `BaseService` (slots, income, lock), `StealService` (grabs and
  carries), `EventService` (the meteor rain), `RebirthService` (rebirths), and one client script
  for the HUD. Rebirth progress persists through a DataStore wrapped in `pcall`, so the game
  still runs session-only where store access is unavailable.
- `main.ts` (Node 22, standard library only) hands the entry in: it copies `game.rbxl`, `src/`,
  `screenshots/` and `PLAY.json` to the output directory and writes `dossier.json` with the
  vendored `vendor/makefun-roblox.ts`.

## Publishing

The experience was published from Roblox Studio as **Warung Brainrot**, set Public, and its
description carries this account's make.fun play code; `PLAY.json` names its play link, place id
and universe id. The finished place is published over the same experience from Studio, and the
screenshots in `screenshots/` are captures of the game running in Studio — the first is also the
experience's first thumbnail on Roblox.

Run the hand-in locally the way the grader does:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
