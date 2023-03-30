function __MainRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = function(game) as void
        m.super1_new(game)
        m.game_started = false
        m.snake = invalid
        m.apple = invalid
        m.scoreHandler = invalid
        m.grid = 40
        m.gridHeight = 0
        m.gridWidth = 0
        m.wallWidth = 2 * 40
        m.screenW = 0
        m.screenH = 0
        m.name = "MainRoom"
    end function
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.game.addEntity(PauseHandler(m.game))
        m.game.addEntity(ScoreHandler(m.game))
        m.screenW = m.game.canvas.getWidth()
        m.screenH = m.game.canvas.getHeight()
        m.gridHeight = cint(m.screenH / m.grid)
        if m.gridHeight mod 2 = 1
            m.gridHeight--
        end if
        m.gridWidth = cint(m.screenW / m.grid)
        if m.gridWidth mod 2 = 1
            m.gridWidth--
        end if
        m.game_started = false
        m.game.canvas.setOffset(100, 100)
        m.addWallsColliders()
    end function
    instance.super1_onCollision = instance.onCollision
    instance.onCollision = function(colliderName as string, other_colliderName as string, other_entity as object)
        ? "Collision: " + colliderName + " and " + other_colliderName + " of " + other_entity.name
    end function
    instance.addWallsColliders = function()
        m.addRectangleCollider("wallTop", m.screenW, m.wallWidth, 0, m.screenH)
        m.addRectangleCollider("wallLeft", m.wallWidth, m.screenH, 0, m.screenH)
        m.addRectangleCollider("wallBottom", m.screenW, m.wallWidth, 0, m.wallWidth)
        m.addRectangleCollider("wallRight", m.wallWidth, m.screenH, m.screenW - m.wallWidth, m.screenH)
    end function
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = function(dt)
        if m.game_started and not BGE_isValidEntity(m.snake)
            m.snake = m.game.addEntity(Snake(m.game), {
                gridX: cint(m.gridWidth / 2)
                gridY: cint(m.gridHeight / 2)
                grid: m.grid
            })
        end if
        if m.game_started and not BGE_isValidEntity(m.apple) and BGE_isValidEntity(m.snake)
            applePos = m.getAppleGrid()
            m.apple = m.game.addEntity(Apple(m.game), {
                grid: m.grid
                gridX: applePos.x
                gridY: applePos.y
            })
        end if
    end function
    instance.super1_onDrawBegin = instance.onDrawBegin
    instance.onDrawBegin = function(renderObj as object)
        m.drawWalls(renderObj)
        frameCenter = renderObj.getCanvasCenter()
        if not m.game_started
            if invalid <> m.snake
                renderObj.DrawText("Game Over!", frameCenter.x, frameCenter.y + 20, BGE_Colors().white, m.game.getFont("default"), "center")
            end if
            renderObj.DrawText("Press OK To Play", frameCenter.x, frameCenter.y - 20, BGE_Colors().white, m.game.getFont("default"), "center")
        end if
    end function
    instance.super1_onInput = instance.onInput
    instance.onInput = function(input)
        if input.isButton("back")
            m.game.End()
        end if
        if not m.game_started and input.isButton("ok")
            m.game_started = true
            m.game.destroyEntity(m.snake)
            m.game.postGameEvent("game_start")
        end if
    end function
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = function(event as string, data as object)
        if event = "game_over"
            m.game_started = false
        end if
    end function
    instance.getAppleGrid = function() as object
        applePosition = invalid
        while applePosition = invalid
            gridX = rnd(m.gridWidth - 4) + 1
            gridY = rnd(m.gridHeight - 4) + 1
            if not m.snake.checkPositionForSnake(gridX, gridY)
                applePosition = {
                    x: gridX
                    y: gridY
                }
            end if
        end while
        return applePosition
    end function
    instance.drawWalls = function(renderObj as object)
        color = BGE_Colors().White
        renderObj.DrawRectangle(0, 0, m.screenW, m.wallWidth, color)
        renderObj.DrawRectangle(0, 0, m.wallWidth, m.screenH, color)
        renderObj.DrawRectangle(0, m.screenH - m.wallWidth, m.screenW, m.wallWidth, color)
        renderObj.DrawRectangle(m.screenW - m.wallWidth, 0, m.wallWidth, m.screenH, color)
    end function
    return instance
end function
function MainRoom(game)
    instance = __MainRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./MainRoom.bs.map