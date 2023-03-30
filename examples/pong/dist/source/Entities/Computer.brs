function __Computer_builder()
    instance = __Paddle_builder()
    instance.super1_new = instance.new
    instance.new = sub(game)
        m.super1_new(game)
        m.name = "Computer"
        m.position.x = 1280 - 50
        m.position.y = invalid
    end sub
    instance.super1_getFrontColliderXOffset = instance.getFrontColliderXOffset
    instance.getFrontColliderXOffset = function() as float
        return - m.width / 2
    end function
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt)
        ballEntity = m.game.getEntityByName("Ball")
        ' If there is a ball and the ball is moving to the right and hasn't gotten to the computer paddle yet move paddle towards ball
        if ballEntity <> invalid and ballEntity.velocity.x > 0 and ballEntity.position.x < m.position.x
            if ballEntity.position.y < m.position.y - 20
                if m.position.y > m.bounds.top + m.height / 2
                    m.position.y -= 3.5 * 60 * dt
                else
                    m.position.y = m.bounds.top + m.height / 2
                end if
            else if ballEntity.position.y > m.position.y + 20
                if m.position.y < m.bounds.bottom - m.height / 2
                    m.position.y += 3.5 * 60 * dt
                else
                    m.position.y = m.bounds.bottom - m.height / 2
                end if
            end if
        end if
    end sub
    return instance
end function
function Computer(game)
    instance = __Computer_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Computer.bs.map