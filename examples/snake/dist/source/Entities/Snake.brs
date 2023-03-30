function __Snake_builder()
    instance = __GridEntity_builder()
    ' slow game loop to 10 fps instead of 60
    instance.super1_new = instance.new
    instance.new = function(game) as void
        m.super1_new(game)
        m.segments = []
        m.timeCount = 0
        m.dead = false
        m.maxCells = 10
        m.xDirection = 0
        m.yDirection = 0
        m.secondsPerFrame = 0.1
        m.snakeHeadCollider = invalid
        m.name = "snake"
    end function
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.gridX = args.gridX
        m.gridY = args.gridY
        m.position.xDirection = 1
        m.position.yDirection = 0
        m.grid = args.grid
        m.snakeHeadCollider = m.addRectangleCollider("snake_head", m.grid, m.grid, 0, 0)
        m.snakeHeadCollider.enabled = false
    end function
    instance.super1_onCollision = instance.onCollision
    instance.onCollision = function(colliderName as string, other_colliderName as string, other_entity as object) as void
        if other_entity.name = "apple"
            m.maxCells++
            m.game.postGameEvent("score")
            m.game.playSound("score", 50)
            m.game.destroyEntity(other_entity)
        end if
        if other_entity.name = "MainRoom"
            ? "Collision: " + colliderName + " and " + other_colliderName + " of " + other_entity.name
            m.die()
            return
        end if
    end function
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = function(dt as float) as void
        if m.dead
            return
        end if
        m.timeCount += dt
        if m.timeCount < m.secondsPerFrame
            return
        end if
        m.timeCount = m.timecount - m.secondsPerFrame
        m.snakeHeadCollider.enabled = true
        m.gridX += m.position.xDirection
        m.gridY += m.position.yDirection
        m.refreshPosition()
        ' keep track of where snake has been. front of the array is always the head
        m.segments.unshift({
            x: m.gridX
            y: m.gridY
        })
        ' remove cells as we move away from them
        if m.segments.count() > m.maxCells
            m.segments.pop()
        end if
        ' if the snake goes out of bounds
        if m.checkPositionForSnake(m.gridX, m.gridY, true)
            m.die()
            return
        end if
    end function
    instance.super1_onInput = instance.onInput
    instance.onInput = function(input)
        if m.position.yDirection = 0 and (input.isButton("up") or input.isButton("down"))
            m.position.yDirection = input.y
            m.position.xDirection = 0
        else if m.position.xDirection = 0 and (input.isButton("left") or input.isButton("right"))
            m.position.xDirection = input.x
            m.position.yDirection = 0
        end if
    end function
    instance.super1_onDrawBegin = instance.onDrawBegin
    instance.onDrawBegin = function(canvas)
        ' Draw Head
        m.drawRectangleOnGrid(canvas, m.gridX, m.gridY, BGE_Colors().Green)
        green = 255
        for each segment in m.segments
            green = 0.95 * green ' make snake get darker, just for fun
            if green < 128
                green = 128
            end if
            m.drawRectangleOnGrid(canvas, segment.x, segment.y, BGE_RGBAtoRGBA(0, green, 0))
        end for
    end function
    instance.checkPositionForSnake = function(gridX, gridY, ignoreHead = false) as boolean
        i = 0
        for each segment in m.segments
            if gridX = segment.x and gridY = segment.y
                if not ignoreHead or i > 0
                    return true
                end if
            end if
            i++
        end for
        return false
    end function
    instance.die = function()
        m.dead = true
        m.snakeHeadCollider.enabled = false
        m.game.playSound("die", 75)
        m.game.postGameEvent("game_over")
    end function
    return instance
end function
function Snake(game)
    instance = __Snake_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Snake.bs.map