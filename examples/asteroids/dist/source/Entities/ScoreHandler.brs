function __ScoreHandler_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.score = 0
        m.name = "ScoreHandler"
    end sub
    instance.super0_onGameEvent = instance.onGameEvent
    instance.onGameEvent = sub(event as string, data as object)
        if event = "rock_hit"
            m.score++
        end if
        if event = "game_start"
            m.score = 0
        end if
    end sub
    instance.super0_onDrawEnd = instance.onDrawEnd
    instance.onDrawEnd = sub(renderObj as object)
        if m.score > 0
            font = m.game.getFont("default")
            frameCenter = renderObj.getCanvasCenter()
            renderObj.DrawText(m.score.ToStr(), frameCenter.x, 100, BGE_Colors().white, font, "center")
        end if
    end sub
    return instance
end function
function ScoreHandler(game)
    instance = __ScoreHandler_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./ScoreHandler.bs.map