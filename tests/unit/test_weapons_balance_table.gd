extends GutTest
## Tests para WeaponsBalanceTable


func before_each() -> void:
	# Reset cache para tests limpios
	WeaponsBalanceTable.reset_cache()


func test_initialize_creates_balance_data_for_all_weapons() -> void:
	WeaponsBalanceTable.initialize()
	
	var all_data = WeaponsBalanceTable.get_all_balance_data()
	assert_gt(all_data.size(), 50, "Should have balance data for many weapons")


func test_get_balance_data_returns_valid_data() -> void:
	var data = WeaponsBalanceTable.get_balance_data("medium_laser")
	
	assert_not_null(data, "Should return data for medium_laser")
	assert_eq(data.name, "Medium Laser")
	assert_eq(data.damage, 5)
	assert_eq(data.heat, 5)
	assert_eq(data.category, "Energy")


func test_get_balance_data_returns_null_for_invalid_weapon() -> void:
	var data = WeaponsBalanceTable.get_balance_data("invalid_weapon_xyz")
	assert_null(data, "Should return null for invalid weapon")


func test_dps_per_weight_calculation() -> void:
	var data = WeaponsBalanceTable.get_balance_data("small_laser")
	
	# Small laser: 3 damage, 0.5 tons = 6.0 DPS/weight
	assert_eq(data.dps_per_weight, 6.0, "Small laser should have 6.0 DPS/weight")


func test_heat_efficiency_calculation() -> void:
	var data = WeaponsBalanceTable.get_balance_data("medium_laser")
	
	# Medium laser: 5 damage, 5 heat = 1.0 efficiency
	assert_eq(data.heat_efficiency, 1.0, "Medium laser should have 1.0 heat efficiency")


func test_heat_efficiency_infinite_for_zero_heat() -> void:
	var data = WeaponsBalanceTable.get_balance_data("machine_gun")
	
	# Machine gun has 0 heat
	assert_eq(data.heat_efficiency, INF, "Machine gun should have infinite heat efficiency")


func test_missile_damage_calculation() -> void:
	var srm6 = WeaponsBalanceTable.get_balance_data("srm6")
	
	# SRM-6: 2 damage x 6 missiles = 12 total
	assert_eq(srm6.damage, 12, "SRM-6 should have 12 total damage")


func test_get_by_category_filters_correctly() -> void:
	var energy_weapons = WeaponsBalanceTable.get_by_category("Energy")
	var ballistic_weapons = WeaponsBalanceTable.get_by_category("Ballistic")
	var missile_weapons = WeaponsBalanceTable.get_by_category("Missile")
	
	assert_gt(energy_weapons.size(), 10, "Should have many energy weapons")
	assert_gt(ballistic_weapons.size(), 10, "Should have many ballistic weapons")
	assert_gt(missile_weapons.size(), 10, "Should have many missile weapons")
	
	# Verify all are correct category
	for weapon in energy_weapons:
		assert_eq(weapon.category, "Energy", "All should be energy weapons")


func test_get_top_by_metric_returns_sorted() -> void:
	var top_dps = WeaponsBalanceTable.get_top_by_metric("dps_per_weight", 5)
	
	assert_eq(top_dps.size(), 5, "Should return 5 weapons")
	
	# Verify sorted in descending order
	for i in range(top_dps.size() - 1):
		assert_gte(top_dps[i].dps_per_weight, top_dps[i + 1].dps_per_weight,
			"Should be sorted descending by DPS/weight")


func test_get_top_by_damage() -> void:
	var top_damage = WeaponsBalanceTable.get_top_by_metric("damage", 3)
	
	assert_eq(top_damage.size(), 3, "Should return 3 weapons")
	assert_gte(top_damage[0].damage, top_damage[1].damage, "Should be sorted by damage")


func test_compare_weapons() -> void:
	var comparison = WeaponsBalanceTable.compare_weapons("medium_laser", "small_laser")
	
	assert_has(comparison, "damage_diff")
	assert_has(comparison, "heat_diff")
	assert_has(comparison, "overall_diff")
	assert_has(comparison, "winner")
	
	# Medium laser has more damage than small
	assert_eq(comparison.damage_diff, 2, "Medium laser has 2 more damage")


func test_compare_weapons_invalid_returns_empty() -> void:
	var comparison = WeaponsBalanceTable.compare_weapons("invalid_a", "invalid_b")
	assert_eq(comparison.size(), 0, "Should return empty for invalid weapons")


func test_get_weapons_in_range() -> void:
	var mid_tier = WeaponsBalanceTable.get_weapons_in_range(4.0, 6.0)
	
	for weapon in mid_tier:
		assert_gte(weapon.overall_score, 4.0, "Score should be >= 4.0")
		assert_lte(weapon.overall_score, 6.0, "Score should be <= 6.0")


func test_get_balance_report_generates_string() -> void:
	var report = WeaponsBalanceTable.get_balance_report()
	
	assert_string_contains(report, "WEAPONS BALANCE REPORT")
	assert_string_contains(report, "TOP 5 DPS/WEIGHT")
	assert_string_contains(report, "TOP 5 HEAT EFFICIENCY")
	assert_string_contains(report, "BY CATEGORY")


func test_export_to_csv_format() -> void:
	var csv = WeaponsBalanceTable.export_to_csv()
	
	# Should have header
	assert_string_contains(csv, "ID,Name,Category")
	assert_string_contains(csv, "DPS/Weight")
	
	# Should have data rows
	assert_string_contains(csv, "medium_laser")
	assert_string_contains(csv, "ac20")


func test_get_balance_warnings_returns_array() -> void:
	var warnings = WeaponsBalanceTable.get_balance_warnings()
	
	assert_typeof(warnings, TYPE_ARRAY, "Should return an array")
	
	# Check warning structure if any exist
	if warnings.size() > 0:
		var warning = warnings[0]
		assert_has(warning, "weapon")
		assert_has(warning, "issue")
		assert_has(warning, "value")
		assert_has(warning, "severity")


func test_special_abilities_detection() -> void:
	# Pulse laser should have to-hit modifier
	var pulse = WeaponsBalanceTable.get_balance_data("medium_pulse_laser")
	assert_string_contains(pulse.special, "-2 To-Hit")
	
	# PPC should have min range
	var ppc = WeaponsBalanceTable.get_balance_data("ppc")
	assert_string_contains(ppc.special, "Min Range")
	
	# UAC should have ultra
	var uac = WeaponsBalanceTable.get_balance_data("uac5")
	assert_string_contains(uac.special, "Ultra")
	
	# Streak should have streak
	var streak = WeaponsBalanceTable.get_balance_data("streak_srm2")
	assert_string_contains(streak.special, "Streak")


func test_overall_score_is_reasonable() -> void:
	var all_data = WeaponsBalanceTable.get_all_balance_data()
	
	for weapon in all_data:
		# Overall score should be between 0 and 10
		assert_gte(weapon.overall_score, 0.0, 
			"%s score should be >= 0" % weapon.name)
		assert_lte(weapon.overall_score, 10.0, 
			"%s score should be <= 10" % weapon.name)


func test_to_dictionary_contains_all_fields() -> void:
	var data = WeaponsBalanceTable.get_balance_data("ac10")
	var dict = data.to_dictionary()
	
	assert_has(dict, "id")
	assert_has(dict, "name")
	assert_has(dict, "category")
	assert_has(dict, "damage")
	assert_has(dict, "heat")
	assert_has(dict, "dps_per_weight")
	assert_has(dict, "heat_efficiency")
	assert_has(dict, "overall_score")


func test_cache_prevents_reinitialization() -> void:
	WeaponsBalanceTable.initialize()
	var first_data = WeaponsBalanceTable.get_balance_data("medium_laser")
	
	# Calling initialize again should not recreate
	WeaponsBalanceTable.initialize()
	var second_data = WeaponsBalanceTable.get_balance_data("medium_laser")
	
	assert_eq(first_data, second_data, "Should return same cached instance")
