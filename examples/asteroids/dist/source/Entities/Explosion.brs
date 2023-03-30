function __Explosion_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.explosion = invalid
        m.totalLifeTime = 0
        m.soundName = invalid
        m.name = "Explosion"
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.position = args.position
        m.rotation = args.rotation
        m.soundName = args.soundName
        m.explosion = m.addSprite("boom", m.game.getBitmap("boom"), 128, 128)
        m.explosion.scale = BGE_Math_createScaleVector(args.imageScale)
        m.explosion.applyPreTranslation(- 64, - 80)
        m.explosion.addAnimation("boom", {
            startFrame: 0
            frameCount: 64
        }, 60, "forward")
        m.explosion.offset.z = 10
        m.playExplosion()
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt as float)
        m.totalLifeTime += dt
        if m.totalLifeTime >= 1
            m.invalidate()
        end if
    end sub
    instance.playExplosion = sub()
        explosionName = m.soundName
        if invalid = explosionName
            explosionNum = Rnd(9)
            explosionName = "explosion0" + stri(explosionNum).trim()
        end if
        m.game.playSound(explosionName, 70)
        m.explosion.playAnimation("boom")
    end sub
    return instance
end function
function Explosion(game)
    instance = __Explosion_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Explosion.bs.map