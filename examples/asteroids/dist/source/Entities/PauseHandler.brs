function __PauseHandler_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.name = "PauseHandler"
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.persistent = true
        m.pauseable = false
    end sub
    instance.super0_onInput = instance.onInput
    instance.onInput = sub(input as object)
        if input.isButton("play") and input.press
            if not m.game.isPaused()
                m.game.Pause()
            else
                m.game.Resume()
            end if
        end if
    end sub
    instance.super0_onDrawBegin = instance.onDrawBegin
    instance.onDrawBegin = sub(renderObj as object)
        if m.game.isPaused()
            font = m.game.getFont("default")
            frameCenter = renderObj.getCanvasCenter()
            renderObj.DrawText("Paused", frameCenter.x, 100, BGE_Colors().white, font, "center")
        end if
    end sub
    return instance
end function
function PauseHandler(game)
    instance = __PauseHandler_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./PauseHandler.bs.map