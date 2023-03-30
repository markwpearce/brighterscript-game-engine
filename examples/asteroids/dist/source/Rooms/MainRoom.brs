function __MainRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = sub(game)
        m.super1_new(game)
        m.game_started = false
        m.player = invalid
        m.rocks = []
        m.timeSinceLastRock = 0
        m.timeBetweenRocks = 10
        m.debugEnabled = false
        m.backgroundImage = invalid
        m.maxBackgroundOffset = 100
        m.name = "MainRoom"
    end sub
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.game.addEntity(PauseHandler(m.game))
        m.game.addEntity(ScoreHandler(m.game))
        screenWidth = m.game.screen.getWidth()
        screenHeight = m.game.screen.getHeight()
        backgroundBmp = m.game.getBitmap("background")
        region = CreateObject("roRegion", backgroundBmp, 0, 0, backgroundBmp.getWidth(), backgroundBmp.getHeight())
        region.SetScaleMode(1)
        region.SetPreTranslation(- backgroundBmp.getWidth() / 2, - backgroundBmp.getHeight() / 2)
        m.backgroundImage = m.addImage("background", region, {})
        m.backgroundImage.offset.x = m.game.screen.GetWidth() / 2
        m.backgroundImage.offset.y = screenHeight / 2
        m.backgroundImage.offset.z = - 10
        m.updateBackground(BGE_Math_Vector(screenWidth / 2, screenHeight / 2))
        m.timeSinceLastRock = m.timeBetweenRocks
    end sub
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt)
        if m.game_started and not BGE_isValidEntity(m.player)
            m.player = m.game.addEntity(Player(m.game))
            m.addNewRock()
        end if
        if m.game_started
            if not m.player.dead
                m.timeSinceLastRock += dt
                if m.timeSinceLastRock >= m.timeBetweenRocks
                    m.timeSinceLastRock = 0
                    m.addNewRock()
                end if
            end if
            m.updateBackground(m.player.position)
        end if
    end sub
    instance.updateBackground = sub(point as object)
        playerDistFromCenter = m.game.canvas.renderer.getCanvasCenter().subtract(point).length()
        maxDist = m.game.screen.getHeight() / 2
        playerDistFromCenter = BGE_Math_Clamp(playerDistFromCenter, 0, maxDist)
        newScale = BGE_Tweens_CubicTween(1.2, 1, playerDistFromCenter, maxDist)
        m.backgroundImage.scale = BGE_Math_createScaleVector(newScale)
    end sub
    instance.super1_onDrawEnd = instance.onDrawEnd
    instance.onDrawEnd = sub(renderObj as object)
        if not m.game_started
            frameCenter = renderObj.getCanvasCenter()
            if invalid <> m.player
                renderObj.DrawText("Game Over!", frameCenter.x, frameCenter.y - 20, BGE_Colors().White, m.game.getFont("default"), "center")
            end if
            renderObj.DrawText("Press OK To Play", frameCenter.x, frameCenter.y + 20, BGE_Colors().White, m.game.getFont("default"), "center")
            renderObj.DrawText("Move: Arrows | Shoot: OK", frameCenter.x, frameCenter.y + 60, BGE_Colors().White, m.game.getFont("default"), "center")
        end if
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.isButton("back")
            m.game.End()
        end if
        if input.press and input.isButton("replay")
            m.debugEnabled = not m.debugEnabled
            m.game.debugDrawEntityDetails(m.debugEnabled)
            m.game.debugDrawColliders(m.debugEnabled)
            m.game.debugShowUi(m.debugEnabled)
        end if
        if not m.game_started and input.isButton("ok")
            m.game_started = true
            m.game.postGameEvent("game_start")
        end if
    end sub
    instance.clearEntities = sub()
        if invalid <> m.player
            m.game.destroyEntity(m.player)
        end if
        for each rockOld in m.rocks
            m.game.destroyEntity(rockOld)
        end for
        m.rocks = []
    end sub
    instance.addNewRock = sub(position = invalid as object, level = 1 as integer, rotationalThrust = 0 as integer, parentRotation = invalid as object)
        height = m.game.getCanvas().GetHeight()
        width = m.game.getCanvas().GetWidth()
        repositionable = true
        rockPosition = BGE_Math_Vector()
        zRot = - BGE_Math_HalfPI() / 2 ' about 45 degrees
        if position = invalid
            repositionable = false
            ' generate a position outside the screen
            q = rnd(2)
            fudge = 200
            randomY = rnd(height)
            rockPosition.x -= fudge
            rockPosition.y = randomY
            if q = 2
                rockPosition.x = width + fudge
                rockPosition.y = randomY
                zRot = - 1 * (3 * BGE_Math_PI() / 4) ' 115 degrees
            end if
            if randomY < (height / 2)
                ' Rock is in lower part of screen, switch rotation so it goes up
                zRot = - zRot
            end if
        else
            rockPosition = position.copy()
        end if
        rockRotation = BGE_Math_Vector(0, 0, zRot) ' + rnd(0.1) - 0.05)
        if parentRotation <> invalid
            rockRotation = parentRotation.copy()
            rockRotation.z += (BGE_Math_Pi() / 4) * rotationalThrust
        end if
        m.rocks.push(m.game.addEntity(Rock(m.game), {
            position: rockPosition
            level: level
            rotationalThrust: rotationalThrust
            rotation: rockRotation
            repositionable: repositionable
        }))
    end sub
    instance.addExplosion = sub(rockToDie as object, imageScale = 1 as float, soundName = invalid)
        m.game.addEntity(Explosion(m.game), {
            position: rockToDie.position
            imageScale: imageScale
            rotation: rockToDie.rotation
            soundName: soundName
        })
    end sub
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = sub(event as string, data as object)
        if event = "game_over"
            m.game_started = false
            m.addExplosion(m.player, 5, "die")
        end if
        if event = "game_start"
            m.clearEntities()
        end if
        if event = "rock_hit"
            rockToDie = data.rock
            nextLevel = rockToDie.level + 1
            if nextLevel < 4
                m.addNewRock(rockToDie.position, nextLevel, 1, rockToDie.rotation)
                m.addNewRock(rockToDie.position, nextLevel, - 1, rockToDie.rotation)
            end if
            m.addExplosion(rockToDie, 3 / rockToDie.level)
            i = 0
            indexOfRockToDie = - 1
            for each rockEntity in m.rocks
                if rockEntity.id = rockToDie.id
                    indexOfRockToDie = i
                    exit for
                end if
                i++
            end for
            if indexOfRockToDie <> - 1
                m.rocks.delete(indexOfRockToDie)
            end if
            m.game.destroyEntity(rockToDie)
            m.game.destroyEntity(data.bullet)
        end if
    end sub
    return instance
end function
function MainRoom(game)
    instance = __MainRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./MainRoom.bs.map