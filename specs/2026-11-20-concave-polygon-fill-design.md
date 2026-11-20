# Concave polygon fill (#547)

## Problem

`Renderer.drawPolygonTo()` fills the convex hull of its points, so a concave `DrawablePolygon`
or SceneGraph `Polygon` (a chevron, an L, a star) draws with its notches filled in. #539's
`drawConvexPolygonAsSpansTo()` walks a convex outline's two sides down from its top corner. It
can't do a notch: a band through one has more than two edge crossings.

## Approach: scanline fill with an active-edge list

`BGE.ScanlinePolygonFill` (new file, `renderer/ScanlinePolygonFill.bs`), owned by the
renderer:

1. Work in `(u, v)`, where `v` is the banded axis: across y unless the bounding box is taller
   than it's wide (same rule and grid as the convex fill).
2. Build the edge table once per fill: each non-horizontal edge's top `v`, bottom `v`, `u` at
   its top, `du/dv`, and its winding direction (+1 going down, -1 going up). Insertion-sort an
   index array by top as the edges are added.
3. Per band, sample at the band's middle (clamped into the polygon's extent, like the convex
   fill). Drop active edges whose bottom is at or above the sample, add edges whose top is at
   or above it (skipping any that ended between samples). An edge is live on `[top, bottom)`,
   so a vertex the outline passes through counts once.
4. Work out each active edge's crossing and insertion-sort the active list by it. The list
   stays in last band's order, so this is close to one pass.
5. Walk the crossings with a winding count. **Nonzero** (SVG's default): inside wherever the
   count isn't 0, so a star drawn as one line fills solid. **Even-odd** is the same walk
   toggling instead of adding, so it's in too (`BGE.PolygonFillRule.evenOdd`: hollow star).
6. Round each span's ends to whole pixels. A span thinner than a pixel still gets one (as the
   convex fill does); a span that touches or overlaps the band's previous span joins it. Spans
   in a band never overlap, so a translucent fill never blends twice and there are no seams.
7. Merge down: a span exactly matching one from the band above extends that rect instead of
   starting one (two-pointer walk over the sorted lists). Unmatched pending rects are drawn.
   An L-shape is 2 `DrawRect`s; a U's two arms stay one rect each.

No per-band allocation: every scratch array (edge table, order, active list, crossings,
spans, pending rects) lives on the fill object, is written by index and keeps a count. The
renderer creates the fill object on first use.

Alternatives (from the issue) not taken: ear clipping is O(n²) in BrightScript and leaves
triangles to fill at ~0.4 ms each, with seams between them; splitting into cached convex
pieces adds a cache to invalidate for a cost the scanline fill should already beat.

## API

- `BGE.PolygonFillRule` enum: `nonZero = "nonzero"`, `evenOdd = "evenodd"` (SVG's names).
- `Renderer.drawPolygonAsSpansTo(canvas, points, x, y, rgba, bandSize = 1, bandAcrossY =
  invalid, fillRule = nonZero) as integer`: the scanline fill itself, returns rects drawn.
- `Renderer.drawConcavePolygonTo(canvas, points, x, y, rgba, allowQuickDraw = false, fillRule =
  nonZero) as boolean` (and `drawConcavePolygon()` on the renderer's own canvas): picks how.
  - Points already strictly convex in order go to `drawPolygonTo()` (one cheap check, and big
    convex shapes keep their exact triangle fill).
  - Otherwise there's no cheaper exact fill, so it always bands. At rest, 1px bands.
  - With `allowQuickDraw`, a shape under `triangleSkipSize` is skipped, and one more than
    `CONCAVE_SPAN_QUICK_MAX_BANDS` (48) px across its banded side uses the
    `triangleQuickDrawStep` band size; both count in `getLossyTriangleFillCount()`, so the
    object redraws exactly once it stops. (First drafted as the convex fill's
    `(n - 2) * POLYGON_SPAN_BANDS_PER_TRIANGLE`, but that never coarsens a many-sided shape:
    a moving 300 px 24-point gear stayed at 1px, 16.5 ms a fill on a Roku Express. A concave
    fill has no exact fallback, so a fixed cap fits better.)
    `getQuickDrawFillError()` stays right: the error is still the band step.
- `drawPolygonTo()` is unchanged: hull by default.

## Opt-in flags

- `DrawablePolygon.concave as boolean = false` and `DrawablePolygon.fillRule =
  BGE.PolygonFillRule.nonZero`. `SceneObjectPolygon` passes them to the renderer and redraws
  when either changes (it already compares points each frame, so this costs two compares).
- SceneGraph `Polygon`: `concave` (`boolean`) and `fillRule` (`string`, `"nonzero"`/`"evenodd"`)
  fields, both redraw-triggering and in the cache key; `ShapeRenderTask` gets the same fields.

## Occlusion, depth sort and fog

- **Occlusion:** `SceneObjectPolygon` isn't an eligible occluder type (only Image, Rectangle
  and Model are), so a concave polygon can never claim to hide what's behind its notches.
  A test pins that; if polygons ever become occluders, a concave one must claim nothing (or a
  conservative interior), and the doc comment on the flag says so.
- **Depth sort** projects the polygon's points and tests hull overlap (`hullsOverlap()`, SAT).
  For a concave polygon that's conservative: an object in a notch is ordered against it when it
  needn't be, never mis-ordered.
- **Fog silhouettes** use bounding points for every non-model caster already; unchanged.
- **Model faces** keep using `drawPolygonTo()`: faces are convex.

## Testing

Rooibos, `ScanlinePolygonFill.spec.bs` (pixel checks on a headless `roBitmap`):

- chevron: notch empty, arms filled (bands across y)
- L-shape: both legs filled, the corner empty, exactly 2 rects (merging)
- tall chevron: bands across x
- star, nonzero: solid centre, empty between tips; even-odd: hollow centre
- translucent star (1px and 2px bands): every pixel's alpha is 0 or the fill's, never doubled
- off-canvas bands skipped; zero-area and under-3-point input draw nothing

`RendererTriangleFill.spec.bs`: `drawConcavePolygonTo` delegates convex input, skips tiny
and coarsens big shapes only with `allowQuickDraw`. `SceneObjectPolygon.spec.bs`: the flag
reaches the renderer, toggling it redraws, and a polygon isn't an eligible occluder.

## Benchmark

`polygon-fill-benchmark` (rendererTest) gets concave shapes (chevron, L, 5-point star, a
12-point gear-ish outline at a few sizes) timed with `scan1`/`scan4` against `span1` of their
hull and `auto` (what `drawPolygonTo()` does with the hull), plus a per-band cost line, and its
on-screen fill check draws them. Device numbers go in the PR.

## Plan

1. Spec (this file).
2. Failing tests for `ScanlinePolygonFill`; implement until green.
3. Renderer `drawPolygonAsSpansTo()`/`drawConcavePolygonTo()` tests, then code.
4. `DrawablePolygon`/`SceneObjectPolygon` flag tests, then code; SceneGraph `Polygon` fields.
5. Benchmark cases, validate rendererTest, device run.
6. Docs: `docs/drawables-and-scene-objects.md`, `docs/scenegraph-shapes.md`, renderer rule.
7. `npm run check`, code review, PR.

## Device results (Roku Express, 720p, Roku OS 16.0.4)

Not comparable with #539's Roku Ultra numbers. ms per fill, 30 rotations each.

- Per band: the convex walk (`span1`) costs ~23-31 us a band on big shapes, the scanline
  fill (`scan1`) ~44-61 us on the same convex shapes and on concave ones: about 1.9x. More
  active edges (a gear, a pentagram) sit at the top of that range.
- Per shape, concave fill at rest against what the hull fill draws today (`auto`): chevron 240
  9.3 vs 1.1, L 240 13.4 vs 2.6, star10 120 6.2 vs 2.9, star10 300 14.6 vs 2.9, gear24 300
  16.8 vs 9.0. Moving (`concaveQuick`, band step 2 at Medium) roughly halves the big ones.
- Small shapes (60 px and under) are 2-4 ms either way, dominated by per-call cost.

No triangulation cache: big concave shapes cost 2-5x their hull, but the quick-draw step covers
the moving case and the shapes this is for (arrows, stars, UI marks) are mostly small.
