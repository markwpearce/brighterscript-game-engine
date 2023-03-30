function __Player_builder()
    instance = __Paddle_builder()
    instance.super1_new = instance.new
    instance.new = sub(game)
        m.super1_new(game)
        m.name = "Player"
        m.position.x = 50
        m.position.y = invalid
    end sub
    instance.super1_getFrontColliderXOffset = instance.getFrontColliderXOffset
    instance.getFrontColliderXOffset = function() as float
        return m.width / 2 - 1
    end function
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt)
        if m.position.y < m.bounds.top + m.height / 2
            m.position.y = m.bounds.top + m.height / 2
            m.velocity.y = 0
        end if
        if m.position.y > m.bounds.bottom - m.height / 2
            m.position.y = m.bounds.bottom - m.height / 2
            m.velocity.y = 0
        end if
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input as object)
        m.velocity.y = input.y * 3.5
    end sub
    return instance
end function
function Player(game)
    instance = __Player_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Player.bs.map