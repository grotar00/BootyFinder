# ==============================================================================
extends Control

# ==============================================================================
# Initializing scene elements
onready var Scan = $Start/Scan
onready var Open = $IO/Open
onready var DirPath = $IO/LineEdit
onready var Paste = $IO/Paste
onready var Subs = $IO/Subs
onready var Info = $Info/RichTextLabel
onready var Screen = $Info/Screen
onready var Export = $Info/Export
onready var New = $Reference/New
onready var Add = $Reference/Add
onready var Grid = $Thumbnails/Container
onready var Dialog = $FileDialog

# Global variables
var Files := []			# [[Path, MD5],..]
var Refs := []			# [MD5,..]
var Uniques := []		# [Path,..]
var errors := 0			# Times failed to acquire hash sum
var PATH := ""			# Collection directory
var APPDIR := ""		# Application directory
var SCAN = false		# Proceed with scan while true (emergency stop)
var subfolders = true	# Whether scan nested folders
var RefName = "__HASHES.txt"		# MD5 reference file for processing
var RefNameNew = "__HASHES_NEW.txt"	# New MD5 reference file
# List of readable extensions (some media won't be displayed)
var Extensions = [	"jpg", "jpeg", "png", "tga", "tif", "tiff", "bmp", "gif",
					"apng", "webp", "webm", "mp4", "swf"]

# ==============================================================================
# [>>>] Application start
func _ready():
	# Align grid for thumbnails display
	Grid.rect_size = Grid.get_parent().rect_size - Vector2(10, 10)
	
	# Application folder
	PATH = FixPath(OS.get_executable_path().get_base_dir())
	APPDIR = PATH
	Dialog.current_dir = APPDIR
	Dialog.current_path = APPDIR
	
	# Display current folder
	DirPath.text = PATH
	
	# Start listing files from current folder (recursive call if has sub)
	Scan.connect("pressed", self, "ScanForUniqueFiles")
	Scan.connect("mouse_entered", DirPath, "release_focus")
	
	# Pick folder manually
	Open.connect("pressed", Dialog, "popup")
	
	# Apply new folder from file dialog
	Dialog.connect("dir_selected", self, "ChangeFolder")
	
	# Apply new path on input
	DirPath.connect("text_changed", self, "ChangeFolder", [false])
	
	# Paste path from clipboard
	Paste.connect("pressed", self, "GetClipboard")
	
	# Toggle subfolders scan
	Subs.connect("pressed", self, "ToggleSubfolders")
	Subs.connect("pressed", Subs, "release_focus")
	
	# Save window screenshot
	Screen.connect("pressed", self, "SaveScreenshot")
	
	# Copy unique files to separate folder
	Export.connect("pressed", self, "ExportCopies")
	
	# Generate new MD5 reference
	New.connect("pressed", self, "GenerateReference", [0])
	
	# Add to existing MD5 reference
	Add.connect("pressed", self, "GenerateReference", [1])
	
	FindReference()

# ==============================================================================
# Duplicate all found images in "../__BOOTY/" folder
func ExportCopies():
	if Uniques.size() == 0:
		return
	
	elif Uniques.size() >= 300:
		Print("List contains more than 300 files, please consider packing whole folder")
		Export.disabled = true
		Export.modulate = Color.white
		return
	
	Print(	["Creating copies of ", Uniques.size(), " listed files..."],
			[null],
			[0,4])
	
	yield(get_tree().create_timer(.03), "timeout")
	var dir = Directory.new()
	dir.make_dir(APPDIR + "__BOOTY\\")
	for file in Uniques:
		var new_path = APPDIR + "__BOOTY\\" + file.get_file()
		dir.copy(file, new_path)
	
	Export.text = "DONE!"
	Print(	["All listed files duplicated to a ", "\"__BOOTY\"",
			" folder within application directory, you can zip and share it now"],
			[null, Color.dodgerblue])
	yield(get_tree().create_timer(1), "timeout")
	Export.text = "EXPORT"
	Export.disabled = true
	Export.modulate = Color.white

# ==============================================================================
# Create window screenshot with all the thumbnails
func SaveScreenshot():
	DirPath.secret = true
	yield(get_tree().create_timer(.03), "timeout")
	var capture = get_viewport().get_texture().get_data()
	
	capture.flip_y()
	capture.save_png(APPDIR + "__IMAGES.png")
	DirPath.secret = false
	
	Print(	["File ", "\"__IMAGES.png\"", " created within application directory, ",
			"please send it to according channel for analysis"],
			[null, Color.greenyellow])
	
# ==============================================================================
# Find __HASHES.txt file with list of MD5 to compare with
func FindReference():
	# Check if file exists
	var dir = Directory.new()
	if dir.file_exists(PATH + RefName):
		var file = File.new()
		# Open it and get list of all hash sums
		file.open(PATH + RefName, File.READ)
		Refs = file.get_as_text().split("\n")
		Print(	["Reference file initialized with ", Refs.size(), " entries",
				". Enter your collection's path in the field above and press ",
				"SCAN"],
				[null, Color.lightblue, null, null, Color.lightgreen],
				[0,4,0,0,2])
	# Disable application and show warning
	else:
		Scan.disabled = true
		Open.disabled = true
		Print(	["Cannot find ", "\"__HASHES.txt\"", " reference file.",
				"   Please find it and reload application"],
				[null, Color.red],
				[0,2])

# ==============================================================================
# Add MD5 from current folder to existing __HASHES_NEW if mode == 1
# Create new one if mode == 1 and file not found or mode == 0
func GenerateReference(mode):
	Print([	"[Please wait if application doesn't respond]",
			" Searching..."],
			[Color(.3,.45,.45), Color.white],
			[1,2])
	yield(get_tree().create_timer(.3), "timeout")
	
	# Get list of all files within directory
	SCAN = true
	UpdateFileList(PATH)
	CalculateMD5()
	var NewData = ExportFilesMD5()
	SCAN = false
	
	# Check if reference file exists
	var dir = Directory.new()
	var file = File.new()
	var output = ""
	# Yes
	if mode and dir.file_exists(APPDIR + RefNameNew):
		file.open(APPDIR + RefNameNew, File.READ)
		var MayHaveDupes = file.get_as_text().split("\n")
		file.close()
		# Remove duplicate entries from imported file
		var Data = []
		for i in MayHaveDupes:
			if !i in Data:
				Data.append(i)
		# Combine reference list with files in current folder
		var new_entries_count = 0
		for i in NewData:
			if !i in Data:
				Data.append(i)
				new_entries_count += 1
		# Remove empty entries
		Data.erase("")
		# Generate text file
		for i in Data:
			output += i + "\n"
		output = output.trim_suffix("\n")
		# Notification
		Print([	"Scanned ", NewData.size(), " files. Added ", new_entries_count,
				" entries to ", "\"__HASHES_NEW.txt\"",
				" with total of ", Data.size(), " entries"],
				[null, Color.aquamarine, null, Color.aquamarine, null,
				Color.cadetblue, null, Color.aquamarine],
				[0,4,0,4,0,0,0,4])
	# No
	else:
		# Generate text file
		var DupeFree = []
		for i in NewData:
			if !i in DupeFree:
				DupeFree.append(i)
		for i in DupeFree:
			output += i + "\n"
		output = output.trim_suffix("\n")
		# Notification
		if DupeFree.size() < NewData.size():
			Print([	"Created new ", "\"__HASHES_NEW.txt\"", " list with ",
					DupeFree.size(), " entries   (",
					NewData.size() - DupeFree.size(),
					" dupes ignored)"],
					[null, Color.cadetblue, null, Color.aquamarine,
					null, Color.aquamarine],
					[0,0,0,4,0,4])
		else:
			Print([	"Created new ", "\"__HASHES_NEW.txt\"", " list with ",
					DupeFree.size(), " entries"],
					[null, Color.cadetblue, null, Color.aquamarine],
					[0,0,0,4])
	
	file.open(APPDIR + RefNameNew, File.WRITE_READ)
	file.store_string(output)
	file.close()
	# Reset arrays for new scan
	Files = []
	Refs = []
	Uniques = []
	errors = 0

# ==============================================================================
# Get new path from clipboard
func GetClipboard():
	# Get clipboard content
	var clip = OS.get_clipboard()
	
	# If is valid path
	if clip.get_base_dir():
		ChangeFolder(clip)
	else:
		Paste.text = "WRONG PATH"
		Paste.modulate = Color(1.2,0.9,0.9)
		yield(get_tree().create_timer(1), "timeout")
		Paste.text = "CLIPBOARD>"
		Paste.modulate = Color.white

# ==============================================================================
# Change path to images folder
func ChangeFolder(folder, update_line=true):
	# If not valid path
	if !folder.get_base_dir():
		return
	PATH = FixPath(folder)
	
	if update_line:
		DirPath.text = PATH

# ==============================================================================
# Add "\" in the end of path
func FixPath(path):
	if path[-1] != "\\":
		return path + "\\"
	return path

# ==============================================================================
# Main sequence
func ScanForUniqueFiles():
	SCAN = !SCAN

	if SCAN:
		Scan.text = "STOP"
		Scan.modulate = Color(1.2,0.9,0.9)
	else:
		Cancel()
		Scan.text = "SCAN"
		Scan.modulate = Color(0.9,1.2,0.9)
		return
		
	# Clean file list on first scan
	Files = []
	
	# Disable screenshot button
	Screen.disabled = true
	Screen.modulate = Color.white
	Export.disabled = true
	Export.modulate = Color.white
	
	# Update message
	Print([	"[Please wait if application doesn't respond]",
			" Listing files..."],
			[Color(.3,.45,.45), Color.white],
			[1,2])
	yield(get_tree().create_timer(.5), "timeout")
	
	# Proceed with scan
	if SCAN: UpdateFileList(PATH)
	else: Cancel()
	
	# Update message
	Print([	"[Please wait if application doesn't respond] ",
			"Calculating hash sums for ", Files.size(),
			" found files, it may take up to ",
			10 + Files.size() / 50, "s..."],
			[Color(.3,.45,.45), Color.white],
			[1,2,6,2,6,2])
	yield(get_tree().create_timer(.5), "timeout")
	
	# Get hash sums
	if SCAN: CalculateMD5()
	else: Cancel()
	
	# Find all unlisted files
	if SCAN: FindUniques()
	else: Cancel()
	
	Print([	"[Please wait if application doesn't respond]",
			" Generating thumbnails..."],
			[Color(.3,.45,.45), Color.white],
			[1,2])
	yield(get_tree().create_timer(.5), "timeout")
	
	if SCAN: ShowThumbnails()
	else: Cancel()

# ==============================================================================
# Display found images as grid of previews
func ShowThumbnails():
	# Clear all thumbnails
	for child in Grid.get_children():
		child.queue_free()
	
	var max_size = 48.0
	if Uniques.size() < 30:
		max_size = 120.0
	elif Uniques.size() < 50:
		max_size = 100.0
	elif Uniques.size() < 75:
		max_size = 96.0
	elif Uniques.size() < 100:
		max_size = 84.0
	elif Uniques.size() < 180:
		max_size = 64.0
	elif Uniques.size() < 240:
		max_size = 56.0
	var gap = 3
	
	var hpos = 0
	var vpos = 0
	var count = 0
	
	# For each unique image
	for file in Uniques:
		if !SCAN:
			Cancel()
			return
		
		# Create new texture button and load image to it
		var thumb = Thumbnail.new()
		var img = ImageTexture.new()
		
		img.load(file)
		
		if img:
			count += 1
			
			# Get size modifier to fit image in row
			var dim = img.get_size()
			var zoom = 1.0
			if dim.y > max_size:
				zoom = max_size / dim.y
				img.set_size_override(dim * zoom)
				img.set_flags(3)
			thumb.texture_normal = img
			thumb.img_path = file
			
			# Set new position
			if hpos + dim.x * zoom >= Grid.rect_size.x:
				hpos = 0
				vpos += max_size + gap
			thumb.rect_position.x = hpos
			thumb.rect_position.y = vpos
			hpos += dim.x * zoom + gap
			
			if vpos > 625 - max_size or count > 300:
				break
			
			# Add to scene
			Grid.add_child(thumb)
	
	if !SCAN:
		Cancel()
		return
	
	if vpos >= 625 - max_size or count > 300:
		Print([	Files.size(), " files scanned, ",
				Uniques.size(), " unique images found",
				"     (Too much pictures, displaying first 300)"],
				[Color.greenyellow, null, Color.lightblue, null, Color.red],
				[4,0,4])
	elif !errors:
		Print([	Files.size(), " files scanned, ",
				Uniques.size(), " unique images found"],
				[Color.greenyellow, null, Color.lightblue],
				[4,0,4])
	else:
		Print([	Files.size(), " files scanned with ",
				errors, " errors, ",
				Uniques.size(), " unique images found"],
				[Color.greenyellow, null, Color.red, null, Color.lightblue],
				[4,0,4,0,4])
	
	if Uniques.size() > 0:
		Screen.disabled = false
		Screen.modulate = Color(0.9, 1.2, 0.9)
		Export.disabled = false
		Export.modulate = Color(0.9, 0.9, 1.2)
	
	# Scan complete
	SCAN = false
	Scan.text = "SCAN"
	Scan.modulate = Color(0.9,1.2,0.9)

# ==============================================================================
# Get names of files which have MD5 not listed in reference list
func FindUniques():
	Uniques = []
	for i in Files.size():
		if !SCAN: return
		if !Files[i][1] in Refs:
			Uniques.append(Files[i][0])

# ==============================================================================
# Create references list
func ExportFilesMD5():
	# Make new array for only MD5
	var md5_list = []
	
	# Add hash sum of each file
	for i in Files.size():
		md5_list.append(Files[i][1])
	md5_list.sort()

	return md5_list
	
# ==============================================================================
# Extract hash-sum from file
func CalculateMD5():
	var file = File.new()
	for i in Files.size():
		if !SCAN: return
		var file_hash = file.get_md5(Files[i][0])
		Files[i].append(file_hash)
	
	# Show number of files unable to get MD5 for
	errors = 0
	for i in Files:
		if !i[1]:
			errors += 1

# ==============================================================================
# Creates an array of all filenames in current folder and subfolders
func UpdateFileList(path):
	# Create parser
	var dir := Directory.new()
	
	# Add "\" in the end of path
	path = FixPath(path)
	
	# Open current directory
	if dir.open(path) != OK:
		Print("Cannot open this directory", Color.red)
		return
	
	# Begin the search
	if dir.list_dir_begin(true) != OK:
		Print("Cannot list files in this directory", Color.red)
		return
	
	# Do until all filenames are listed
	var file_name = dir.get_next()
	while file_name:
		if !SCAN:
			Cancel()
			return
		# If is folder
		if dir.current_is_dir() and subfolders:
			UpdateFileList(path + file_name)	# Recursion
		# If is file and has image extension
		elif file_name.get_extension().to_lower() in Extensions:
			Files.append([path + file_name])
		# Get name of next file
		file_name = dir.get_next()
	dir.list_dir_end()

# ==============================================================================
# Stop scan
func Cancel():
	Files = []
	Uniques = []
	errors = 0
	Screen.disabled = true
	Screen.modulate = Color.white
	Export.disabled = true
	Export.modulate = Color.white
	SCAN = false
	Print("Scan was cancelled")

# ==============================================================================
# Toggle subfolders scanning flag
func ToggleSubfolders():
	subfolders = Subs.pressed

# ==============================================================================
# Display text on second panel
func Print(strings="", colors=Color.white, styles=0):
	Info.clear()
	if !typeof(strings) == TYPE_ARRAY:
		strings = [strings]
	if !typeof(colors) == TYPE_ARRAY:
		colors = [colors]
	if !typeof(styles) == TYPE_ARRAY:
		styles = [styles]
	for i in strings.size():
		if colors.size() - 1 >= i and colors[i]:
			Info.push_color(colors[i])
		else:
			Info.push_color(Color.white)
		if styles.size() - 1 >= i and styles[i]:
			match styles[i]:
				0: Info.push_normal()
				1: Info.push_italics()
				2: Info.push_bold()
				3:
					Info.push_italics()
					Info.push_bold()
				4: Info.push_underline()
				5:
					Info.push_italics()
					Info.push_underline()
				6:
					Info.push_bold()
					Info.push_underline()
		else:
			Info.push_normal()
		Info.add_text(str(strings[i]))
		Info.pop()
		if styles.size() - 1 >= i and styles[i] in [3, 5, 6]:
			Info.pop()
