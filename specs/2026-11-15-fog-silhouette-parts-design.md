# Fog silhouettes: a few boxes per model (#525)

## Why

A `castsFogSilhouette` model gets one fog-coloured screen box over its bounding points
(`Renderer.workOutFogBoxes()`). thirdPerson's graveyard chapel (a tall narrow tower on a long
nave) shows that box as a translucent slab in the fade band and a solid block past the draw
distance, mostly over open sky beside the tower.

Done when the chapel fades into fog with no visible rectangle around it, in the fade band and
past the draw distance, and the town costs about the same.

## Goals / non-goals

- Goal: L/T-shaped models (tower on a nave) get a silhouette close to their outline, with no
  setup from the game.
- Non-goal: an exact outline (impostor masks), author-provided parts, a per-drawable
  silhouette reach. Walls already draw their real outline and are untouched.
- Anti-goal: darker seams where boxes overlap in the fade band, or a noticeable cost increase
  in the town.

## Approaches

1. **Automatic height bands (picked).** Split each model into a few boxes once per geometry
   change, by where its footprint shrinks with height. No setup; might misjudge odd shapes.
2. Author-provided `fogSilhouetteParts` on the drawable. Exact control, but every model needs
   hand setup.
3. Impostor alpha mask. Exact outline, but past the draw distance the model isn't drawn so
   there's often no capture; ruled out.
4. Convex hull of the projected box. Needs triangle fills (much dearer than `DrawRect` on
   Roku) and doesn't fix the tower-beside-nave gap; ruled out.

## Design

- **Parts, model space, once per geometry.** `SceneObjectModel` slices its model-space height
  into a fixed number of slices. Each slice's footprint is the x/z extent of every face whose
  y-range overlaps it (so a tower wall running from the ground up counts in every slice it
  spans: never smaller than the model). Adjacent slices merge into one part while the footprint
  doesn't shrink sharply; a capped number of parts (about 3). A boxy house stays one part.
  Recomputed only when `geometryVersion` changes.
- **World points per frame.** A new `SceneObject` method returns the caster's silhouette parts
  as arrays of world-space corner points. The base returns one part, its bounding points (what's
  used today); `SceneObjectModel` overrides it with its parts' corners through
  `transformationMatrix`.
- **Screen union, no overlap.** `workOutFogBoxes()` projects each part to a screen box (same
  behind-the-eye rule as now), then turns that caster's boxes into disjoint rects: split at every
  box's top and bottom, merge the x-spans in each band, one rect per span. Same alpha and colour
  per caster as now. Overlap between different casters is as today.
- Repeat/caching logic in `drawFogSilhouettes()` is unchanged; it already reruns on geometry or
  transform changes.

## Left to the builder

Slice count, the "shrinks sharply" threshold and the part cap (constants, measured against the
chapel and the town houses); test coverage in the existing fog/renderer specs; a line in the
fog docs and `Fog` doc comment. Verify on device in thirdPerson (graveyard and town).
