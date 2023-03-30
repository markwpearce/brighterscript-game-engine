function __GhostRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = function(game) as void
        m.super1_new(game)
        m.ghosts = []
        m.ghostsLabel = invalid
        m.name = "GhostRoom"
        m.ghostsLabel = BGE_UI_Label(m.game)
    end function
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.ghostsLabel.customPosition = true
        m.ghostsLabel.customX = m.game.canvas.getWidth() / 2
        m.ghostsLabel.customY = 100
        m.ghostsLabel.drawableText.alignment = "center"
        m.game.gameUi.addChild(m.ghostsLabel)
        m.addGhosts(100)
    end function
    instance.addGhosts = sub(num)
        for i = 0 to num - 1
            x = rnd(m.game.screen.getWidth())
            y = rnd(m.game.screen.getHeight())
            ghost = BGE_GameEntity(m.game)
            ghost.name = "Ghost"
            m.ghosts.push(m.game.addEntity(ghost))
        end for
        m.ghostsLabel.setText("Ghosts: " + bslib_toString(m.ghosts.count()))
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.press
            if input.isButton("ok")
                m.addGhosts(100)
            else if input.isButton("fastforward")
                m.game.changeRoom("RectangleRoom")
            end if
        end if
    end sub
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = function(event as string, data as object)
    end function
    instance.super1_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = function(newRoom as object) as void
        m.game.gameUi.removeChild(m.ghostsLabel)
        m.ghosts = []
    end function
    return instance
end function
function GhostRoom(game)
    instance = __GhostRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./GhostRoom.bs.map