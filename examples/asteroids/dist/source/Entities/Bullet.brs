function __Bullet_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.speed = 100
        m.angle = 0
        m.bulletCollider = invalid
        m.name = "Bullet"
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.position = args.position
        m.rotation = args.rotation
        m.speed = args.speed
        m.velocity.x = m.speed * cos(m.rotation.z)
        m.velocity.y = m.speed * sin(m.rotation.z)
        m.width = 10
        m.height = 10
        m.bulletCollider = m.addCircleCollider("bullet", m.width / 2)
        m.game.playSound("laser", 50)
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        m.checkOffScreen()
    end sub
    instance.checkOffScreen = sub()
        w = m.game.getCanvas().GetWidth()
        h = m.game.getCanvas().GetHeight()
        if m.position.x < 0 or m.position.x > w or m.position.y < 0 or m.position.y > h
            m.game.destroyEntity(m)
        end if
    end sub
    instance.super0_onDrawEnd = instance.onDrawEnd
    instance.onDrawEnd = sub(renderObj as object)
        drawPosition = renderObj.worldPointToCanvasPoint(m.position)
        renderObj.drawSquare(drawPosition.x, drawPosition.y, m.width, BGE_Colors().Lime)
    end sub
    return instance
end function
function Bullet(game)
    instance = __Bullet_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Bullet.bs.map