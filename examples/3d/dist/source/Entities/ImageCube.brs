function __ImageCube_builder()
    instance = __BGE_GameEntity_builder()
    ' z
    instance.super0_new = instance.new
    instance.new = sub(game)
        m.super0_new(game)
        m.speed = 0.5
        m.size = 400
        m.doRotation = false
        m.rotAxisIndex = 2
        m.name = "ImageCube"
    end sub
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        if invalid <> args.Speed
            m.speed = args.speed
        end if
        if invalid <> args.size
            m.size = args.size
        end if
        'm.rotation.y = BGE.Math.Pi()
        'm.rotation.z =
        s = 400
        'm.rotation.x = BGE.Math.DegreesToRadians(-150)
        'SQUARE
        'm.addLineDrawable(new BGE.Math.Vector(0, 0, 0), new BGE.Math.Vector(s, 0, 0), BGE.ColorsRGB().White)
        'm.addLineDrawable(new BGE.Math.Vector(0, 0, 0), new BGE.Math.Vector(0, s, 0), BGE.ColorsRGB().White)
        'm.addLineDrawable(new BGE.Math.Vector(s, 0, 0), new BGE.Math.Vector(s, s, 0), BGE.ColorsRGB().White)
        'm.addLineDrawable(new BGE.Math.Vector(0, s, 0), new BGE.Math.Vector(s, s, 0), BGE.ColorsRGB().White)
        'CUBE
        m.scale.x = m.size / 400
        m.scale.y = m.size / 400
        m.scale.z = m.size / 400
        rokuBitmap = m.game.getBitmap("roku")
        rokuBitmapRegion = CreateObject("roRegion", rokuBitmap, 0, 0, rokuBitmap.getWidth(), rokuBitmap.getHeight())
        halfPi = BGE_Math_halfPI()
        m.addImage("side1", rokuBitmapRegion)
        m.addImage("side2", rokuBitmapRegion, {
            offset: BGE_Math_Vector(s, 0, 0)
            rotation: BGE_Math_Vector(0, - halfPi, 0)
        })
        m.addImage("side3", rokuBitmapRegion, {
            offset: BGE_Math_Vector(s, 0, - s)
            rotation: BGE_Math_Vector(0, 2 * - halfPi, 0)
        })
        m.addImage("side4", rokuBitmapRegion, {
            offset: BGE_Math_Vector(0, 0, - s)
            rotation: BGE_Math_Vector(0, 3 * - halfPi, 0)
        })
        m.addImage("top", rokuBitmapRegion, {
            offset: BGE_Math_Vector(0, 0, - s)
            rotation: BGE_Math_Vector(halfPi, 0, 0)
        })
        m.addImage("bottom", rokuBitmapRegion, {
            offset: BGE_Math_Vector(0, - s, 0)
            rotation: BGE_Math_Vector(- halfPi, 0, 0)
        })
    end sub
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        if m.doRotation
            rotAxes = [
                "x"
                "y"
                "z"
            ]
            rotAxis = rotAxes[m.rotAxisIndex]
            m.rotation[rotAxis] += deltaTime * m.speed
            otherotAxisIndex = m.rotAxisIndex + 1
            if otherotAxisIndex > 2
                otherotAxisIndex = 0
            end if
            rotAxis = rotAxes[otherotAxisIndex]
            m.rotation[rotAxis] += deltaTime * m.speed
        end if
    end sub
    instance.super0_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.press
            if input.isButton("ok")
                m.doRotation = not m.doRotation
            else if input.isButton("options")
                m.rotAxisIndex += 1
                if m.rotAxisIndex > 2
                    m.rotAxisIndex = 0
                end if
            end if
        end if
    end sub
    return instance
end function
function ImageCube(game)
    instance = __ImageCube_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./ImageCube.bs.map