function __MainRoom_builder()
    instance = __BGE_Room_builder()
    'CreateObject("roTimespan")
    instance.super1_new = instance.new
    instance.new = sub(game)
        m.super1_new(game)
        m.game_started = false
        m.ball_spawn_timer = invalid
        m.ball_direction = - 1
        m.ball = invalid
        m.name = "MainRoom"
    end sub
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.game.addEntity(Player(m.game))
        m.game.addEntity(Computer(m.game))
        m.game.addEntity(PauseHandler(m.game))
        m.game.addEntity(ScoreHandler(m.game))
        m.game_started = true
        m.ball_spawn_timer = CreateObject("roTimespan")
        m.ball_direction = - 1
        m.ball = invalid
    end sub
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt)
        if m.game_started and not BGE_isValidEntity(m.ball) and m.ball_spawn_timer.TotalMilliseconds() > 1000
            m.ball = m.game.addEntity(Ball(m.game), {
                direction: m.ball_direction
            })
        end if
    end sub
    instance.super1_onDrawBegin = instance.onDrawBegin
    instance.onDrawBegin = sub(renderer as object)
        offset = 50
        screenSize = renderer.getCanvasSize()
        center = renderer.getCanvasCenter()
        renderer.drawRectangle(0, 0, screenSize.x, offset, &hFFFFFFFF)
        renderer.drawRectangle(0, screenSize.y - offset, m.game.screen.getWidth(), offset, &hFFFFFFFF)
        if not m.game_started
            renderer.drawText("Press OK To Play", center.x, center.y - 20, BGE_Colors().White, m.game.getFont("default"), "center")
        end if
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.isButton("back")
            m.game.End()
        end if
        if not m.game_started and input.isButton("ok")
            m.game_started = true
        end if
    end sub
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = sub(event as string, data as object)
        if event = "score"
            if data.team = 0
                m.ball_direction = - 1
            else
                m.ball_direction = 1
            end if
            m.ball = invalid
            m.ball_spawn_timer.Mark()
        end if
    end sub
    return instance
end function
function MainRoom(game)
    instance = __MainRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./MainRoom.bs.map