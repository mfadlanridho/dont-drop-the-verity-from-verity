# Progress Tracker

Owned by the lead (the main Claude session), who plans, dispatches the agents and verifies their work. Design reference: [GAME_DESIGN.md](GAME_DESIGN.md).

Status values: `todo`, `doing`, `review`, `done`, `blocked`.
Task IDs: `G` gameplay, `B` builder, `M` meta, `U` ui, `Q` qa, `P` lead.

**Current milestone:** M0 Foundation
**Last updated:** 2026-10-05

## M0 — Foundation

Goal: the project boots with the agreed structure and a graybox map.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | Resolve open decisions in GAME_DESIGN.md section 10 | lead | todo | | needs the user |
| G-01 | Service/controller bootstrap in `init.server.luau` and `init.client.luau`; remove `Hello.luau` | gameplay | review | | `Shared.Loader` runs every module in `Services/` and `Controllers/`: all `Init()` first, then `Start()` |
| G-02 | `Config` modules and `Remotes.luau` | gameplay | review | G-01 | Config: `Verity`, `Stack`, `Guardian`, `Drop`. Remotes live in `ReplicatedStorage.Remotes`. `Verity.PickupRadius` (6) is not in the GDD |
| M-01 | `DataService` with in-memory session profile (no DataStore yet) | meta | todo | G-01 | |
| B-01 | Graybox map meeting the map contract (GDD section 9) | builder | done | | flat meadow layout, superseded by the tower (B-08) and removed from the place |
| B-08 | Tower graybox map, now `Workspace.Map` | builder | review | | chosen layout, needs saving in Studio; three floors `Zone1` to `Zone3`, four spawn regions per floor with `Weight` by area (no `Band`); gates carry `RequiredRebirths` and do not block yet; `ReturnPad` on floors 2 and 3 is unwired; GDD sections 4.3, 4.8 and 9 need updating |

## M1 — Core loop

Goal: collect, stack, bank. Playable without the Guardian.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| G-03 | `VerityService`: spawn, cap, refill | gameplay | review | G-02, B-01 | pickups live in `Workspace.Pickups`, tag `VerityPickup`, attributes `Tier` and `Value`; G-04 collects through `VerityService.Collect(pickup)`. Placeholder orb until B-02. Region `Weight` attribute steers refills; GDD section 9 should list `Band` and `Weight` |
| G-04 | `StackService`: server stack state, pickup validation, capacity, speed penalty | gameplay | todo | G-03 | |
| G-05 | `StackController`: head stack visuals with visual cap | gameplay | todo | G-04 | |
| G-06 | `BankService`: bank zone converts stack to banked Veritys | gameplay | todo | G-04, M-01 | |
| U-01 | HUD: stack count / capacity, banked Veritys | ui | todo | G-04 | |
| B-02 | Verity orb model | builder | todo | | |
| Q-01 | Playtest M1 loop, report trip time and feel | qa | todo | G-06, U-01 | |

## M2 — Guardian

Goal: the risk half of the loop.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| G-07 | `GuardianService`: state machine, targeting, pathfinding | gameplay | todo | G-04 | |
| G-08 | Hit handling: drop, scatter pickups, immunity | gameplay | todo | G-07 | |
| G-09 | Safe zone exclusion | gameplay | todo | G-07 | |
| B-03 | Guardian model and rig | builder | todo | | |
| U-02 | Hunted warning: audio cue and screen effect | ui | todo | G-07 | |
| Q-02 | Playtest Guardian fairness with 1 and 3+ players | qa | todo | G-08, U-02 | |

## M3 — Meta

Goal: reasons to keep playing past the first session.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| M-02 | DataStore persistence with session locking and retries | meta | todo | M-01 | |
| M-03 | `UpgradeService` and cost curves | meta | todo | M-02 | |
| M-04 | `RebirthService` | meta | todo | M-03 | |
| M-05 | Global leaderboards (OrderedDataStore) | meta | todo | M-02 | |
| U-03 | Shop and rebirth UI | ui | todo | M-03 | |
| B-04 | Shop and leaderboard props at spawn | builder | todo | | |
| Q-03 | Economy pacing check: time to first rebirth | qa | todo | M-04 | target 20 to 30 min |

## M4 — Content and polish

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| B-05 | Zone 1 art pass | builder | todo | Q-02 | |
| B-06 | Zone 2 (Dusk Fields) | builder | todo | M-04 | |
| G-10 | Zone unlock gating and pickup tiers | gameplay | todo | M-04, B-06 | |
| M-06 | Pets and eggs | meta | todo | M-03 | |
| M-07 | Daily and playtime rewards | meta | todo | M-02 | |
| U-04 | Juice: pickup pop, bank burst, smile stages, SFX | ui | todo | | |

## M5 — Monetization and launch

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| M-08 | Gamepasses and developer products, including Save My Stack | meta | todo | G-08 | |
| U-05 | Store UI and purchase prompts | ui | todo | M-08 | |
| Q-04 | Exploit pass on every remote | qa | todo | | |
| Q-05 | Full playtest, mobile and PC | qa | todo | | |
| B-07 | Icon and thumbnail scenes | builder | todo | | |

## Decision log

| Date | Decision | By |
| --- | --- | --- |
| 2026-10-05 | Scripts live in Rojo `src/`; map lives in the Studio place file | initial setup |
| 2026-10-05 | Map is a tower: ring floors around an open shaft, bank and safe zone in the lobby at the bottom, jumping down the shaft to bank is allowed. Flat meadow map removed | user |

## Blockers

None.
