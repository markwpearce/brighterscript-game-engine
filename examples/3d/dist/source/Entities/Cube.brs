function __Cube_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.speed = 1
        m.size = 200
        m.lines = []
        m.doRotation = true
        m.name = "Cube"
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        if invalid <> args.Speed
            m.speed = args.speed
        end if
        if invalid <> args.size
            m.size = args.size
        end if
        s = m.size
        'CUBE
        m.addLineDrawable(BGE_Math_Vector(0, 0, 0), BGE_Math_Vector(s, 0, 0), BGE_ColorsRGB().White)
        m.addLineDrawable(BGE_Math_Vector(0, 0, 0), BGE_Math_Vector(0, s, 0), BGE_ColorsRGB().Red)
        m.addLineDrawable(BGE_Math_Vector(0, 0, 0), BGE_Math_Vector(0, 0, s), BGE_ColorsRGB().Lime)
        m.addLineDrawable(BGE_Math_Vector(s, 0, 0), BGE_Math_Vector(s, s, 0), BGE_ColorsRGB().Blue)
        m.addLineDrawable(BGE_Math_Vector(s, 0, 0), BGE_Math_Vector(s, 0, s), BGE_ColorsRGB().Yellow)
        m.addLineDrawable(BGE_Math_Vector(0, s, 0), BGE_Math_Vector(s, s, 0), BGE_ColorsRGB().Cyan)
        m.addLineDrawable(BGE_Math_Vector(0, s, 0), BGE_Math_Vector(0, s, s), BGE_ColorsRGB().Aqua)
        m.addLineDrawable(BGE_Math_Vector(0, 0, s), BGE_Math_Vector(s, 0, s), BGE_ColorsRGB().Magenta)
        m.addLineDrawable(BGE_Math_Vector(0, 0, s), BGE_Math_Vector(0, s, s), BGE_ColorsRGB().Silver)
        m.addLineDrawable(BGE_Math_Vector(s, s, s), BGE_Math_Vector(s, s, 0), BGE_ColorsRGB().Maroon)
        m.addLineDrawable(BGE_Math_Vector(s, s, s), BGE_Math_Vector(0, s, s), BGE_ColorsRGB().Olive)
        m.addLineDrawable(BGE_Math_Vector(s, s, s), BGE_Math_Vector(s, 0, s), BGE_ColorsRGB().Green)
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        if m.doRotation
            m.rotation.y += deltaTime * m.speed
            m.rotation.x += deltaTime * m.speed
        end if
    end sub
    instance.addLineDrawable = sub(startPos as object, endPos as object, color as integer)
        lineName = "line_" + m.lines.count().toStr().trim()
        lineObj = BGE_DrawableLine(m, m.game.getCanvas(), startPos, endPos)
        lineObj.color = color
        m.lines.push(lineObj)
        m.addImageObject(lineName, lineObj)
    end sub
    instance.super0_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.press
            if input.isButton("ok")
                m.doRotation = not m.doRotation
            end if
        end if
    end sub
    return instance
end function
function Cube(game)
    instance = __Cube_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Cube.bs.map