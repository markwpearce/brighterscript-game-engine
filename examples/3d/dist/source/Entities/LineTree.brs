function __LineTree_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.size = 100
        m.complexity = 10
        m.lines = []
        m.doRotation = false
        m.name = "LineTree"
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        if invalid <> args.size
            m.size = args.size
        end if
        m.rotation.y = rnd(0)
        top = m.size
        bottom = top / 3
        m.addLineDrawable(BGE_Math_Vector(0, 0, 0), BGE_Math_Vector(0, top, 0), BGE_ColorsRGB().Maroon)
        for i = 1 to m.complexity
            theta = (BGE_Math_PI() * 2 * i) / m.complexity
            m.addLineDrawable(BGE_Math_Vector(cos(theta) * bottom, bottom, sin(theta) * bottom), BGE_Math_Vector(0, top, 0), BGE_ColorsRGB().Green)
        end for
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        if m.doRotation
            m.rotation.y += deltaTime
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
function LineTree(game)
    instance = __LineTree_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./LineTree.bs.map