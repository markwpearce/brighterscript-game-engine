function __WalkerEntity_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game) as void
        m.super0_new(game)
        m.walker = invalid
        m.animationFrameRate = 20
        m.direction = "right"
        m.action = "stand"
        m.movement = {
            x: 0
            y: 0
        }
        m.speed = 10
        m.name = "Walker"
    end function
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = function(args) as void
        m.position.y = args.y
        m.position.x = args.x
        m.zIndex = 1
        m.walker = m.addSprite("walkingsprite", m.game.getBitmap("walkingsprite"), 144, 180)
        m.walker.setScale(args.scale)
        m.walker.applyPreTranslation(- 72, - 180)
        m.walker.addAnimation("stand_right", {
            startFrame: 0
            frameCount: 1
        }, m.animationFrameRate, "forward")
        m.walker.addAnimation("stand_left", {
            startFrame: 17
            frameCount: 1
        }, m.animationFrameRate, "forward")
        m.walker.addAnimation("stand_down", {
            startFrame: 18
            frameCount: 1
        }, m.animationFrameRate, "forward")
        m.walker.addAnimation("stand_up", {
            startFrame: 27
            frameCount: 1
        }, m.animationFrameRate, "forward")
        m.walker.addAnimation("walk_right", {
            startFrame: 1
            frameCount: 8
        }, m.animationFrameRate, "loop")
        m.walker.addAnimation("walk_left", {
            startFrame: 9
            frameCount: 8
        }, m.animationFrameRate, "loop")
        m.walker.addAnimation("walk_down", {
            startFrame: 19
            frameCount: 8
        }, m.animationFrameRate, "loop")
        m.walker.addAnimation("walk_up", {
            startFrame: 28
            frameCount: 8
        }, m.animationFrameRate, "loop")
        m.walker.color = BGE_getRandomColorRGB()
    end function
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = function(dt as float) as void
        m.walker.playAnimation(m.action + "_" + m.direction)
    end function
    instance.super0_onInput = instance.onInput
    instance.onInput = function(input as object)
        m.velocity.x = input.x * m.speed
        m.velocity.y = input.y * m.speed
        if input.isDirectionalArrow()
            m.direction = input.button
            m.action = "walk"
        end if
        if not input.held
            m.action = "stand"
        end if
    end function
    return instance
end function
function WalkerEntity(game)
    instance = __WalkerEntity_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./WalkerEntity.bs.map