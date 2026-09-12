class_name EditionDisplay
extends RefCounted

# Coordinates returned here are framebuffer pixels. Native macOS points are
# converted once at window creation; drawing and mouse input use the same scale.
const BASE_UI:=Vector2(800,600)
const DEFAULT_WINDOW:=Vector2(1280,800)
const NAME_POINTS:=16
const BODY_POINTS:=14
const QUEST_TITLE_POINTS:=18
const HEALTH_BAR:=Vector2(58,5)

# Entry artwork and input rectangles share one continuous, aspect-preserving
# transform. The extra bottom space keeps two-line status messages off forms.
static func entry_zoom(pixels: Vector2) -> float:
	return maxf(0.1,minf(pixels.x/800.0,pixels.y/620.0))

# Automatic game scale follows the display density, never window-size buckets.
# Only oversized manual UI settings shrink continuously to keep controls on screen.
static func ui_zoom(pixels: Vector2,requested:=0,density:=1.0) -> float:
	var fit:=maxf(0.1,minf(pixels.x/BASE_UI.x,pixels.y/BASE_UI.y))
	var desired:=maxf(1,density) if requested==0 else float(clampi(requested,1,4))
	return minf(desired,fit)

static func map_zoom(_pixels: Vector2,requested:=0,density:=1.0) -> float:
	return float(clampi(requested,1,6)) if requested>0 else 2.0*maxf(1,density)

static func window_pixels(usable: Vector2,density: float,saved_points:=Vector2.ZERO) -> Vector2i:
	var desired:=saved_points if saved_points.x>=800 and saved_points.y>=600 else DEFAULT_WINDOW
	var available:=(usable-Vector2(40,64)*density).max(BASE_UI)
	return Vector2i((desired*density).min(available).round())

static func hud_x(original_x: float,width: float) -> float:
	if original_x<207:return original_x
	if original_x>=600:return original_x+width-800
	return original_x+floorf((width-800)/2)

static func restore_position(anchor: Vector2,bounds: Vector2,window_size: Vector2) -> Vector2:
	return ((bounds-window_size).max(Vector2.ZERO)*anchor.clamp(Vector2.ZERO,Vector2.ONE)).round()
