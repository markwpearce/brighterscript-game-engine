---
title: BGE/Debug
kind: namespace
longname: BGE/Debug
---

# BGE/Debug

**Alias:** `BGE.Debug`

---

## Other

<MemberHeading id="debugoptions" depth="3" name="DebugOptions" sig="DebugOptions" />

<MemberMeta badges="static" />

**Properties**

- `draw_colliders` (boolean)
- `draw_collider_names` (boolean)
- `draw_safe_zones` (boolean)
- `colliders_color` (dynamic)
- `safe_action_zone_color` (dynamic)
- `safe_title_zone_color` (dynamic)
- `limit_frame_rate` (integer)
- `show_debug_ui` (boolean)
- `draw_debugUi_to_screen` (boolean)
- `draw_entity_axes` (boolean)
- `draw_entity_names` (boolean)
- `draw_scene_object_normals` (boolean)

**Returns**

- `BGE.Debug.DebugOptions`

<MemberHeading id="debugwindow" depth="3" name="DebugWindow" sig="DebugWindow" />

<MemberMeta badges="static" />

**Extends:&#x20;**`BGE.UI.UiContainer`

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Returns**

- `BGE.Debug.DebugWindow`

<MemberHeading id="fpsdisplay" depth="3" name="FpsDisplay" sig="FpsDisplay" />

<MemberMeta badges="static" />

**Extends:&#x20;**`DebugWindow`

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Properties**

- `fps` (integer)

**Returns**

- `BGE.Debug.FpsDisplay`

<MemberHeading id="garbagecollectordisplay" depth="3" name="GarbageCollectorDisplay" sig="GarbageCollectorDisplay" />

<MemberMeta badges="static" />

**Extends:&#x20;**`DebugWindow`

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Returns**

- `BGE.Debug.GarbageCollectorDisplay`

<MemberHeading id="inputdisplay" depth="3" name="InputDisplay" sig="InputDisplay" />

<MemberMeta badges="static" />

**Extends:&#x20;**`DebugWindow`

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Returns**

- `BGE.Debug.InputDisplay`

<MemberHeading id="memorydisplay" depth="3" name="MemoryDisplay" sig="MemoryDisplay" />

<MemberMeta badges="static" />

**Extends:&#x20;**`DebugWindow`

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Returns**

- `BGE.Debug.MemoryDisplay`
