function __RectangleRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = function(game) as void
        m.super1_new(game)
        m.rectangles = []
        m.rows = 2
        m.cols = 2
        m.rectanglesLabel = invalid
        m.name = "RectangleRoom"
        m.rectanglesLabel = BGE_UI_Label(m.game)
    end function
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.getRectangles()
        m.rectanglesLabel.customPosition = true
        m.rectanglesLabel.customX = m.game.canvas.getWidth() / 2
        m.rectanglesLabel.customY = 100
        m.rectanglesLabel.drawableText.alignment = "center"
        m.game.gameUi.addChild(m.rectanglesLabel)
    end function
    instance.getRectangles = sub()
        for each rectangle in m.rectangles
            m.game.destroyEntity(rectangle)
        end for
        m.rectangles = []
        rectWidth = m.game.getCanvas().getWidth() / m.cols
        rectHeight = m.game.getCanvas().getHeight() / m.rows
        for i = 0 to m.rows - 1
            for j = 0 to m.cols - 1
                x = j * rectWidth
                y = i * rectHeight
                rect = m.game.addEntity(RectangleEntity(m.game), {
                    x: x
                    y: y
                    width: rectWidth
                    height: rectHeight
                })
                m.rectangles.push(rect)
            end for
        end for
        m.rectanglesLabel.setText("Rectangles: " + bslib_toString(m.rectangles.count()))
    end sub
    instance.changeColors = sub()
        for each rect in m.rectangles
            rect.modifyColor(m.game.getDeltaTime())
        end for
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input)
        if not input.press
            if input.isButton("play")
                m.changeColors()
            end if
            return
        end if
        if input.isButton("ok")
            m.getRectangles()
        else if input.isButton("options")
            m.changeColors()
        else if input.isButton("up")
            m.rows++
            m.cols++
            m.getRectangles()
        else if input.isButton("down")
            m.cols--
            m.rows--
            m.getRectangles()
        else if input.isButton("fastforward")
            m.game.changeRoom("PolygonRoom")
        end if
    end sub
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = function(event as string, data as object)
    end function
    instance.super1_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = function(newRoom as object) as void
        m.game.gameUi.removeChild(m.rectanglesLabel)
    end function
    return instance
end function
function RectangleRoom(game)
    instance = __RectangleRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./RectangleRoom.bs.map