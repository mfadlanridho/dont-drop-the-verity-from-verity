"""Pacing model for the upgrade and rebirth economy (M-03, M-04).

Simulates one player doing collect-to-bank trips and buying upgrades, and
reports when the first upgrade and each rebirth land. Targets: first upgrade
within 2 minutes, first rebirth in 20 to 30 minutes.

The economy numbers mirror src/shared/Config (Upgrades, Stack, Verity,
and Rebirth once M-04 adds it) and src/shared/Economy.luau; keep them in step by hand. The MAP numbers are guesses until Q-01
times real trips: retune them first, then the curves.

    python3 tools/economy_sim.py
"""

import math

# --- Mirrors src/shared/Config -------------------------------------------
UPGRADES = {
    # id: (base cost, growth per level, max level)
    "Capacity": (10, 1.22, 40),
    "Speed": (25, 1.45, 10),
    "Magnet": (20, 1.45, 10),
    "Multiplier": (50, 2.00, 9),
}
REBIRTH_BASE_COST = 1200
REBIRTH_COST_GROWTH = 5.0
REBIRTH_BANK_BONUS = 0.5  # GDD 4.7: +50% banked per rebirth

BASE_CAPACITY, CAPACITY_PER_LEVEL = 10, 5
BASE_SPEED, SPEED_PER_LEVEL = 16, 1
PENALTY_PER_WEIGHT, MAX_PENALTY = 0.01, 0.4
BASE_RADIUS, RADIUS_PER_LEVEL = 6, 2
MULTIPLIER_PER_LEVEL = 1
# Zone a player farms at each rebirth count (GDD 4.8), and the average value
# and weight of a pickup there: Zone1 Normal; Zone2 Normal and Golden, even
# split; Zone3 Golden and Corrupted, even split.
ZONE_UNLOCK_REBIRTHS = (0, 1, 3)
ZONE_PICKUP = ((1, 1), (3, 2), (15, 6.5))  # (value, weight)

# --- Map assumptions (not measured) --------------------------------------
PICKUP_SPACING = 30   # studs between neighbouring pickups on a collecting route
MIN_STEP = 4          # studs walked per pickup however large the magnet is
TRAVEL_ONE_WAY = 100  # studs between the bank and the pickups, per floor climbed
RETURN_PAD = 8        # seconds from an upper floor back to the bank by return pad
OVERHEAD = 5          # seconds per trip spent banking and shopping
REFILL_PER_SECOND = 2 # zone refill; a solo player cannot collect faster

# --- Guardian assumptions (not measured; Q-02 should give the hit rate) ----
# A hit drops the whole stack (GDD 4.5). Stacks under MIN_TARGET_WEIGHT are
# never hunted.
MIN_TARGET_WEIGHT = 5
HIT_CHANCE = (0.15, 0.25, 0.35)  # chance a hunted trip is hit, per floor
RECOVERED = 0.5                  # share of a dropped stack picked back up
RECOVERY_SECONDS = 10            # time spent picking it back up


def cost(upgrade, level):
    """Price of going from `level` to `level + 1`."""
    base, growth, _ = UPGRADES[upgrade]
    return round_price(base * growth ** level)


def round_price(value):
    """Two significant digits above 100, so prices read cleanly."""
    if value < 100:
        return math.floor(value + 0.5)
    magnitude = 10 ** (math.floor(math.log10(value)) - 1)
    return math.floor(value / magnitude + 0.5) * magnitude


def rebirth_cost(rebirths):
    return round_price(REBIRTH_BASE_COST * REBIRTH_COST_GROWTH ** rebirths)


def trip(levels, rebirths):
    """(seconds, banked) for an average full collect-to-bank trip."""
    capacity = BASE_CAPACITY + levels["Capacity"] * CAPACITY_PER_LEVEL
    speed = BASE_SPEED + levels["Speed"] * SPEED_PER_LEVEL
    radius = BASE_RADIUS + levels["Magnet"] * RADIUS_PER_LEVEL
    multiplier = 1 + levels["Multiplier"] * MULTIPLIER_PER_LEVEL
    zone = sum(1 for needed in ZONE_UNLOCK_REBIRTHS if rebirths >= needed)
    value, weight = ZONE_PICKUP[zone - 1]

    # Capacity is a weight limit; a pickup that does not fit is left behind.
    pickups = math.floor(capacity / weight)
    carried = pickups * weight
    step = max(PICKUP_SPACING - radius, MIN_STEP)
    full_penalty = min(carried * PENALTY_PER_WEIGHT, MAX_PENALTY)
    # The stack grows while collecting, so the average penalty is half the final one.
    collect = pickups * step / (speed * (1 - full_penalty / 2))
    collect = max(collect, pickups / REFILL_PER_SECOND)
    out = TRAVEL_ONE_WAY * zone / speed
    back = TRAVEL_ONE_WAY / (speed * (1 - full_penalty)) if zone == 1 else RETURN_PAD
    # Multiplier and the rebirth bonus both scale banked value, not weight.
    banked = math.floor(pickups * value * multiplier * (1 + REBIRTH_BANK_BONUS * rebirths))
    seconds = collect + out + back + OVERHEAD

    # Expected cost of the Guardian, averaged over many trips.
    if carried >= MIN_TARGET_WEIGHT:
        hit = HIT_CHANCE[zone - 1]
        banked *= 1 - hit * (1 - RECOVERED)
        seconds += hit * RECOVERY_SECONDS
    return seconds, banked


def rate(levels, rebirths):
    seconds, banked = trip(levels, rebirths)
    return banked / seconds


def simulate(rebirth_goal=3, verbose=True):
    clock, banked, rebirths = 0.0, 0, 0
    levels = {name: 0 for name in UPGRADES}
    first_upgrade = None
    last_rebirth = 0.0
    results = []

    while rebirths < rebirth_goal and clock < 6 * 3600:
        seconds, earned = trip(levels, rebirths)
        clock += seconds
        banked += earned

        goal = rebirth_cost(rebirths)
        if banked >= goal:
            results.append((rebirths + 1, clock, clock - last_rebirth, dict(levels), goal))
            last_rebirth = clock
            banked, rebirths = 0, rebirths + 1
            levels = {name: 0 for name in UPGRADES}
            continue

        # Buy the affordable upgrade that pays for itself soonest, as long as it
        # does so before the rebirth would be reached anyway.
        while True:
            now = rate(levels, rebirths)
            time_left = (goal - banked) / now
            best, best_payback = None, None
            for name, (_, _, cap) in UPGRADES.items():
                if levels[name] >= cap:
                    continue
                price = cost(name, levels[name])
                if price > banked:
                    continue
                trial = dict(levels, **{name: levels[name] + 1})
                gain = rate(trial, rebirths) - now
                if gain <= 0:
                    continue
                payback = price / gain
                if payback < time_left and (best is None or payback < best_payback):
                    best, best_payback = name, payback
            if best is None:
                break
            banked -= cost(best, levels[best])
            levels[best] += 1
            if first_upgrade is None:
                first_upgrade = clock

    if verbose:
        seconds, earned = trip({name: 0 for name in UPGRADES}, 0)
        print(f"Average first trip: {seconds:.0f}s for {earned:.1f} banked ({earned / seconds * 60:.0f}/min)")
        print(f"First upgrade at {first_upgrade / 60:.1f} min")
        for number, at, took, final, goal in results:
            built = ", ".join(f"{name} {level}" for name, level in final.items())
            print(f"Rebirth {number} (cost {goal}): at {at / 60:.1f} min, took {took / 60:.1f} min; {built}")
    return first_upgrade, results


def print_tables(rows=12):
    for name, (_, _, cap) in UPGRADES.items():
        print(f"\n{name} (max level {cap})")
        print("level   cost  cumulative")
        total = 0
        for level in range(min(rows, cap)):
            price = cost(name, level)
            total += price
            print(f"{level + 1:>5}  {price:>5}  {total:>10}")
    print("\nRebirth costs:", ", ".join(str(rebirth_cost(n)) for n in range(6)))


if __name__ == "__main__":
    simulate()
    print_tables()
