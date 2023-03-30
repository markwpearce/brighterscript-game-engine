function __ScoreHandler_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.scores = {
            player: 0
            computer: 0
        }
        m.name = "ScoreHandler"
    end sub
    instance.super0_onGameEvent = instance.onGameEvent
    instance.onGameEvent = sub(event as string, data as object)
        if event = "score"
            if data.team = 0
                m.scores.player++
            else
                m.scores.computer++
            end if
        end if
    end sub
    instance.super0_onDrawEnd = instance.onDrawEnd
    instance.onDrawEnd = sub(renderer as object)
        font = m.game.getFont("default")
        renderer.DrawText(m.scores.player.ToStr(), 1280 / 2 - 200, 100, BGE_Colors().White, font, "center")
        renderer.DrawText(m.scores.computer.ToStr(), 1280 / 2 + 200, 100, BGE_Colors().White, font, "center")
    end sub
    return instance
end function
function ScoreHandler(game)
    instance = __ScoreHandler_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./ScoreHandler.bs.map