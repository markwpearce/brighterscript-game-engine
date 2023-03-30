function __Ball_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game as object)
        m.super0_new(game)
        m.direction = invalid
        m.hit_frequency_timer = CreateObject("roTimeSpan")
        m.dead = false
        m.boundsOffset = 50
        m.bounds = {
            top: 50
            bottom: 720 - 50
        }
        m.name = "Ball"
        m.bounds = {
            top: m.boundsOffset
            bottom: m.game.screen.getHeight() - m.boundsOffset
        }
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args as object)
        m.direction = args.direction
        m.position.x = m.game.screen.getWidth() / 2
        m.position.y = m.game.screen.getHeight() / 2
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
        m.addRectangleCollider("ball_collider", bm_ball.GetWidth(), bm_ball.GetHeight(), - bm_ball.GetWidth() / 2, bm_ball.GetHeight() / 2)
    end sub
    instance.super0_onCollision = instance.onCollision
    instance.onCollision = sub(colliderName as string, other_colliderName as string, other_entity as object)
        need_to_play_hit_sound = false
        ' If colliding with the front of the player paddle
        if not m.dead and other_entity.name = "Player" and other_colliderName = "front"
            m.velocity.x = Abs(m.velocity.x)
            need_to_play_hit_sound = true
        end if
        ' If colliding with the front of the computer paddle
        if not m.dead and other_entity.name = "Computer" and other_colliderName = "front"
            m.velocity.x = Abs(m.velocity.x) * - 1
            need_to_play_hit_sound = true
        end if
        ' If colliding with the front or bottom of the either paddle
        if other_entity.name = "Player" or other_entity.name = "Computer"
            if other_colliderName = "top" or other_colliderName = "bottom"
                m.velocity.y = m.velocity.y * - 1
                need_to_play_hit_sound = true
            end if
        end if
        if need_to_play_hit_sound
            m.PlayHitSound()
        end if
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt as float)
        image = m.getImage("main")
        collider = m.getCollider("ball_collider")
        playerEntity = m.game.getEntityByName("Player")
        computerEntity = m.game.getEntityByName("Computer")
        ' Increase alpha until full if not at full
        if image.alpha < 255
            image.alpha += 3
        end if
        ' If the left side of the ball is past the center of the player paddle position
        if invalid <> playerEntity and m.position.x - collider.width / 2 <= playerEntity.position.x
            m.dead = true
            if m.position.x <= - 100
                m.game.postGameEvent("score", {
                    team: 1
                })
                m.game.destroyEntity(m)
                return ' If an entity destroys itself it must return immediately as all internal variables are now invalid
            end if
        end if
        ' If the right side of the ball is past the center of the computer paddle
        if computerEntity <> invalid and m.position.x + collider.width / 2 >= computerEntity.position.x
            m.dead = true
            if m.position.x >= 1280 + 100
                m.game.postGameEvent("score", {
                    team: 0
                })
                m.game.destroyEntity(m)
                return ' If an entity destroys itself it must return immediately as all internal variables are now invalid
            end if
        end if
        ' If the ball is hitting the top bounds
        if m.position.y - collider.height / 2 <= m.bounds.top
            m.velocity.y = abs(m.velocity.y)
            m.PlayHitSound()
        end if
        ' If the ball is hitting the bottom bounds
        if m.position.y + collider.height / 2 >= m.bounds.bottom
            m.velocity.y = abs(m.velocity.y) * - 1
            m.PlayHitSound()
        end if
    end sub
    instance.super0_PlayHitSound = instance.PlayHitSound
    instance.PlayHitSound = function()
        ' Play the hit sound if ball is on screen and didn't already play within the last 100ms
        if m.position.x > 0 and m.position.x < m.game.getCanvas().GetWidth() and m.hit_frequency_timer.TotalMilliseconds() > 100
            m.game.playSound("hit", 50)
            m.hit_frequency_timer.Mark()
        end if
    end function
    instance.super0_onDestroy = instance.onDestroy
    instance.onDestroy = function()
        m.game.playSound("score", 50)
    end function
    return instance
end function
function Ball(game as object)
    instance = __Ball_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Ball.bs.map