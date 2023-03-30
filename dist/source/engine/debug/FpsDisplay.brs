' @module BGE
function __BGE_Debug_FpsDisplay_builder()
    instance = __BGE_Debug_DebugWindow_builder()
    instance.super3_new = instance.new
    instance.new = sub(game as object)
        m.super3_new(game)
        m.fps = 0
        m.framesInLastSecond = 0
        m.frameTimeCounter = 0
        m.fpsLabel = invalid
        m.width = 100
        m.height = 40
        m.fpsLabel = BGE_UI_Label(game)
        m.fpsLabel.drawableText.font = m.game.getFont("debugUI")
        m.addChild(m.fpsLabel)
    end sub
    instance.super3_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt as float)
        m.frameTimeCounter += dt
        if m.frameTimeCounter > 1.0
            m.fps = m.framesInLastSecond
            m.framesInLastSecond = 0
            m.frameTimeCounter = 1 - m.frameTimeCounter
        end if
        m.framesInLastSecond++
        m.fpsLabel.setText("FPS: " + bslib_toString(m.fps))
        m.width = m.fpsLabel.width + 20
    end sub
    return instance
end function
function BGE_Debug_FpsDisplay(game as object)
    instance = __BGE_Debug_FpsDisplay_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./FpsDisplay.bs.map