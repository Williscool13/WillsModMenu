# PAYDAY 3 Settings screen: style reference

This file records how PAYDAY 3's own **Settings** screen is built, so Will's Mod
Menu can look like it. Every number here was measured from the running game.
The menu's implementation lives in `WillsModMenu/Scripts/screen.lua`. Its style
tables are `S` (sizes), `C` (colours) and `L` (screen layout); the tables below
name the matching key where one exists.

## Where the numbers come from

- **Widget values** (sizes, paddings, colours, fonts, asset paths): read from
  the game's live widget tree on the main menu's Settings screen, with a debug
  script that walked every widget and printed its properties (2026-11-20).
- **Screen positions** (the hint bar, sub-header spacing): measured from
  screenshots at 2560 × 1440, where the game's DPI scale is 1.333. They are
  converted to UMG units below.

## Conventions

| Topic | Rule |
|---|---|
| Units | UMG units: pixels on a 1920 × 1080 screen. At 2560 × 1440, 1 unit = 1.333 px. |
| Colours | Linear RGB (what UMG stores), **not** sRGB. Linear 0.5 looks much lighter than sRGB 0.5. Values are R, G, B and alpha A, from 0 to 1. |
| Paddings | `[left top right bottom]`. |
| Shear | `(-16, 0)` is the game's slant for tabs and the hint bar: a render-transform shear, so the box leans right. |
| Layout fractions | `L` entries are `{ x, y, width, height }` as fractions of the screen, so the layout scales with any resolution and aspect. |

## Font

| Use | Font asset | Typeface |
|---|---|---|
| Everything except the title | `/Game/UI/Assets/Fonts/Din_Pro/DINPro-CondMedium_Font` | `MediumPro` |
| Screen title | same asset | `BlackPro` |

Load the font by path. Borrowing it from an on-screen game label fails after a
UE4SS hot reload (the label is gone and the default font shows).

## Screen layout

The game's Settings screen, and the menu's version of it (`L` in `screen.lua`):

| Area | Menu position `{ x, y, w, h }` | Notes |
|---|---|---|
| Title | `{ 0.050, 0.050 }` | "MODS", top left. |
| Tab bar | `{ 0.205, 0.150, 0.39, 0.035 }` | The selected mod's sections. |
| Mod list | `{ 0.050, 0.240, 0.135, 0.5795 }` | The menu's own addition; the game has no list here. |
| MOD MENU SETTINGS button | `{ 0.050, 0.834, 0.135, 0.046 }` | Under the mod list. |
| Setting rows | `{ 0.205, 0.240, 0.39, 0.64 }` | Scrolls. |
| Description pane | `{ 0.625, 0.262, 0.33, 0.30 }` | The hovered row's text. |
| Description heading | `{ 0.625, 0.236 }` | The mod's name in capitals. |
| Hint bar | See [Hint bar](#hint-bar) | Bottom left. |

## Screen title (`WBP_ScreenTitle`)

| Part | Value | Menu key |
|---|---|---|
| Title text | `BlackPro` 34, letter spacing 1, uppercase, white | `S.title` |
| Underline | A 1 px line texture plus a "chunky" line 66 × 2, green, scale X 0.7 | |
| Underline green | (0.1384, 0.3325, 0.2159) | `C.titleGreen` |
| `//SELECTION OPEN//` | `MediumPro` 5, the same green | `S.selOpen` |

## Tab bar (`WBP_UI_NavBar`)

| Part | Value | Menu key |
|---|---|---|
| Band | Image black A 0.5, padding `[0 6 0 6]`, shear (-16, 0) | `C.tabBand` |
| End lines | Image 2 wide, white, padding `[0 6 4 6]` (left) / `[4 6 0 6]` (right), shear (-16, 0) | |
| Tab size (`WBP_UI_Widget_NavBarButton`) | SizeBox height 50, min width 150, max width 300 | `S.tabH`, `S.tabMinW` |
| Tab text | `MediumPro` 12, colour 0.9047 (grey-white), uppercase, ScaleBox padding `[25 5 25 5]` | `S.tab`, `C.tabText`, `S.tabPad` |
| Selected tab | Image (0.0242, 0.2462, 0.0931), padding `[0 6 0 6]`, shear -16, plus a 1 px white line (`1_Pixel_Line_Horizontal`) along the bottom, padding `[-6 0 6 0]` | `C.tabSel` |
| Hovered tab | Image (0.0232, 0.1195, 0.0561), same shape, plus a 2 px white line along the bottom | `C.tabHover` |

## Setting rows (all types)

| Part | Value | Menu key |
|---|---|---|
| Row height | 50 | `S.rowH` |
| Gap to the next row | 5 (a Spacer) | `S.rowGap` |
| Background | BackgroundBlur (strength 5 to 10) plus Image black A 0.5 | `C.rowBg` |
| Name | `MediumPro` 16, white, RenderOpacity 0.5 when not focused; ScaleBox padding `[7 0 375 0]`, vertically centred | `S.name`, `S.namePad` |
| Outline (focused row) | Image `Border_Image`, Box brush (margin 0.5), material `MM_UI_Border_Shader` (one dynamic instance per row) | `C.outline` |
| Value area | Right-aligned, 357 wide, Image white A 0.04 | `S.valueW`, `C.valueBg` |

The name does not change on hover; only the outline appears.

### Choice: `< value >`

| Part | Value | Menu key |
|---|---|---|
| Layout | `[SizeBox 35: arrow] [Overlay, padding [3 0 3 0]: value box] [SizeBox 35: arrow, right padding 1.5]` | `S.arrowW`, `S.inner` |
| Value box | Image white A 0.04, text `MediumPro` 16 centred, opacity 0.5 | `C.valueBg`, `S.value` |
| Arrow button (`WBP_MouseOnly_TextButton`) | Background white A 0.039; hover overlay white A 0.15; text `MediumPro` 16, white A 0.85, centred | `C.btnBg`, `C.btnHover` |

### On / Off (two choices)

| Part | Value |
|---|---|
| Layout | HBox padding `[0 1 0 1]`: `[SizeBox 177: option 1] [Spacer 3] [SizeBox 177: option 2]` |
| Each half | The same button as the choice arrows |

### Slider

| Part | Value | Menu key |
|---|---|---|
| Layout | HBox right-aligned, right padding 60: `[value text, padding [5 0 5 0], opacity 0.5] [SizeBox 200 × 50: Slider]` | `S.sliderW`, `S.sliderRight` |
| Bar | Colour (0.2346, 0.2502, 0.2462), BarThickness 5; bar images use `/Game/UI/Textures/UI_Tex_EmptySprite` | `C.sliderBar` |
| Thumb | `/Game/UI/Assets/TextureAssets/char_circle`, 15 × 15, white | |
| Hovered | Thumb 20 × 20; bar tinted orange (1, 0.1765, 0.0353) | `C.sliderHot` |

Build the slider style from these values. Copying `WidgetStyle` from a live
game slider found with `FindAllOf` crashed the game (the object can be stale).
The hovered-bar image must be tinted **white**: an orange tint on top of the
orange bar colour shows red.

## Sub-headers (`Settings_GroupTitle_C`)

Measured in the Video settings.

| Part | Value | Menu key |
|---|---|---|
| Text | `MediumPro` 16, uppercase, white at 50 % opacity (looks grey) | `S.section` |
| Background | None | |
| Position | Flush with the rows' left edge; about 13 above the text (from the row above) and 6 below it (to the next row) | `S.groupH` |

## Scroll list

| Part | Value |
|---|---|
| Scrollbar | Thickness 6, padding `[8 2 2 2]` |

## Hint bar

The bar at the bottom left with key hints (`[Esc] BACK`). Copy the **main-menu
Settings** bar. The heist pause menu's bar differs: it sits 6 px higher, is
slanted only about 4°, and has a dark rounded backing behind each key.

| Part | Value (main-menu Settings) | Menu key |
|---|---|---|
| Bar | Height 56, centred at 0.9319 of the screen height, black A 0.75, sheared -16 on the right end | `C.hintBg` |
| Orange strip | 4.5 wide, at the screen edge, drawn on top of the bar | `C.orange` |
| First keycap | 110 from the screen edge | |
| Spacing | 10 from a keycap to its label; 26 between hints; 28 after the last hint. The bar sizes to its hints. | |
| Label (`Text_DisplayText`) | `MediumPro` 12, white A 0.8 | `S.hint` |

### Keycap (`WBP_UI_InputKey`)

| Part | Value | Menu key |
|---|---|---|
| Sprite | PaperSprite `/Game/UI/Textures/Utility/SS_UI_Keyboard_PC_Empty`, drawn as Box (margin 0.01); white area 27; min size 32 × 32 | |
| Text | `MediumPro` 12, black, inside a ScaleBox (padding 5) that shrinks long names such as "Esc" | `S.hintKey` |

## Where the menu differs on purpose

| Element | Menu | Why |
|---|---|---|
| Backdrop | Near-black (0.004, 0.006, 0.005) A 0.90 over the whole screen | The menu sits on top of the game's menus, which must not show through. |
| Mod list | A framed scrolling list on the left, rows in the row style, selected entry in the tab green | The game has no equivalent; tabs across the top don't scale to many mods. |
| Faint outlines | Rows and the mod list get a faint outline (0.55 grey, A 0.28) | Separates rows on the flat backdrop. |
| Chosen On/Off half | White A 0.12 | Readable without the game's focus animation. |
| Typed fields (colour, text) | `MediumPro` 14 | `S.edit`: a little smaller than values, to fit inside the value area. |
| Hover | The outline appears on mouse hover | The game highlights the focused row (keyboard or gamepad). |

## Implementation rules learned the hard way

- **Build everything from plain UMG widgets** (Border, Image, TextBlock,
  Overlay, SizeBox, ScrollBox, Slider, EditableText). Creating the game's own
  Settings widgets (`WBP_Settings_*`, `WBP_ScreenTitle`) outside their screen
  crashed the game at the next level load.
- **Never copy structs or styles from live game widgets** found with
  `FindAllOf`. Rebuild them from the values above.
- **Geometry calls return zeros** in this UE4SS build (`GetCachedGeometry`,
  `LocalToAbsolute`, `GetLocalSize`). Measure from screenshots instead, and get
  the mouse with `WidgetLayoutLibrary:GetMousePositionOnViewport`.
- Colours in this file are linear. A colour picked from a screenshot (sRGB)
  needs converting before it goes into UMG.
