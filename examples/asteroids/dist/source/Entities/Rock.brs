function __Rock_builder()
    instance = __SpaceEntity_builder()
    instance.super1_new = instance.new
    instance.new = sub(game)
        m.super1_new(game)
        m.level = 0
        m.rockCollider = invalid
        m.rockImage = invalid
        m.totalAliveTime = 0
        m.rotXFlavor = 0
        m.rotYFlavor = 0
        m.OkToBounce = true
        m.bounceTimeOut = 2
        m.maxLifeSeconds = 30
        m.name = "Rock"
        m.rotXFlavor = rnd(0) / 5
        m.rotYFlavor = rnd(0) / 5
    end sub
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.position = args.position
        m.rotation = BGE_Math_Vector(0, 0, 2 * BGE_Math_Pi())
        if invalid <> args.rotation
            m.rotation = args.rotation
        end if
        if invalid <> args.rotationalThrust and 0 <> args.rotationalThrust
            m.rotationalThrust = args.rotationalThrust
        else
            m.rotationalThrust = rnd(2) - 1
        end if
        if m.rotationalThrust = 0
            m.rotationalThrust = - 1
        end if
        m.rotationalThrust = BGE_Math_Clamp(m.rotationalThrust, - 0.5, 0.5)
        m.level = 1
        if invalid <> args.level
            m.level = args.level
        end if
        m.speed = 1
        if invalid <> args.speed
            m.speed = args.speed
        end if
        if invalid <> args.repositionable
            m.repositionable = args.repositionable
        end if
        m.velocity.x = m.speed * cos(m.rotation.z)
        m.velocity.y = m.speed * sin(m.rotation.z)
        rockBitmap = m.game.getBitmap("rock")
        rockWidth = rockBitmap.GetWidth()
        rockHeight = rockBitmap.GetHeight()
        m.scale = BGE_Math_createScaleVector(1 / (m.level * 2))
        size = BGE_Math_Min(rockWidth, rockHeight) * m.scale.x
        m.width = rockWidth
        m.height = rockHeight
        m.rockCollider = m.addCircleCollider("rock", size / 2)
        region = CreateObject("roRegion", rockBitmap, 0, 0, rockWidth, rockHeight)
        region.SetPreTranslation(- rockWidth / 2, - rockHeight / 2)
        m.rockImage = m.addImage("rock", region, {})
        m.rockImage.enabled = false
    end sub
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt)
        m.rockImage.enabled = true
        m.super1_onUpdate(dt)
        m.totalAliveTime += dt
        newScaleX = sin(m.totalAliveTime) * (m.rotXFlavor) + 1
        newScaleY = - sin(m.totalAliveTime) * (m.rotYFlavor) + 1
        m.rockImage.scale.x = newScaleX
        m.rockImage.scale.y = newScaleY
        if m.totalAliveTime > m.maxLifeSeconds
            m.dieOutOfBounds = true
        end if
        m.bounceTimeOut -= dt
        if m.bounceTimeOut < 0
            m.bounceTimeOut = 0
        end if
    end sub
    instance.super1_onCollision = instance.onCollision
    instance.onCollision = sub(colliderName as string, other_colliderName as string, other_entity as object)
        if other_entity.name = "Bullet"
            m.game.postGameEvent("rock_hit", {
                rock: m
                bullet: other_entity
            })
        end if
        if other_entity.name = "Rock" and m.bounceTimeOut <= 0
            oldVelocity = m.velocity.copy()
            m.velocity = other_entity.velocity.copy()
            other_entity.velocity = oldVelocity
            m.bounceTimeOut = 2
            other_entity.bounceTimeOut = 2
        end if
    end sub
    return instance
end function
function Rock(game)
    instance = __Rock_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Rock.bs.map