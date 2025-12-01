@tool
extends SceneTree
## Script para analizar cobertura de tests del core
## Uso: godot --headless -s tests/coverage_analyzer.gd

const CORE_PATHS := [
	"res://scripts/core/",
	"res://scripts/core/combat/",
	"res://scripts/core/movement/",
	"res://scripts/core/battle/",
]

const TEST_PATH := "res://tests/unit/"

var core_functions: Dictionary = {}  # {file: {func_name: line}}
var tested_functions: Dictionary = {}  # {file: [func_names]}
var coverage_results: Dictionary = {}


func _init() -> void:
	print("\n" + "═".repeat(60))
	print("📊 STEEL TITANS - CODE COVERAGE ANALYZER")
	print("═".repeat(60) + "\n")
	
	analyze_core_scripts()
	analyze_test_files()
	calculate_coverage()
	print_report()
	
	quit()


func analyze_core_scripts() -> void:
	print("🔍 Analyzing core scripts...")
	
	for path in CORE_PATHS:
		var dir := DirAccess.open(path)
		if not dir:
			continue
		
		dir.list_dir_begin()
		var file_name := dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".gd") and not file_name.ends_with(".uid"):
				var full_path: String = path + file_name
				extract_functions(full_path)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	var total_funcs := 0
	for file in core_functions:
		total_funcs += core_functions[file].size()
	
	print("   Found %d functions in %d core files\n" % [total_funcs, core_functions.size()])


func extract_functions(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	
	var functions: Dictionary = {}
	var line_num := 0
	
	while not file.eof_reached():
		line_num += 1
		var line := file.get_line().strip_edges()
		
		# Match function definitions
		if line.begins_with("func ") or line.begins_with("static func "):
			var func_name := extract_func_name(line)
			if func_name and not func_name.begins_with("_"):  # Skip private/built-in
				functions[func_name] = line_num
	
	if functions.size() > 0:
		core_functions[file_path] = functions


func extract_func_name(line: String) -> String:
	# "func my_function(...)" -> "my_function"
	var regex := RegEx.new()
	regex.compile(r"(?:static\s+)?func\s+(\w+)\s*\(")
	var result := regex.search(line)
	if result:
		return result.get_string(1)
	return ""


func analyze_test_files() -> void:
	print("🧪 Analyzing test files...")
	
	var dir := DirAccess.open(TEST_PATH)
	if not dir:
		print("   ERROR: Cannot open test directory")
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			analyze_test_file(TEST_PATH + file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	var total_tested := 0
	for file in tested_functions:
		total_tested += tested_functions[file].size()
	
	print("   Found %d tested function references\n" % total_tested)


func analyze_test_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	
	var content := file.get_as_text()
	
	# Find which core file this test is for
	for core_file in core_functions:
		var core_name: String = core_file.get_file().replace(".gd", "")
		var test_name: String = file_path.get_file().replace("test_", "").replace(".gd", "")
		
		# Check if test file matches core file
		if test_name == core_name or core_name.contains(test_name) or test_name.contains(core_name):
			if not tested_functions.has(core_file):
				tested_functions[core_file] = []
			
			# Find function calls in test
			for func_name in core_functions[core_file]:
				# Check various patterns for function calls
				if content.contains("." + func_name + "(") or \
				   content.contains(func_name + "(") or \
				   content.contains("." + func_name + " "):
					if func_name not in tested_functions[core_file]:
						tested_functions[core_file].append(func_name)


func calculate_coverage() -> void:
	for file_path in core_functions:
		var total: int = core_functions[file_path].size()
		var tested: int = 0
		var untested_funcs: Array = []
		
		if tested_functions.has(file_path):
			tested = tested_functions[file_path].size()
			
			# Find untested functions
			for func_name in core_functions[file_path]:
				if func_name not in tested_functions[file_path]:
					untested_funcs.append(func_name)
		else:
			for func_name in core_functions[file_path]:
				untested_funcs.append(func_name)
		
		var percentage := 0.0
		if total > 0:
			percentage = (float(tested) / float(total)) * 100.0
		
		coverage_results[file_path] = {
			"total": total,
			"tested": tested,
			"percentage": percentage,
			"untested": untested_funcs
		}


func print_report() -> void:
	print("═".repeat(60))
	print("📈 COVERAGE REPORT")
	print("═".repeat(60) + "\n")
	
	var overall_total := 0
	var overall_tested := 0
	
	# Sort by coverage percentage
	var sorted_files := coverage_results.keys()
	sorted_files.sort_custom(func(a, b): 
		return coverage_results[a]["percentage"] > coverage_results[b]["percentage"]
	)
	
	for file_path in sorted_files:
		var data: Dictionary = coverage_results[file_path]
		var file_name: String = file_path.get_file()
		var pct: float = data["percentage"]
		
		overall_total += data["total"]
		overall_tested += data["tested"]
		
		# Color coding
		var status := "🔴"
		if pct >= 80:
			status = "🟢"
		elif pct >= 50:
			status = "🟡"
		
		print("%s %s" % [status, file_name])
		print("   Coverage: %d/%d functions (%.1f%%)" % [data["tested"], data["total"], pct])
		
		if data["untested"].size() > 0 and data["untested"].size() <= 5:
			print("   Untested: %s" % ", ".join(data["untested"]))
		elif data["untested"].size() > 5:
			print("   Untested: %s... (+%d more)" % [
				", ".join(data["untested"].slice(0, 5)),
				data["untested"].size() - 5
			])
		print("")
	
	# Overall summary
	var overall_pct := 0.0
	if overall_total > 0:
		overall_pct = (float(overall_tested) / float(overall_total)) * 100.0
	
	print("═".repeat(60))
	print("📊 OVERALL COVERAGE: %d/%d functions (%.1f%%)" % [
		overall_tested, overall_total, overall_pct
	])
	print("═".repeat(60))
	
	# Target check
	if overall_pct >= 80:
		print("✅ Target reached! (>80%)")
	else:
		var needed := int(overall_total * 0.8) - overall_tested
		print("⚠️  Need %d more tested functions to reach 80%%" % needed)
	
	print("")


# Entry point
func _initialize() -> void:
	pass
