# Baked lights on staticImage planes (#528)

## Intent

The thirdPerson town ground (a shaded `staticImage` plane) should look like the graveyard, field
and crypt grounds: each torch casts a pool of light where it stands. Today every ranged point light
is measured once under the camera and tints the whole plane, so walking up to a torch turns the
whole town orange.

## Goals / non-goals

- Goal: pools on shaded `staticImage` planes, in the right places, matching the tiled look
  (`lightPoolOpacity`, same gradient shapes).
- Goal: no frame cost over today's uniform tint.
- Non-goal: changing `tiledImage` planes. A texel in a repeating tile stands for many world
  spots, so pools can't be baked into it; they keep drawing per redraw.
- Non-goal: per-light opt-in. Every shaded `staticImage` plane gets this.
- Anti-goal: a visible lighting difference between baked and the tiled planes' pools.

## Approaches (measured on device, 2026-11-15)

Orbiting the camera at 4 town spots, quality pinned at Medium, 2 runs each (fps):

| Spot | uniform (today) | per-frame pools | baked |
|---|---|---|---|
| square 17,17 | 8.96 | 8.91 | 9.03 |
| keep 17,8 | 10.47 | 10.31 | 10.53 |
| south road 17,27 | 12.13 | 11.91 | 12.20 |
| NE corner 31,4 | 14.47 | 14.22 | 14.54 |

1. **Per-frame pools** (as `tiledImage`): pools drawn into the top-down bitmap on every redraw.
   About 1-2% slower, scales with torches in view, and pools can spill past the decal's edges.
2. **Baked** (picked): pools and the uniform tint drawn into a lit copy of the texture, rebuilt
   only when the lights change. Free next to today, clipped to the texture by construction.

Both look the same. Mark picked baked.

## Design

- `SceneObjectPlane`: for an `isShaded` `staticImage` plane, the warp's source is a lit copy of
  the (possibly stretched) source region: the texture drawn tinted by the uniform lights
  (ambient, directional, point lights with no `range`), then each ranged point light's pool drawn
  over it in texture space (`worldPointToTexel()` for the centre, `radius / texelScale` for the
  size), using the existing pool gradients and `getLightPoolRGBA()`.
- The lit copy is keyed by `rendererObj.lightingVersion` and the source size, and allocated
  fresh on each rebuild (Roku queues draws, so a bitmap read this frame can't be redrawn).
- With the lighting in the texture, the composite is blitted untinted (`hasBakedLighting`), and a
  lighting change forces a full redraw rather than the tiled pools-only redraw.
- Pool lights drop out of the uniform tint on these planes too (`usesLightPools()`).
- Cost of the lit copy: one bitmap the size of the source texture (the town's 576x512 is ~1.2 MB).
  A light that changes every frame rebakes every frame; noted in the docs.
- Remove the spike's `staticLightMode` field and the thirdPerson `groundLights` param.
- `lightPoolOpacity` default is now 0.4 (was 0.6) for all planes, per Mark.

## Left to the builder

- Unit tests (Rooibos, headless): rebuilt once per lighting change and not per frame; composite
  tint is -1 when baked; pool lights excluded from the tint; pool placement in texels for a
  known light; unshaded planes and planes with no lights untouched.
- Docs: the plane lighting paragraph in `docs/drawables-and-scene-objects.md` and
  `specs/renderer-notes.md`.
- On-device check of the town before the PR.
