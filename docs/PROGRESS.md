# Progress Tracker

Owned by the lead (the main Claude session), who plans, dispatches the agents and verifies their work. Design reference: [GAME_DESIGN.md](GAME_DESIGN.md).

Status values: `todo`, `doing`, `review`, `done`, `blocked`.
Task IDs: `G` gameplay, `B` builder, `M` meta, `U` ui-artist, `Q` qa, `P` lead.

UI split: the agent that owns a system builds and wires that system's UI. The `ui-artist` only polishes UI that already works.

**Current milestone:** M0 Foundation
**Last updated:** 2026-10-05

## M0 — Foundation

Goal: the project boots with the agreed structure and a graybox map.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | Resolve open decisions in GAME_DESIGN.md section 10 | lead | todo | | needs the user |
| G-01 | Service/controller bootstrap in `init.server.luau` and `init.client.luau`; remove `Hello.luau` | gameplay | review | | `Shared.Loader` runs every module in `Services/` and `Controllers/`: all `Init()` first, then `Start()` |
| G-02 | `Config` modules and `Remotes.luau` | gameplay | review | G-01 | Config: `Verity`, `Stack`, `Guardian`, `Drop`. Remotes live in `ReplicatedStorage.Remotes`. `Verity.PickupRadius` (6) is not in the GDD |
| M-01 | `DataService` with in-memory session profile (no DataStore yet) | meta | review | G-01 | profile shape in `Config.Data.Template` and `Types.Profile`. Server API: `GetProfile`, `OnProfileLoaded`, `Update`, `AddBanked`, `TrySpend`, `RecordStack`. Client reads Player attributes `Banked`, `TotalBanked`, `Rebirths`, `TallestStack`, `Upgrade<Id>` and `DataLoaded`; no remote. Data resets every session until M-02 |
| B-01 | Graybox map meeting the map contract (GDD section 9) | builder | done | | flat meadow layout, superseded by the tower (B-08) and removed from the place |
| B-08 | Tower graybox map, now `Workspace.Map` | builder | review | | chosen layout, needs saving in Studio; three floors `Zone1` to `Zone3`; curved interior ramps `Zone2.RampTo2` (south-west corner of floor 1) and `Zone3.RampTo3` (north-east corner of floor 2), each arriving through a railed opening in the floor above, walked end to end in a playtest; spawn regions: four on floor 1, three each on floors 2 and 3 (split around the opening, `Weight` by area); return pads wired in G-11; gates carry `RequiredRebirths` and do not block yet; GDD sections 4.3, 4.8 and 9 need updating |

## M1 — Core loop

Goal: collect, stack, bank. Playable without the Guardian.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| G-03 | `VerityService`: spawn, cap, refill | gameplay | review | G-02, B-01 | pickups live in `Workspace.Pickups`, tag `VerityPickup`, attributes `Tier`, `Value` and `Weight`; tiers are in `Config.Verity.Tiers` and orbs are sized and tinted per tier by `Shared.VerityOrb`; G-04 reads `VerityService.GetTier(pickup)` and collects through `VerityService.Collect(pickup)`, which returns the tier. Placeholder orb until B-02. Region `Weight` attribute steers refills; GDD section 9 should list `Weight`. Floors 2 and 3 now spawn (`Zone2` Normal and Golden, `Zone3` Golden and Corrupted, picked evenly) |
| G-04 | `StackService`: server stack state, pickup validation, capacity, speed penalty | gameplay | review | G-03 | the stack is a list of tiers; capacity and the speed penalty count weight, banking counts value; a pickup is taken only if its whole weight fits. Player attributes `Stack` (count), `StackWeight`, `StackCapacity`, `StackValue` (Multiplier included) and `StackTiers` (one letter per Verity, e.g. `NNGC`), names in `Config.Stack`. API `Get`, `GetWeight`, `GetCapacity`, `GetValue`, `GetTiers`, `Remove(count)`, `Clear`; the last two return the tiers removed. Pickup is a server distance check each frame, no remote. Upgrade effects per level live in `Config.Stack` and `Config.Verity`. Stack is lost on death (assumed) |
| G-05 | `StackController`: head stack visuals with visual cap | gameplay | review | G-04 | client-only anchored orbs in `Character.VerityStack`, placed each frame so the stack wobbles on a spring (tunables `Wobble*` and `IdleSway*` in `Config.Stack`), for every player, one orb per Verity sized and tinted by tier from `StackTiers`; count billboard past `VisualCap`. `Config.Stack.OrbScale` and `OrbSpacing` (both 0.75, user to confirm) keep a 30-orb stack 24.6 studs tall, under the 36 stud ceilings. Only one-player rendering tested |
| G-06 | `BankService`: bank zone converts stack to banked Veritys | gameplay | review | G-04, M-01 | a living character inside a `BankZone` banks its whole stack at once: `DataService.AddBanked(StackService.GetValue)`, then the stack clears and `DataService.RecordStack` gets the Verity count. Fires `Remotes.StackBanked(value, count)` to that player. The rebirth bank bonus (GDD 4.7) is not applied; that is M-04's to hook in |
| G-11 | `ReturnPadService`: return pads send the character to the lobby | gameplay | review | B-08 | staying on a `ReturnPad` for `Config.ReturnPad.ChannelSeconds` (1.5, user to confirm; 0 = instant) moves the character to `ReturnTarget`; stack untouched; player attribute `ReturnAt` holds the server time the teleport fires, for a UI countdown |
| G-12 | Carry and strain animations while holding a stack | gameplay | review | G-04 | `CarryController` plays them on the local character while `StackWeight` > 0, upper body only, over walk and idle. It cross-fades from Carry to Strain as weight / capacity goes from `Config.Stack.StrainStart` (0.5) to 1. Published as group assets 103959159779590 (Carry) and 98274000309647 (Strain), ids in `Config.Stack`, by `tools/carry_animation.py` through Open Cloud; the key is in the untracked `.env`. Preview copies are under `ReplicatedStorage.Assets.Animations` in the place, rebuilt by `tools/build_carry_animation.luau`. R15 only |
| G-13 | Working HUD: stack weight / capacity and value, return pad countdown | gameplay | review | G-04, G-11 | `StackHudController` builds `PlayerGui.StackHud`: `Load` (bar `Fill`, `Amount` as weight / capacity, `Value` as "Carrying: n", `Speed` as the share of walk speed left under the load, `TooHeavy`, and `Banked` as a 2 second "Banked +n" note) at bottom centre and `Return.Countdown` while on a return pad. The bar turns red and `TooHeavy` shows while the new `StackRefused` attribute is true (a pickup in reach does not fit). Plain, for U-01 to style |
| M-09 | Working HUD: banked Veritys | meta | review | M-01 | `BankedHudController` builds `PlayerGui.BankedHud.Banked.Amount`, left edge, vertically centred; reads the `Banked` attribute. `Shared.Format.Number` abbreviates numbers (1.25K) for any UI |
| U-01 | HUD polish; sets up the shared theme in `src/client/UI/` | ui-artist | todo | G-13, M-09 | look only, no logic changes |
| B-02 | Verity orb model | builder | review | | `ReplicatedStorage.Assets.Verity`: Model with PrimaryPart `Orb` (2 stud ball, no collision, massless) and decal `Face` on the Front face, pivot at the centre facing -Z; needs saving in Studio. Open: a 30-orb stack is 60 studs against 36 studs of floor headroom; face image ownership and GDD open decision 4 |
| Q-01 | Playtest M1 loop, report trip time and feel | qa | todo | G-06, G-13, M-09 | |

## M2 — Guardian

Goal: the risk half of the loop.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| G-07 | `GuardianService`: state machine, targeting, pathfinding | gameplay | review | G-04 | one Guardian per `GuardianSpawn`, in `Workspace.Guardians`, attributes `Zone` and `State`. Hunts the heaviest stack on its floor (min weight 5), 1.5 s telegraph, paths with PathfindingService and heads straight for a target with no path. Floors 2 and 3 are faster (`Config.Guardian.Zones`). Stand-in model is a giant Corrupted orb until B-03 puts a `Guardian` model in `ServerStorage.Assets` |
| G-08 | Hit handling: drop, scatter pickups, immunity | gameplay | review | G-07 | `DropService.Drop(player)` drops the whole stack (user decision), scatters up to 40 pickups 8 to 14 studs away through `VerityService.SpawnDropped` (attribute `Dropped`, not collectable for 0.75 s, gone after 10 s), 3 s immunity, fires `Remotes.StackDropped(count)` |
| G-09 | Safe zone exclusion | gameplay | review | G-07 | players in a `SafeZone` are never targeted and entering one ends the chase; the Guardian paths around safe zones (a PathfindingModifier is added to each at runtime) and never steps into one |
| B-03 | Guardian model and rig | builder | todo | | |
| G-14 | Working hunted warning for the targeted player | gameplay | review | G-07 | `HuntedController` builds `PlayerGui.HuntedHud`: `Warning` while hunted (from `Remotes.GuardianHunt`) and `Dropped` for 3 s after a hit. Plain, for U-02 to add the audio cue and screen effect |
| U-02 | Hunted warning polish: audio cue and screen effect | ui-artist | todo | G-14 | |
| Q-02 | Playtest Guardian fairness with 1 and 3+ players | qa | todo | G-08, G-14 | |

## M3 — Meta

Goal: reasons to keep playing past the first session.

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| M-02 | DataStore persistence with session locking and retries | meta | review | M-01 | built on ProfileStore, vendored at `src/server/Vendor/ProfileStore.luau`. Live store `PlayerData`, Studio saves to `PlayerData_Studio`, key `Player_<UserId>`. `DataService` API unchanged, but profiles now load asynchronously: use `OnProfileLoaded` or handle a nil `GetProfile` |
| M-03 | `UpgradeService` and cost curves | meta | review | M-02 | prices in `Config.Upgrades`, formula in `Shared.Economy.UpgradeCost`. RemoteFunction `BuyUpgrade(upgradeId)` returns `(bought, reason)`. Curves tuned in `tools/economy_sim.py` on guessed map timings: first upgrade 0.6 min, first rebirth 23 min at a rebirth cost of 1200 (M-04); retune after Q-01. Retuned for the weight/value split: Multiplier now multiplies banked value, so it costs 50, doubling per level. Open: Speed level 3 and up outruns the Guardian (18) when unloaded; Zone 2 income makes the second rebirth about twice as fast as the first |
| M-04 | `RebirthService` | meta | todo | M-03 | |
| M-05 | Global leaderboards (OrderedDataStore) | meta | todo | M-02 | |
| M-10 | Working shop and rebirth UI | meta | todo | M-03, M-04 | plain, fully wired |
| U-03 | Shop and rebirth UI polish | ui-artist | todo | M-10 | |
| B-04 | Shop and leaderboard props at spawn | builder | todo | | |
| Q-03 | Economy pacing check: time to first rebirth | qa | todo | M-04 | target 20 to 30 min |

## M4 — Content and polish

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| B-05 | Zone 1 art pass | builder | todo | Q-02 | |
| B-06 | Zone 2 (Dusk Fields) | builder | todo | M-04 | |
| G-10 | Zone unlock gating and pickup tiers | gameplay | todo | M-04, B-06 | tiers already spawn on floors 2 and 3 (done with the weight change); the gates still do not block and the tier mix per floor is an even split |
| M-06 | Pets and eggs | meta | todo | M-03 | |
| M-07 | Daily and playtime rewards | meta | todo | M-02 | |
| U-04 | Juice: pickup pop, bank burst, smile stages, SFX | ui-artist | todo | U-01 | presentational only |

## M5 — Monetization and launch

| ID | Task | Owner | Status | Depends on | Notes |
| --- | --- | --- | --- | --- | --- |
| M-08 | Gamepasses and developer products, including Save My Stack | meta | todo | G-08 | |
| M-11 | Working store UI and purchase prompts | meta | todo | M-08 | plain, fully wired |
| U-05 | Store UI polish | ui-artist | todo | M-11 | |
| Q-04 | Exploit pass on every remote | qa | todo | | |
| Q-05 | Full playtest, mobile and PC | qa | todo | | |
| B-07 | Icon and thumbnail scenes | builder | todo | | |

## Decision log

| Date | Decision | By |
| --- | --- | --- |
| 2026-10-05 | Scripts live in Rojo `src/`; map lives in the Studio place file | initial setup |
| 2026-10-05 | Map is a tower: stacked floors, bank and safe zone in the lobby on floor 1. Flat meadow map removed | user |
| 2026-10-05 | No open shaft. Players return from upper floors by a teleport pad to the lobby | user |
| 2026-10-05 | Ramps between floors are curved and inside the tower, one per floor in alternating corners; the outside ramps are removed | user |
| 2026-10-05 | Player data persists through ProfileStore, vendored as one file, no Wally | user |
| 2026-10-05 | Veritys have a weight separate from their value: Normal 1/1, Golden 5/3, Corrupted 25/10 (value/weight). Capacity and slowdown count weight, the bank counts value, and a Verity that does not fit stays on the ground. Multiplier multiplies banked value only | user |
| 2026-10-05 | A Guardian hit drops the whole stack, not half. The Veritys scatter as pickups the player can try to grab back | user |
| 2026-10-05 | Balance belongs to the meta agent, which directly edits the economy values in `Config.Verity` and `Config.Stack` (listed in the agent briefs). The user sets pacing targets, qa measures them, gameplay keeps the feel values | user |
| 2026-10-05 | System owners build and wire their own UI. The UI agent is a UI artist (`ui-artist`) who only polishes working UI | user |

## Blockers

None.
