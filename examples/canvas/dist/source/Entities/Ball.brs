function __Ball_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game as object) as void
        m.super0_new(game)
        m.direction = invalid
        m.hit_frequency_timer = CreateObject("roTimeSpan")
        m.dead = false
        m.bounds = {
            top: 0
            left: 0
            right: 1280
            bottom: 720
        }
        m.name = "Ball"
    end function
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = function(args as object)
        m.direction = args.direction
        w = m.game.canvas.getWidth()
        h = m.game.canvas.getHeight()
        m.position.x = w / 2
        m.position.y = h / 2
        m.bounds.bottom = h
        m.bounds.right = w
        m.velocity.x = 5.5 * m.direction
        m.velocity.y = 5
        if rnd(2) = 1
            m.velocity.y *= - 1
        end if
        bm_ball = m.game.getBitmap("ball")
        ' bs:disable-next-line
        region = CreateObject("roRegion", bm_ball, 0, 0, bm_ball.GetWidth(), bm_ball.GetHeight())
        region.SetPreTranslation(- bm_ball.GetWidth() / 2, - bm_ball.GetHeight() / 2)
        m.addImage("main", region, {
            color: &hffffff
            alpha: 0
        })
        m.addRectangleCollider("ball_collider", bm_ball.GetWidth(), bm_ball.GetHeight(), - bm_ball.GetWidth() / 2, - bm_ball.GetHeight() / 2)
        m.depth = - 1
    end function
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = function(dt as float)
        image = m.getImage("main")
        collider = m.getCollider("ball_collider")
        ' Increase alpha until full if not at full
        if image.alpha < 255
            image.alpha += 3
        end if
        ' If the ball is hitting the left bounds
        if m.position.x - collider.height / 2 <= m.bounds.left
            m.velocity.x = abs(m.velocity.x)
        end if
        ' If the ball is hitting the right bounds
        if m.position.x + collider.height / 2 >= m.bounds.right
            m.velocity.x = abs(m.velocity.x) * - 1
        end if
        ' If the ball is hitting the top bounds
        if m.position.y - collider.height / 2 <= m.bounds.top
            m.velocity.y = abs(m.velocity.y)
        end if
        ' If the ball is hitting the bottom bounds
        if m.position.y + collider.height / 2 >= m.bounds.bottom
            m.velocity.y = abs(m.velocity.y) * - 1
        end if
    end function
    return instance
end function
function Ball(game as object)
    instance = __Ball_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Ball.bs.map