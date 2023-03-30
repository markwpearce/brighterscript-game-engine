function __ScoreHandler_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game) as void
        m.super0_new(game)
        m.score = 0
        m.name = "ScoreHandler"
    end function
    instance.super0_onGameEvent = instance.onGameEvent
    instance.onGameEvent = function(event as string, data as object)
        if event = "score"
            m.score++
        else if event = "game_start"
            m.score = 0
        end if
    end function
    instance.super0_onDrawEnd = instance.onDrawEnd
    instance.onDrawEnd = function(renderObj as object)
        font = m.game.getFont("default")
        frameCenter = renderObj.getCanvasCenter()
        renderObj.drawText(m.score.ToStr(), frameCenter.x, 100, BGE_Colors().white, m.game.getFont("default"), "center")
    end function
    return instance
end function
function ScoreHandler(game)
    instance = __ScoreHandler_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./ScoreHandler.bs.map