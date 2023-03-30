function __PauseHandler_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game) as void
        m.super0_new(game)
        m.name = "PauseHandler"
    end function
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.persistent = true
        m.pauseable = false
    end function
    instance.super0_onInput = instance.onInput
    instance.onInput = function(input as object)
        if input.isButton("play") and input.press
            if not m.game.isPaused()
                m.game.Pause()
            else
                m.game.Resume()
            end if
        end if
    end function
    instance.super0_onDrawBegin = instance.onDrawBegin
    instance.onDrawBegin = function(renderObj as object)
        if m.game.isPaused()
            frameCenter = renderObj.getCanvasCenter()
            renderObj.drawText("Paused", frameCenter.x, frameCenter.y - 20, BGE_Colors().white, m.game.getFont("default"), "center")
        end if
    end function
    return instance
end function
function PauseHandler(game)
    instance = __PauseHandler_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./PauseHandler.bs.map