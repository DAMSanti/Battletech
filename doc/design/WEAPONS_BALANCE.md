# Weapons Balance Analysis

## Overview
This document analyzes the weapons database for balance considerations. All data is extracted from `scripts/core/data/weapons_database.gd`.

## Key Metrics

### DPS/Weight (Damage Per Ton)
Higher is better for weight-efficient builds.

| Rank | Weapon | DPS/Weight | Notes |
|------|--------|------------|-------|
| 1 | Rocket Launcher 10 | 20.00 | One-shot only |
| 2 | Rocket Launcher 15 | 15.00 | One-shot only |
| 3 | Rocket Launcher 20 | 13.33 | One-shot only |
| 4 | Small Laser | 6.00 | Best sustainable |
| 5 | ER Small Laser | 6.00 | Extended range |
| 6 | Medium Laser | 5.00 | Workhorse |
| 7 | ER Medium Laser | 5.00 | Extended range |
| 8 | Machine Gun | 4.00 | No heat |
| 9 | Light MG | 4.00 | Lightest weapon |
| 10 | SRM-2/4/6 | 4.00 | Consistent |

### Heat Efficiency (Damage/Heat)
Higher is better for sustained combat.

| Rank | Weapon | Efficiency | Notes |
|------|--------|------------|-------|
| 1 | Gauss Rifle | 15.00 | Best overall |
| 2 | Heavy Gauss | 12.50 | High damage |
| 3 | Light Gauss | 8.00 | Long range |
| 4 | AC5/LB5X/UAC5 | 5.00 | Cool running |
| 5 | LB10X | 5.00 | Cluster option |
| 6 | MRM-30/40 | 3.33 | High volume |
| 7 | AC10/LB20X | 3.33 | Good balance |
| 8 | Small Laser | 3.00 | Energy efficient |
| 9 | SRM-6 | 3.00 | Close combat |
| 10 | LRM-15 | 3.00 | Long range |

### Machine Guns/Flamers
These weapons have infinite heat efficiency (0 heat generated).

## Category Analysis

### Energy Weapons
- **Best DPS/Weight**: Small Laser (6.00)
- **Best Range**: ER PPC (23 hexes)
- **Best Accuracy**: Pulse Lasers (-2 to-hit)
- **Best Heat Efficiency**: Light PPC (2.00)
- **Highest Alpha**: Heavy PPC (15 damage)

### Ballistic Weapons
- **Best DPS/Weight**: AC/20 (1.43)
- **Best Range**: AC/2, LB2X, UAC2 (27 hexes)
- **Best Heat Efficiency**: Gauss Rifle (15.00)
- **Highest Alpha**: Heavy Gauss (25 damage)
- **Special**: Ultra/Rotary can double/sextuple fire

### Missile Weapons
- **Best DPS/Weight**: SRM family (4.00)
- **Best Range**: LRM family (21 hexes)
- **Best Efficiency**: MRM family (varies)
- **Highest Alpha**: MRM-40 (40 potential damage)
- **Special**: Streak = no ammo waste, MML = flexible

## Balance Observations

### Well-Balanced Weapons
1. **Medium Laser** - The gold standard, good at everything
2. **AC/5** - Versatile with low heat
3. **SRM-6** - Excellent close combat option
4. **LRM-15** - Good balance of firepower and heat

### Potentially Overpowered
1. **Gauss Rifle** - 15 damage for 1 heat is exceptional
2. **Small Laser** - Very efficient for its weight
3. **Rocket Launchers** - One-shot alpha is massive
4. **Light PPC** - Same damage as PPC, half the heat

### Potentially Underpowered
1. **AC/2** - Low damage for weight, even with range
2. **Heavy PPC** - Same heat as ER PPC, less range
3. **Flamer** - Situational, low direct damage
4. **NARC** - Zero damage, requires team coordination

## Tech Base Comparison

### Inner Sphere (IS)
- More weapons available
- Generally heavier per damage point
- Standard lasers are efficient

### Clan
- ER lasers only in this database
- Same weight, more range
- More heat per shot

## Recommendations for Balance

### Consider Adjusting
1. **Gauss Rifle heat** - Could be 2-3 to balance
2. **AC/2 damage** - Could be 3 to improve viability
3. **Light PPC heat** - Could be 7 to differentiate from PPC
4. **Rocket Launchers** - One-shot nature may be enough balance

### Consider Adding
1. More Clan weapons for variety
2. ER versions of IS lasers
3. Snub-nose PPC variants
4. Artillery weapons

## Spreadsheet
See `WEAPONS_BALANCE.csv` for the complete data in spreadsheet format.

## Formulas Used
- **DPS/Weight** = Damage / Weight (tons)
- **Heat Efficiency** = Damage / Heat (∞ for 0 heat weapons)
- **For missiles**: Damage = missiles × damage per missile
