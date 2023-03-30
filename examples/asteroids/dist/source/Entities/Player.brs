function __Player_builder()
    instance = __SpaceEntity_builder()
    ' rocket image points up, so it adds 90 degrees
    instance.super1_new = instance.new
    instance.new = sub(game)
        m.super1_new(game)
        m.rocketCollider = invalid
        m.rocketImage = invalid
        m.rocketOnImage = invalid
        m.thrust = 0
        m.dead = false
        m.acceleration = 2
        m.rotationAdjustment = BGE_Math_halfPI()
        m.name = "Player"
    end sub
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.position.y = m.game.getCanvas().GetHeight() / 2
        m.position.x = m.game.getCanvas().GetWidth() / 2
        rocketBitmap = m.game.getBitmap("rocket")
        rocketOnBitmap = m.game.getBitmap("rocket_on")
        m.width = rocketBitmap.GetWidth()
        m.height = rocketBitmap.GetHeight()
        rocketOnHeight = rocketOnBitmap.getHeight()
        m.rocketCollider = m.addCircleCollider("rocket", m.width / 3)
        region = CreateObject("roRegion", rocketBitmap, 0, 0, m.width, m.height)
        region.SetPreTranslation(- m.width / 2, - m.height / 2)
        m.rocketImage = m.addImage("rocket", region, {})
        regionRocketOn = CreateObject("roRegion", rocketOnBitmap, 0, 0, m.width, rocketOnHeight)
        regionRocketOn.SetPreTranslation(- m.width / 2, - m.height / 2)
        m.rocketOnImage = m.addImage("rocket_on", regionRocketOn, {})
    end sub
    instance.super1_onCollision = instance.onCollision
    instance.onCollision = sub(colliderName as string, other_colliderName as string, other_entity as object)
        if other_entity.name = "Rock" and not m.dead
            m.dead = true
            m.thrust = 0
            m.rotationalThrust = other_entity.rotationalThrust
            m.game.postGameEvent("game_over")
        end if
    end sub
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        m.super1_onUpdate(deltaTime)
        rocketRot = m.getRocketRadRotation()
        m.velocity.x += deltaTime * m.thrust * cos(rocketRot) * m.acceleration
        m.velocity.y += deltaTime * m.thrust * sin(rocketRot) * m.acceleration
        m.rocketImage.enabled = (0 = m.thrust)
        m.rocketOnImage.enabled = (0 <> m.thrust)
        if m.dead
            ' make it spin out in to space
            scale = (10.0 - deltaTime) / 10.0
            m.rocketImage.scale = BGE_Math_createScaleVector(scale * m.rocketImage.scale.x)
        end if
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input as object)
        if not m.dead
            m.rotationalThrust = - input.x
            if input.isButton("up")
                m.thrust = input.y
                m.game.playSound("engine", 50)
            else if input.isButton("ok") and input.press
                m.shoot()
            end if
        end if
    end sub
    instance.getRocketRadRotation = function() as float
        return (m.rotation.z + m.rotationAdjustment)
    end function
    instance.super1_shoot = instance.shoot
    instance.shoot = sub()
        bulletPosition = m.position.copy()
        rocketRot = m.getRocketRadRotation()
        bulletPosition.x += m.rocketCollider.radius * 1.3 * cos(rocketRot)
        bulletPosition.y += m.rocketCollider.radius * 1.3 * sin(rocketRot)
        bulletRotation = m.rotation.add(BGE_Math_Vector(0, 0, m.rotationAdjustment))
        m.game.addEntity(Bullet(m.game), {
            position: bulletPosition
            rotation: bulletRotation
            speed: 10 + Abs(m.velocity.x * m.velocity.y)
        })
    end sub
    return instance
end function
function Player(game)
    instance = __Player_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Player.bs.map