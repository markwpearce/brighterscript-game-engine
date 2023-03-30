function __PolygonRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = function(game) as void
        m.super1_new(game)
        m.polygonEntities = []
        m.polygonCount = 20
        m.totalEntities = 0
        m.drawMode = 3
        m.sizeConfig = {
            change: false
            size: 100
        }
        m.polygonsLabel = invalid
        m.drawModeLabel = invalid
        m.name = "PolygonRoom"
        m.polygonsLabel = BGE_UI_Label(m.game)
        m.drawModeLabel = BGE_UI_Label(m.game)
    end function
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.getRandomPolygons()
        m.polygonsLabel.customPosition = true
        m.polygonsLabel.customX = m.game.canvas.getWidth() / 2
        m.polygonsLabel.customY = 100
        m.polygonsLabel.drawableText.alignment = "center"
        m.game.gameUi.addChild(m.polygonsLabel)
        m.drawModeLabel.customPosition = true
        m.drawModeLabel.customX = m.game.canvas.getWidth() / 2
        m.drawModeLabel.customY = m.game.canvas.getHeight() - 200
        m.drawModeLabel.drawableText.alignment = "center"
        m.game.gameUi.addChild(m.drawModeLabel)
    end function
    instance.getRandomPolygons = sub()
        for each polygon in m.polygonEntities
            m.game.destroyEntity(polygon)
        end for
        m.polygonEntities = []
        for i = 0 to m.polygonCount - 1
            x = rnd(m.game.screen.GetWidth())
            y = rnd(m.game.screen.GetHeight())
            poly = m.game.addEntity(PolygonEntity(m.game), {
                x: x
                y: y
                sizeConfig: m.sizeConfig
            })
            m.polygonEntities.push(poly)
            m.totalEntities++
            poly.setDrawMode(m.drawMode)
        end for
        m.polygonsLabel.setText("Polygons: " + bslib_toString(m.polygonEntities.count()))
        m.drawModeLabel.setText("DrawMode: " + bslib_toString(m.drawMode))
    end sub
    instance.changeDrawMode = sub()
        m.drawMode = (m.drawMode + 1)
        if m.drawMode > 7
            m.drawMode = 1
        end if
        for each polygon in m.polygonEntities
            polygon.setDrawMode(m.drawMode)
        end for
        m.drawModeLabel.setText("DrawMode: " + bslib_toString(m.drawMode))
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input)
        if not input.press
            if input.isButton("play")
                m.sizeConfig.change = not input.release
            end if
            return
        end if
        m.sizeConfig.change = false
        if input.isButton("ok")
            m.getRandomPolygons()
        else if input.isButton("options")
            m.changeDrawMode()
        else if input.isButton("up")
            m.polygonCount = int(m.polygonCount * 1.2)
            m.getRandomPolygons()
        else if input.isButton("down")
            m.polygonCount = int(m.polygonCount / 1.2)
            m.getRandomPolygons()
        else if input.isButton("fastforward")
            m.game.changeRoom("SpriteRoom")
        end if
    end sub
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = function(event as string, data as object)
    end function
    instance.super1_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = function(newRoom as object) as void
        m.game.gameUi.removeChild(m.drawModeLabel)
        m.game.gameUi.removeChild(m.polygonsLabel)
    end function
    return instance
end function
function PolygonRoom(game)
    instance = __PolygonRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./PolygonRoom.bs.map