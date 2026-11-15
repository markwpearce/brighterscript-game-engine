# Keep cached images past a shrinking draw distance (issue #529)

## Why

When auto quality steps down, `drawDistanceScale` shrinks and `Camera3d.currentDrawDistance`
eases in. Objects just past the new distance fade out and fog (backdrop and silhouette boxes)
covers them. Some of them already have a picture that's still right for the view: a draw-replay
blit (still camera) or a model impostor capture (moving camera). Drawing that costs about what the
fog box covering it costs, and looks far better. In thirdPerson the lamp-lit buildings flicker into
fog on every step down and back on every step up.

## Rule

Only with fog on (`Camera3d.fog.enabled`), `Fog.keepCachedImages` (default true) and a fade band
(`drawDistanceFadeFraction > 0`).

**Keep distance.** `Camera3d` remembers the eased draw distance at the moment its target drops
below it (`keepDrawDistance`, the max over consecutive drops). It's cleared once the eased distance
climbs back to it, on `snapDrawDistance()`, and never exceeds what was actually drawn.
`getCachedImageKeepDistance()` returns it while it's past the current distance and the gates
above hold, else 0.

**Kept object.** On a frame its fade alpha comes out below the alpha it was last drawn with, an
object is kept when all hold:
- it drew last frame (at any fade above 0), alone (not in an overlap cluster), with the same
  geometry and projection, and isn't newly enabled
- its nearest bounding point is within the keep distance
- it has a cheap picture for this frame:
  - **replay** (any type with draw replay: images, models): its blit was captured at that fade,
    with the same lights and fill colour, and the object hasn't moved relative to the camera (or
    its camera-locked pose still matches)
  - **impostor** (models with `useImpostor` that cast fog silhouettes): the capture is at least
    the current quality, its lights still fit, and the fit to this frame's box corners is within
    the impostor limits and lands on the canvas

A kept object's `distanceFadeAlpha` is frozen at the alpha it was last drawn with, so the frame
looks as it did before the drop: it draws over the backdrop at that fade, and its fog box (if it
casts one) stays at 1 - that alpha behind it, as before. An object that was fully opaque gets no
box. It never becomes an occluder.

Freezing rather than pinning to 1 came from the device: thirdPerson's fade band is wide, so at
Ultra the town's tower and far huts are already drawn at alpha 0.6-0.98 over fog. Keeping only
fully opaque objects kept none of them; pinning them to 1 would make them pop more solid. Its draw only ever repeats the replay
blit or blits the impostor; if neither works it drops back to its real fade for that frame (and
then culls or fades as today). It's re-checked whenever its fade is recomputed (it or the camera
moved, the distance changed) and each frame while kept. A kept impostor blit drawn with the
camera still is captured for replay, so later still frames cost one blit.

So it drops to fog when: its replay is invalidated (lights, colour, animation key, a move it can't
follow), its impostor fit runs out (turned or zoomed too far), it leaves the keep distance, the
eased distance climbs back past the keep distance (then it's just in range again), or fog or the
flag turns off. Leaving the keep never reuses anything: its next normal draw re-projects (stale
quality and canvas position force it).

## Cost

- Still camera: a kept object costs one replayed blit on top of the fog it already had (a solid
  box without the keep, a 1 - alpha box with it). On device, thirdPerson's town at Medium after
  a drop from Ultra: 48.1 fps kept vs 49.2 without (~0.5 ms), the price of the picture not
  changing. Orbiting: 9.1 vs 9.0, neutral.
  The keep check runs only on frames its fade is recomputed, plus a few field reads while kept.
- Moving camera: the impostor check projects the box's 8 corners, which the silhouette box
  projected anyway, plus a fit and one blit. Hence only for casters: for a non-caster it would
  be all extra.
- Nothing past the old draw distance is projected: only objects that drew last frame can be kept,
  so the set can only shrink.

## Walls: out of scope

Wall strips aren't cached images: every strip is drawn every frame from the walk. Keeping textured
strips past the reduced distance would draw one strip per piece where the fog draws merged runs
(`buildFogRuns`), so it costs more, not less. Tied to #516 (walls redraw); revisit if walls gain a
cached raster.

## Tests

`RendererFogKeep.spec.bs`: keep distance easing (set on drop, cleared on recovery, snap, gates);
a still image past the reduced distance keeps drawing and gets no silhouette box; one that was
fading keeps its fade and its box as they were; it drops
once its replay goes stale (fill colour change); no keep with fog off or the flag off; objects that
were faded before the drop aren't kept; a moving impostor caster is kept (an exact-policy occluder
too, since a kept picture never occludes) and a non-caster isn't; a kept impostor goes to fog once
the view turns past its limit.

Checked on the simulator (127.0.0.1): no crash, still and moving. On the device (Roku at
192.168.41.102), thirdPerson's town pinned at Ultra and dropped to Medium after 15 s: with the keep
the tower and back huts look as they did at Ultra, without it they sink into fog.

## Needs a device

FPS A/B in thirdPerson (`Fog.keepCachedImages` on vs off) through quality step-downs, still and
moving, and a visual check that the buildings and back wall no longer flicker into fog.
