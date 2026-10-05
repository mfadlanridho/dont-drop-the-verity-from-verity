# Don't Drop the Verity — Game Design

Status: draft v0.1 (2026-10-05). Items marked **[ASSUMED]** are defaults picked without sign-off; see [Open decisions](#10-open-decisions).

## 1. Pitch

A +1-style Roblox collect-a-thon. You pick up Veritys (the smiling yellow orb from the Minecraft horror series), stack them on your head, and carry them to the bank. The taller your stack, the slower you move and the more the Verity Guardian wants you. Get hit and your stack spills for everyone else to grab.

## 2. Pillars

1. **The stack is the score.** Stack height is visible to every player at all times. No one needs a leaderboard to know who is winning or who to chase.
2. **Greed is the risk.** Every extra Verity makes you slower and a bigger target. The player always chooses when to cash in.
3. **Instantly readable.** A new player understands the game within 10 seconds of spawning, with no tutorial.
4. **Friendly thing going wrong.** The tone borrows Verity's slow-burn unease: cute first, unsettling as the numbers climb.

## 3. Core loop

1. **Collect** — walk over a Verity and it goes on your stack, if its weight fits.
2. **Carry** — the heavier the stack, the slower you move.
3. **Survive** — the Guardian hunts the tallest stack outside the safe zone.
4. **Bank** — step into the bank zone to convert the stack's value into banked Veritys (the spendable currency).
5. **Upgrade** — spend banked Veritys on capacity, speed, magnet and multiplier.
6. **Rebirth** — reset upgrades and banked Veritys for a permanent multiplier and access to the next zone.

A full collect-to-bank trip should take 30 to 90 seconds in the first zone.

## 4. Systems

All numbers below are starting values and live in `src/shared/Config` so they can be tuned without code changes.

### 4.1 Veritys (pickups)

- Spawn at random points inside each zone's spawn region, up to a per-zone cap (start: 60), refilling at a fixed rate (start: 2 per second).
- Each tier has a value and a weight. Value is what the Verity banks for. Weight is what it uses of the stack's capacity and what slows the carrier. Better tiers bank more per unit of weight, so they are worth more per trip but each one is a bigger commitment.

  | Tier | Value | Weight | Value per weight |
  | --- | --- | --- | --- |
  | Normal | 1 | 1 | 1 |
  | Golden | 5 | 3 | 1.7 |
  | Corrupted | 25 | 10 | 2.5 |

- Higher tiers only spawn in later zones (4.8). Each spawn picks one of its zone's tiers at random.
- Collected by walking within reach, checked on the server (distance from the character). There is no pickup remote.
- A Verity is only picked up if its whole weight fits in the capacity the player has left. One that does not fit stays in the world.

### 4.2 Stack

- The stack is the list of Veritys a player holds, bottom first. It has a count (how many), a weight (the sum of their weights) and a value (the sum of their values).
- Capacity is a weight limit. It starts at 10 and is the main upgrade. A new player can hold ten Normals, three Goldens, or exactly one Corrupted.
- Rendered as one orb per Verity stacked on the head, sized and tinted by tier. Past a visual cap (start: 30 orbs) the stack stops growing in parts and shows a count billboard instead, to protect performance.
- Speed penalty: 1% of walk speed per unit of weight carried, capped at 40%.
- The stack is lost on death **[ASSUMED]**, so resetting is not a free trip to the bank.
- Stack state lives on the server. Clients only render it.

### 4.3 Bank

- A zone at spawn. Entering it converts the whole stack to banked Veritys instantly **[ASSUMED]**. The amount is the stack's value times the player's multipliers.
- The bank zone and the spawn area are a safe zone: the Guardian cannot enter or target players inside.

### 4.4 Verity Guardian

- One Guardian per zone. A large corrupted Verity.
- States: `Idle` → `Hunting` → `Chasing` → `Attacking` → `Cooldown`.
- Each Guardian stays on its own floor and only hunts players on it.
- Targeting **[ASSUMED]**: the player carrying the heaviest stack on its floor and outside the safe zone, with a minimum weight of 5 so brand-new players are left alone. While idle it looks for a target every few seconds; once it has one it keeps that target until the chase ends.
- Speed: slightly faster than an unburdened player (start: 18 vs 16), so a loaded player cannot outrun it in a straight line and has to use the map or bank early.
- Chase leash: gives up after 12 seconds, then a 6 second cooldown. A chase also ends at once if the target enters the safe zone, banks, dies or leaves the floor.
- Telegraph: the Guardian stands still for 1.5 seconds after picking a target, and the target gets a warning (audio cue and screen effect) for the whole hunt. Being hunted must never feel like a surprise.
- It paths around the safe zone and never enters it.

### 4.5 Dropping

- A Guardian hit drops the whole stack.
- Dropped Veritys scatter in a ring around the player as pickups that anyone can collect, including the player who dropped them, and despawn after 10 seconds. They cannot be collected for the first 0.75 seconds. At most 40 are scattered per hit; the rest of a larger stack is lost.
- The hit player gets 3 seconds of immunity so they cannot be chain-hit.
- No player-versus-player knocking in v1.

### 4.6 Upgrades

Bought with banked Veritys, each with escalating cost:

| Upgrade | Effect per level |
| --- | --- |
| Capacity | +5 weight capacity |
| Speed | +1 base walk speed |
| Magnet | +2 studs pickup radius |
| Multiplier | +100% of base value when banked (level 1 doubles it, level 2 triples it); weight is unchanged |

### 4.7 Rebirth

- Cost scales per rebirth. Resets upgrades and banked Veritys.
- Grants a permanent bank multiplier (+50% per rebirth) and unlocks the next zone at set rebirth counts.

### 4.8 Zones

| Zone | Unlock | Pickups | Guardian |
| --- | --- | --- | --- |
| 1. Meadow | start | Normal | base |
| 2. Dusk Fields | rebirth 1 | Normal, Golden | faster |
| 3. The Fog | rebirth 3 | Golden, Corrupted | faster, longer leash |

v1 ships with zone 1 only; zones 2 and 3 are post-core content.

### 4.9 Pets (post-core)

Eggs bought with banked Veritys. Pets give pickup or bank multipliers. Standard rarity tiers. Out of scope until the core loop is fun.

## 5. Tone and presentation

- Zone 1 is bright and friendly. Later zones get darker and foggier.
- A Verity's smile shifts as your stack grows: normal, wide, wrong. Cosmetic only.
- The Guardian is the same face, scaled up and corrupted.
- No gore, no jump scares aimed at young players; unease comes from audio and expression changes.

## 6. Monetization

Gamepasses:

- 2x Veritys
- +50 Capacity
- VIP (chat tag, small bank bonus, VIP trail)
- Auto-collect magnet (large radius)

Developer products:

- **Save My Stack** — offered at the moment of a Guardian hit, cancels the drop. Expected top earner.
- Guardian Shield (60 seconds of immunity)
- Banked Verity packs
- Skip rebirth cost

## 7. Retention

- Global leaderboards: total banked, rebirths, tallest stack ever banked.
- Daily login reward and playtime rewards.
- Group-join bonus.

## 8. Technical architecture

Rojo project. Scripts are owned by the filesystem; the map is owned by the Studio place file.

```
src/shared/Config/        tunable numbers (one module per system)
src/shared/Remotes.luau   single place that defines every RemoteEvent/Function
src/shared/Types.luau     shared type definitions
src/server/Services/      one module per system, started by init.server.luau
src/client/Controllers/   one module per system, started by init.client.luau
```

Server services: `VerityService`, `StackService`, `BankService`, `GuardianService`, `DataService`, `UpgradeService`, `RebirthService`, `MonetizationService`.

Rules:

- The server is authoritative for stack, currency and purchases. The client never sends amounts, only intents ("I want to buy upgrade X").
- Every remote handler validates its arguments and rate-limits.
- Player data goes through `DataService` only. No other service touches DataStores.
- Workspace content the code depends on is found by tag (CollectionService) or by a fixed name under `Workspace.Map`, listed in section 9.

## 9. Map contract

The builder provides these; the gameplay code looks them up:

| Instance | Location | Purpose |
| --- | --- | --- |
| `SpawnRegion` parts, tag `VeritySpawnRegion`, number attribute `Weight` | direct children of each `Workspace.Map.Zone<n>` folder | where pickups spawn. `Weight` is the region's relative share of its zone's spawns; it has nothing to do with a Verity's carry weight |
| `BankZone` part, tag `BankZone` | `Workspace.Map.Spawn` | banking trigger |
| `SafeZone` part, tag `SafeZone` | `Workspace.Map.Spawn` | Guardian exclusion volume |
| `GuardianSpawn` part, tag `GuardianSpawn` | `Workspace.Map.Zone1` | Guardian home position |
| `Verity` model | `ReplicatedStorage.Assets` | pickup and stack orb |
| `Guardian` model | `ServerStorage.Assets` | Guardian rig |

## 10. Open decisions

1. **Banking** — bank zone assumed. Alternative: stack counts permanently on pickup, and the Guardian only removes un-upgraded progress.
2. **Guardian targeting** — heaviest stack assumed. Alternatives: most Veritys, most value, or nearest player.
3. **IP** — Verity is ThatMob's character. Build original models and audio rather than reusing ripped assets, and decide whether the title uses the name as-is.
