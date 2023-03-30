function __MainRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = function(game as object) as void
        m.super1_new(game)
        m.ball = invalid
        m.name = "MainRoom"
    end function
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = function(dt as float)
        if not BGE_isValidEntity(m.ball)
            m.ball = m.game.addEntity(Ball(m.game), {
                direction: - 1
            })
        end if
    end function
    instance.super1_onDrawBegin = instance.onDrawBegin
    instance.onDrawBegin = function(renderer as object)
        w = renderer.getCanvasSize().x
        h = renderer.getCanvasSize().y
        white = BGE_Colors().White
        red = BGE_Colors().Red
        grey = BGE_Colors().Grey
        renderer.DrawRectangle(0, 0, w, h, grey)
        renderer.DrawRectangleOutline(3, 3, w - 3, h - 3, red)
        renderer.DrawText("Canvas", w / 2, 100, white, m.game.getFont("default"), "center")
        renderer.DrawText("Move with arrows", w / 2, 240, white, m.game.getFont("default"), "center")
        renderer.DrawText("Scale with replay/options", w / 2, 270, white, m.game.getFont("default"), "center")
        renderer.DrawText("Center with play/pause", w / 2, 300, white, m.game.getFont("default"), "center")
    end function
    instance.super1_onInput = instance.onInput
    instance.onInput = function(input as object)
        canvasOffset = m.game.canvas.getOffset()
        canvasScale = m.game.canvas.getScale()
        delta = 2
        scaleDelta = 0.01
        if input.isButton("back")
            m.game.End()
        end if
        canvasOffset.x += delta * input.x
        canvasOffset.y += delta * input.y
        if input.isButton("options")
            canvasScale.x *= (1 + scaleDelta)
            canvasScale.y *= (1 + scaleDelta)
        else if input.isButton("replay")
            canvasScale.x *= (1 - scaleDelta)
            canvasScale.y *= (1 - scaleDelta)
        end if
        m.game.canvas.setOffset(canvasOffset.x, canvasOffset.y)
        m.game.canvas.setScale(canvasScale.x, canvasScale.y)
        if input.isButton("play")
            m.game.centerCanvasToScreen()
        end if
    end function
    return instance
end function
function MainRoom(game as object)
    instance = __MainRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./MainRoom.bs.map