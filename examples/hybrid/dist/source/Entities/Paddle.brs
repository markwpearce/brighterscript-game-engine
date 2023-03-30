function __Paddle_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.width = invalid
        m.height = 0
        m.boundsOffset = 50
        m.bounds = {
            top: 50
            bottom: 720 - 50
        }
        m.bounds = {
            top: m.boundsOffset
            bottom: m.game.screen.getHeight() - m.boundsOffset
        }
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.position.y = m.game.getCanvas().GetHeight() / 2
        bm_paddle = m.game.getBitmap("paddle")
        m.width = bm_paddle.GetWidth()
        m.height = bm_paddle.GetHeight()
        m.addRectangleCollider("front", 1, m.height, m.getFrontColliderXOffset(), m.height / 2)
        m.addRectangleCollider("top", m.width - 2, 1, - m.width / 2, m.height / 2)
        m.addRectangleCollider("bottom", m.width - 2, 1, - m.width / 2, - m.height / 2)
        region = CreateObject("roRegion", bm_paddle, 0, 0, m.width, m.height)
        region.SetPreTranslation(- m.width / 2, - m.height / 2)
        m.addImage("main", region, {})
    end sub
    instance.getFrontColliderXOffset = function() as float
        return - m.width / 2
    end function
    return instance
end function
function Paddle(game)
    instance = __Paddle_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Paddle.bs.map