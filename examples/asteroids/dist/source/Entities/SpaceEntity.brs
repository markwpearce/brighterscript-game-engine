function __SpaceEntity_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.rotationalThrust = 0
        m.rotationalVelocity = 2
        m.repositionable = true
        m.dieOutOfBounds = false
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        m.rotation.z += m.rotationalThrust * m.rotationalVelocity * deltaTime
        m.repositionOnBounds()
    end sub
    instance.repositionOnBounds = sub()
        w = m.game.getCanvas().GetWidth()
        h = m.game.getCanvas().GetHeight()
        if not m.repositionable and m.position.x > 0 and m.position.y > 0 and m.position.x < w and m.position.y < h
            ' it is now on screen
            m.repositionable = true
        end if
        if not m.repositionable
            return
        end if
        out = false
        if m.position.x < 0
            m.position.x = w + m.position.x
            out = true
        end if
        if m.position.x > w
            m.position.x = m.position.x mod w
            out = true
        end if
        if m.position.y < 0
            m.position.y = h + m.position.y
            out = true
        end if
        if m.position.y > h
            m.position.y = m.position.y mod h
            out = true
        end if
        if out and m.dieOutOfBounds
            m.invalidate()
        end if
    end sub
    return instance
end function
function SpaceEntity(game)
    instance = __SpaceEntity_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./SpaceEntity.bs.map