# Breakout example

This example is a compact Breakout-style game that shows how a `BGE.Game`
can combine moving entities, rectangular drawables, colliders, room setup,
game events, score tracking, pause handling, and a small HUD.

## Coordinate space

BGE gameplay code uses world space with `+y` pointing up and the origin at the
bottom-left of the canvas. The renderer flips that into canvas/screen space
when it draws the frame.

That convention affects the main Breakout layout:

- the paddle sits near the bottom because it has a small positive `y`
- the first brick row starts near the top because it has the highest `y`
- each lower brick row subtracts from `y`
- the ball is considered lost after it falls below the bottom edge

## Drawable and collider offsets

Breakout uses `DrawableRectangle` for the paddle, ball, and bricks. The example
also shows the difference between centered entities and top-left anchored
entities.

The paddle and ball store their `position` at their centers, so their rectangle
drawable and rectangle collider both use the same corner offset. This keeps the
visible rectangle and collision rectangle aligned.

Bricks store their `position` at their top-left corner, so their drawable and
collider can both use the default offset.

## Brick bounce tradeoff

The collision callback tells an entity which other entity it hit, but it does
not include a collision normal or which side of the collider was struck.

For side walls and the ceiling, the ball handles bounces directly by comparing
its position to the canvas edges. For bricks, the example intentionally uses a
simpler rule: every brick hit inverts `velocity.y`.

That is correct for the common case where the ball approaches a grid of bricks
from above or below. It is not a full per-side brick bounce simulation, but it
keeps the example focused on the engine APIs rather than collision response
math.

## Main files

- `src/source/Rooms/MainRoom.bs` creates the room, paddle, ball, bricks, score
  handler, and pause handler.
- `src/source/Entities/Paddle.bs` demonstrates a centered rectangle drawable
  and collider sharing one offset.
- `src/source/Entities/Ball.bs` demonstrates launch/reset behavior, paddle
  bounce aiming, edge bounces, and the simplified brick bounce.
- `src/source/Entities/Brick.bs` demonstrates a top-left anchored rectangle
  that destroys itself and emits a game event when hit.
