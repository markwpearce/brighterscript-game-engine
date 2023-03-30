' @module BGE
' Contains a roku roBitmap which all game objects get drawn to.
function __BGE_Canvas_builder()
    instance = {}
    ' bitmap GameEntity images get drawn to
    ' Position offset from screen coordinates (z value ignored)
    ' Scale (z value ignored)
    ' Renderer for this canvas
    ' Creates a Canvas object and bitmap
    '
    ' @param {integer} canvasWidth - width of canvas
    ' @param {integer} canvasHeight - height of canvas
    instance.new = sub(game as object, canvasWidth as integer, canvasHeight as integer) as void
        m.bitmap = invalid
        m.offset = BGE_Math_Vector()
        m.scale = BGE_Math_Vector(1, 1, 1)
        m.renderer = invalid
        m.game = invalid
        m.game = game
        m.setSize(canvasWidth, canvasHeight)
    end sub
    ' Changes the size of the canvas
    '
    ' @param {integer} canvasWidth - width of canvas
    ' @param {integer} canvasHeight - height of canvas
    instance.setSize = sub(canvasWidth as integer, canvasHeight as integer) as void
        m.setBitmap(CreateObject("roBitmap", {
            width: canvasWidth
            height: canvasHeight
            AlphaEnable: true
        }))
    end sub
    instance.setBitmap = sub(bitmap as object)
        m.bitmap = bitmap
        if invalid = m.renderer
            m.renderer = BGE_Renderer(m.game, m.bitmap)
        else
            m.renderer.draw2d = m.bitmap
        end if
    end sub
    ' Clears the canvas to the given background color
    '
    ' @param {integer} color
    instance.clear = sub(color as integer)
        m.bitmap.Clear(color)
    end sub
    ' Gets the offset of the canvas from the screen
    '
    ' @return {BGE.Math.Vector} - Position offset
    instance.getOffset = function() as object
        return m.offset.copy()
    end function
    ' Gets the scale of the canvas
    '
    ' @return {BGE.Math.Vector} - Scale as object
    instance.getScale = function() as object
        return m.scale.copy()
    end function
    ' Sets the offset of the canvase.
    ' This is as Float to allow incrementing by less than 1 pixel, it is converted to integer internally
    '
    '
    ' @param {float} x - x offset
    ' @param {float} y - y offset
    instance.setOffset = sub(x as float, y as float)
        m.offset.x = x
        m.offset.y = y
    end sub
    ' Sets the scale of the canvas
    '
    ' @param {float} scale_x - horizontal scale
    ' @param {dynamic} [scale_y=invalid] - vertical scale, or if invalid, use the horizontal scale as vertical scale
    instance.setScale = sub(scale_x as float, scale_y = invalid as dynamic)
        if scale_y = invalid or not (rodash_isFloat(scale_Y) or rodash_isInteger(scale_y))
            scale_y = scale_x
        end if
        m.scale.x = scale_x
        m.scale.y = scale_y
    end sub
    ' Gets the width of the underlying bitmap
    '
    ' @return {integer}
    instance.getWidth = function() as integer
        if invalid <> m.bitmap
            return m.bitmap.getWidth()
        end if
        return - 1
    end function
    ' Gets the height of the underlying bitmap
    '
    ' @return {integer}
    instance.getHeight = function() as integer
        if invalid <> m.bitmap
            return m.bitmap.getHeight()
        end if
        return - 1
    end function
    return instance
end function
function BGE_Canvas(game as object, canvasWidth as integer, canvasHeight as integer)
    instance = __BGE_Canvas_builder()
    instance.new(game, canvasWidth, canvasHeight)
    return instance
end function'//# sourceMappingURL=./Canvas.bs.map