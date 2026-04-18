class_name SKTheme
extends Resource
## RPG-specific theme resource wrapping Godot's [Theme] with
## standardized design tokens for consistent game UI styling.
##
## Provides color palette, font slots, animation timing, and
## style overrides that the consuming project fills in.


@export_category("Godot Theme")
## The base Godot [Theme] resource. Widget contracts apply this automatically.
@export var base_theme:Theme

@export_category("Color Palette")
## Primary UI color (headers, highlights).
@export var color_primary:Color = Color("e0d8c0")
## Secondary UI color (subtext, borders).
@export var color_secondary:Color = Color("8a8070")
## Accent color (interactive elements, selection).
@export var color_accent:Color = Color("d4a44a")
## Health bar / health-related elements.
@export var color_health:Color = Color("c03030")
## Stamina bar / stamina-related elements.
@export var color_stamina:Color = Color("30a030")
## Magicka bar / magicka-related elements.
@export var color_magicka:Color = Color("3050c0")
## Damage number color.
@export var color_damage:Color = Color("ff4444")
## Heal number color.
@export var color_heal:Color = Color("44ff44")

@export_category("Font Slots")
## Heading font (menu titles, section headers).
@export var font_heading:Font
## Body text font (descriptions, dialogue).
@export var font_body:Font
## Monospace font (debug, console).
@export var font_mono:Font
## Damage/heal floating number font.
@export var font_damage_numbers:Font

@export_category("Animation Timing")
## Duration for fade transitions (seconds).
@export var fade_duration:float = 0.2
## Duration for slide transitions (seconds).
@export var slide_duration:float = 0.3
## Scale factor for popup open animation.
@export var popup_scale:float = 0.9
## Duration for tooltip appearance (seconds).
@export var tooltip_delay:float = 0.4

@export_category("Styles")
## StyleBox for panel backgrounds.
@export var panel_style:StyleBox
## StyleBox for tooltip backgrounds.
@export var tooltip_style:StyleBox
## StyleBox for list item backgrounds.
@export var list_item_style:StyleBox
## StyleBox for list item hover state.
@export var list_item_hover_style:StyleBox
## StyleBox for list item selected state.
@export var list_item_selected_style:StyleBox
## StyleBox for stat row backgrounds.
@export var stat_row_style:StyleBox
