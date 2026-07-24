---
title: BGE/UI
kind: namespace
longname: BGE/UI
---

# BGE/UI

**Alias:** `BGE.UI`

---

## Enums

<MemberHeading id="bgeuihorizalignment" depth="3" name="BGE.UI.HorizAlignment" sig="BGE.UI.HorizAlignment" />

<MemberMeta badges="static,readonly,enum" />

**Properties**

- `left` (default: "left")
- `center` (default: "center")
- `right` (default: "right")

<MemberHeading id="bgeuivertalignment" depth="3" name="BGE.UI.VertAlignment" sig="BGE.UI.VertAlignment" />

<MemberMeta badges="static,readonly,enum" />

**Properties**

- `top` (default: "top")
- `center` (default: "center")
- `bottom` (default: "bottom")

## Other

<MemberHeading id="label" depth="3" name="Label" sig="Label" />

<MemberMeta badges="static" />

**Extends:&#x20;**`UiWidget`

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Properties**

- `drawableText` ([BGE.DrawableText](/bge#drawabletext))

**Returns**

- `BGE.UI.Label`

<MemberHeading id="defaultpadding" depth="3" name="DEFAULT_PADDING" sig="DEFAULT_PADDING" />

<MemberMeta badges="static,readonly" />

**Default:** `32`

<MemberHeading id="offsetsize" depth="3" name="OffsetSize" sig="OffsetSize" />

<MemberMeta badges="static" />

**Parameters**

- `tOffset` (float, optional, default: 0)
- `rOffset` (dynamic, optional, default: "invalid")
- `bOffset` (dynamic, optional, default: "invalid")
- `lOffset` (dynamic, optional, default: "invalid")

**Properties**

- `top` (float)
- `right` (float)
- `bottom` (float)
- `left` (float)

**Returns**

- `BGE.UI.OffsetSize`

<MemberHeading id="uicontainer" depth="3" name="UiContainer" sig="UiContainer" />

<MemberMeta badges="static" />

**Extends:&#x20;**`BGE.UI.UiWidget`

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Properties**

- `backgroundRGBA` (integer) — RGBA value for the background of the window/container
- `showBackground` (boolean) — RGBA value for the background of the window/container
- `children` (dynamic)

**Returns**

- `BGE.UI.UiContainer`

<MemberHeading id="uiwidget" depth="3" name="UiWidget" sig="UiWidget" />

<MemberMeta badges="static" />

**Extends:&#x20;**`BGE.GameEntity`

Base Abstract class for all UI Elements

**Parameters**

- `game` ([BGE.Game](/bge#game))

**Properties**

- `customPosition` (boolean) — If position = "custom", then m.customX is horizontal position of this element from the parent position ' and m.customY is the vertical position of this element from the parent position (positive is down)
- `customX` (float)
- `customY` (float)
- `horizAlign` (string) — If customPosition is false, this dictates where horizontally in the container this element should go. Can be: "left", "center" or "right"
- `vertAlign` (string) — If customPosition is false, this dictates where vertically in the container this element should go. Can be: "top", "center" or "bottom"
- `width` (integer) — Width of the element
- `height` (integer) — Height of the element
- `canvas` ([BGE.Canvas](/bge#canvas))
- `padding` ([OffsetSize](/bge-ui#offsetsize))
- `margin` ([OffsetSize](/bge-ui#offsetsize))

**Returns**

- `BGE.UI.UiWidget`
