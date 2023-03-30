function __PolygonEntity_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game) as void
        m.super0_new(game)
        m.sizeConfig = invalid
        m.polygonDrawable = invalid
        m.clockWise = 1
        m.rotSpeed = 1
        m.name = "Polygon"
        m.clockWise = bslib_ternary((rnd(2) = 1), 1, - 1)
        m.rotSpeed = rnd(10) + 1
    end function
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = function(deltaTime as float) as void
        m.rotation.z += m.clockWise * deltaTime * BGE_Math_PI() * m.rotSpeed
        if invalid = m.sizeConfig or not m.sizeConfig.change
            return
        end if
        changedPoints = []
        i = 0
        for each point in m.polygonDrawable.points
            factor = m.clockWise
            if int(m.game.getTotalTime() / 5) mod 2 = 0
                factor *= - 1
            end if
            if i mod 2 = 0
                factor *= - 1
            end if
            changedPoints.push({
                x: point.x + deltaTime * 10 * factor
                y: point.y + deltaTime * 10 * factor
            })
            i++
        end for
        m.polygonDrawable.points = changedPoints
    end function
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.position.y = args.y
        m.position.x = args.x
        m.sizeConfig = args.sizeConfig
        m.polygonDrawable = BGE_DrawablePolygon(m, m.game.getCanvas(), m.getRandomPolygon(7))
        m.addImageObject("polygon", m.polygonDrawable)
        m.polygonDrawable.color = BGE_getRandomColorRGB()
        m.polygonDrawable.drawModeMask = 3
        m.polygonDrawable.outlineRGBA = BGE_getRandomColorRGB()
    end function
    instance.getRandomPolygon = function(points as integer) as object
        poly = []
        points = rnd(points * 2) + 2
        maxSize = m.sizeConfig.size
        for i = 0 to points - 1
            poly.push({
                x: rnd(maxSize)
                y: rnd(maxSize)
            })
        end for
        return poly
    end function
    instance.setDrawMode = sub(drawMode as integer)
        m.polygonDrawable.drawModeMask = drawMode
    end sub
    instance.getRegularPolygon = function(points as integer) as object
        poly = []
        maxSize = m.sizeConfig.size
        radius = maxSize / 2
        for i = 0 to points - 1
            poly.push({
                x: radius * sin(BGE_Math_PI() * 2 * i / points)
                y: radius * cos(BGE_Math_PI() * 2 * i / points)
            })
        end for
        return poly
    end function
    return instance
end function
function PolygonEntity(game)
    instance = __PolygonEntity_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./PolygonEntity.bs.map