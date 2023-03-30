function __SpriteRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = function(game) as void
        m.super1_new(game)
        m.walkers = []
        m.spritesLabel = invalid
        m.name = "SpriteRoom"
        m.spritesLabel = BGE_UI_Label(m.game)
    end function
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.spritesLabel.customPosition = true
        m.spritesLabel.customX = m.game.canvas.getWidth() / 2
        m.spritesLabel.customY = 100
        m.spritesLabel.drawableText.alignment = "center"
        m.game.gameUi.addChild(m.spritesLabel)
        m.addWalkers(10)
    end function
    instance.addWalkers = sub(num)
        for i = 0 to num - 1
            x = rnd(m.game.screen.getWidth())
            y = rnd(m.game.screen.getHeight())
            m.walkers.push(m.game.addEntity(WalkerEntity(m.game), {
                x: x
                y: y
                scale: 1
            }))
        end for
        m.spritesLabel.setText("Sprites: " + bslib_toString(m.walkers.count()))
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.press
            if input.isButton("ok")
                m.addWalkers(10)
            else if input.isButton("fastforward")
                m.game.changeRoom("GhostRoom")
            end if
        end if
    end sub
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = function(event as string, data as object)
    end function
    instance.super1_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = function(newRoom as object) as void
        m.game.gameUi.removeChild(m.spritesLabel)
        m.walkers = []
    end function
    return instance
end function
function SpriteRoom(game)
    instance = __SpriteRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./SpriteRoom.bs.map