function __Poly_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.speed = 1
        m.minVerts = 3
        m.maxVerts = 7
        m.size = 600
        m.polyDraw = invalid
        m.doRotation = false
        m.name = "Poly"
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        points = [
            ' new BGE.Math.Vector(0, 0, 0),
            ' new BGE.Math.Vector(300, 100, 0),
            'new BGE.Math.Vector(100, 200, 0),
        ]
        numPoints = m.minVerts + rnd(m.maxVerts - m.minVerts) - 1
        halfSize = m.size / 2
        for i = 0 to numPoints
            p = BGE_Math_Vector(rnd(m.size) - halfSize, rnd(m.size) - halfSize, rnd(m.size) - halfSize)
            points.push(p)
        end for
        m.polyDraw = BGE_DrawablePolygon(m, invalid, points)
        m.polyDraw.color = BGE_getRandomColorRGB()
        m.addImageObject("polygon", m.polyDraw)
        m.position.x = - 600 + rnd(1200)
        m.position.y = - 300 + rnd(600)
        m.position.z = - 400 + rnd(800)
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        if m.doRotation
            m.rotation.y += deltaTime * m.speed
            m.rotation.x += deltaTime * m.speed
        end if
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
function Poly(game)
    instance = __Poly_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Poly.bs.map