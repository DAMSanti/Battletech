# Loadout to Battle Integration

## Overview
This document explains how custom mech loadouts from the Mech Bay are integrated into the battle system.

## Flow

1. **Create/Edit Loadout** → Advanced Mech Bay (`mech_bay_ui.gd`)
   - User selects mech chassis (tonnage, engine rating)
   - Adds weapons, ammo, equipment to different body locations
   - Saves with custom name to `user://saved_loadouts.json`

2. **Select for Battle** → Mech Bay Screen (`mech_bay_screen.gd`)
   - User views saved loadouts
   - Clicks "SELECT FOR BATTLE" button
   - Calls `SelectedLoadoutManager.set_selected_loadout(loadout_data)`
   - Changes scene to `battle_scene_simple.tscn`

3. **Apply to Battle** → Battle Scene (`battle_scene.gd`)
   - `_setup_battle()` checks `SelectedLoadoutManager.has_loadout()`
   - If loadout exists: calls `_convert_loadout_to_mech_data(loadout)`
   - Conversion extracts:
     - Mech name, tonnage
     - Movement (walk_mp = engine_rating / tonnage)
     - Weapons from all locations
     - Jump jets count
     - Heat capacity based on heat sinks
   - Creates player mech with `_create_player_mech_from_data(mech_data)`

## Key Components

### SelectedLoadoutManager (Autoload)
**Path:** `scripts/managers/selected_loadout_manager.gd`

**Methods:**
- `set_selected_loadout(loadout_data: Dictionary)` - Store loadout for battle
- `get_selected_loadout() -> Dictionary` - Retrieve stored loadout
- `has_loadout() -> bool` - Check if valid loadout exists
- `clear_selection()` - Reset selection

### Loadout Format
```gdscript
{
  "mech_name": "Atlas Brawler",
  "mech_tonnage": 100,
  "engine_rating": 300,
  "heat_sinks": 10,
  "armor_weight": 0.0,
  "loadout": {
    GameEnums.MechLocation.RIGHT_ARM: [
      {
        "id": "ppc",
        "name": "PPC",
        "type": ComponentDatabase.ComponentType.WEAPON_ENERGY,
        "damage": 10,
        "heat": 10,
        "weight": 7.0,
        "critical_slots": 3,
        // ... more weapon data
      }
    ],
    // ... other locations
  }
}
```

### Battle Mech Data Format
```gdscript
{
  "name": "Atlas Brawler",
  "tonnage": 100,
  "walk_mp": 3,     # Calculated: engine_rating / tonnage
  "run_mp": 4,      # Calculated: walk_mp * 1.5
  "jump_mp": 2,     # Counted from jump jets in loadout
  "weapons": [      # Extracted from all locations
    {
      "id": "ppc",
      "name": "PPC",
      "damage": 10,
      "heat": 10,
      "location": GameEnums.MechLocation.RIGHT_ARM,
      // ... weapon data
    }
  ],
  "heat_capacity": 32,  # 30 base + (heat_sinks - 10)
  "gunnery_skill": 4,
  "armor": { /* default armor based on tonnage */ }
}
```

## Testing the Integration

### Test Steps:

1. **Create a Test Loadout:**
   - Run the game
   - Go to Advanced Mech Bay
   - Select a mech (e.g., Hunchback 50t, engine 200)
   - Add some weapons (e.g., AC/20 in right torso, Medium Lasers in arms)
   - Click "SAVE LOADOUT"
   - Enter name: "Test Brawler"

2. **Select for Battle:**
   - Go to Mech Bay (main menu → view saved loadouts)
   - Select "Test Brawler" from list
   - Click "SELECT FOR BATTLE"
   - Should transition to battle scene

3. **Verify in Battle:**
   - Check console output for:
     - `[BATTLE] Using selected loadout from Mech Bay`
     - `[BATTLE] Converted loadout with X weapons`
     - `[BATTLE] Created player mech: Test Brawler (50 tons)`
   - In battle, check if:
     - Mech name is correct
     - Movement matches engine/tonnage ratio
     - Weapons appear in attack menu
     - Heat capacity reflects heat sinks

### Expected Console Output:
```
[SelectedLoadoutManager] Loadout seleccionado: Test Brawler
[BATTLE] Using selected loadout from Mech Bay
[BATTLE] Converted loadout with 3 weapons
[BATTLE] Created player mech: Test Brawler (50 tons)
```

## Fallback Behavior

If no loadout is selected:
1. Checks `MechBayManager` for configured mechs
2. Uses default Atlas if no manager exists
3. Console shows: `[WARNING] MechBayManager not found, using default Atlas`

## Future Enhancements

### Pending Features:
- [ ] Armor configuration in loadout (currently uses default)
- [ ] Ammo tracking per location
- [ ] Critical hits to specific slots
- [ ] Equipment effects (ECM, BAP, CASE)
- [ ] Structure damage based on tonnage
- [ ] Clear selection after battle ends

### Known Limitations:
- Armor is generated with default values (~80% max)
- No ammo consumption tracking yet
- Equipment passive effects not applied
- Critical hits don't destroy specific components yet

## Code References

**Modified Files:**
- `scripts/battle_scene.gd` - Added loadout integration
- `scripts/ui/screens/mech_bay_screen.gd` - Added SELECT FOR BATTLE
- `scripts/managers/selected_loadout_manager.gd` - Created autoload
- `project.godot` - Registered SelectedLoadoutManager autoload

**Key Functions:**
- `battle_scene._setup_battle()` - Checks for selected loadout
- `battle_scene._convert_loadout_to_mech_data()` - Converts loadout format
- `battle_scene._generate_default_armor()` - Creates default armor
- `mech_bay_screen._on_select_for_battle_pressed()` - Saves selection

## Troubleshooting

**Problem:** Loadout not appearing in battle
- **Check:** Console for "Using selected loadout from Mech Bay"
- **Solution:** Ensure you clicked SELECT FOR BATTLE, not just edit

**Problem:** Wrong mech appears in battle
- **Check:** MechBayManager might override selection
- **Solution:** Verify `SelectedLoadoutManager.has_loadout()` returns true

**Problem:** Weapons missing in battle
- **Check:** Console for "Converted loadout with X weapons"
- **Solution:** Verify weapons were saved in loadout (not just ammo/equipment)

**Problem:** Movement speed incorrect
- **Check:** Engine rating and tonnage values
- **Solution:** Walk MP = engine_rating / tonnage (e.g., 200/50 = 4 walk, 6 run)
