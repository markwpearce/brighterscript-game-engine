function __RectangleEntity_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game) as void
        m.super0_new(game)
        m.rectangleDrawable = invalid
        m.color = {
            r: rnd(256)
            g: rnd(256)
            b: rnd(256)
        }
        m.name = "Rectangle"
    end function
    instance.super0_onUpdate = instance.onUpdate
    instance.onUpdate = function(deltaTime as float)
    end function
    instance.super0_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.position.y = args.y
        m.position.x = args.x
        m.rectangleDrawable = BGE_DrawableRectangle(m, m.game.getCanvas(), args.width, args.height)
        m.addImageObject("rectangle", m.rectangleDrawable)
        m.rectangleDrawable.color = BGE_RGBAtoRGBA(m.color.r, m.color.g, m.color.b, 1) / 256
        'm.rectangleDrawable.drawOutline = true
        m.rectangleDrawable.outlineRGBA = m.getRandomColor()
    end function
    instance.getRandomColor = function() as integer
        color% = rnd(256 * 256 * 256)
        return color%
    end function
    instance.modifyColor = sub(delta as float)
        delta = delta * 100
        m.color.r = (m.color.r + delta) mod &hFF
        m.color.g = (m.color.g + delta) mod &hFF
        m.color.b = (m.color.b + delta) mod &hFF
        m.rectangleDrawable.color = BGE_RGBAtoRGBA(m.color.r, m.color.g, m.color.b, 1)
    end sub
    return instance
end function
function RectangleEntity(game)
    instance = __RectangleEntity_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./RectangleEntity.bs.map