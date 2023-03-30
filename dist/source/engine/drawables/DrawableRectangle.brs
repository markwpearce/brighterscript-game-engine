' @module BGE
function __BGE_DrawableRectangle_builder()
    instance = __BGE_DrawableWithOutline_builder()
    instance.super1_new = instance.new
    instance.new = sub(owner as object, canvasBitmap as object, width as float, height as float, args = {} as object)
        m.super1_new(owner, canvasBitmap, args)
        m.tempCanvas = invalid
        m.lastWidth = 0
        m.lastHeight = 0
        m.width = width
        m.height = height
        m.append(args)
    end sub
    instance.super1_draw = instance.draw
    instance.draw = sub(additionalRotation = invalid as object)
        if not m.enabled
            return
        end if
        if m.width = m.lastWidth and m.height = m.lastHeight and not m.shouldRedraw
            m.drawRegionToCanvas(m.tempCanvas, additionalRotation)
            return
        end if
        m.lastWidth = m.width
        m.lastHeight = m.height
        m.tempCanvas = CreateObject("roBitmap", {
            width: m.width
            height: m.height
            AlphaEnable: true
        })
        rgba = m.getFillColorRGBA()
        m.tempCanvas.drawRect(0, 0, m.width, m.height, rgba)
        if m.drawOutline
            BGE_DrawRectangleOutline(m.tempCanvas, 0, 0, m.width, m.height, m.outlineRGBA)
        end if
        m.drawRegionToCanvas(m.tempCanvas, additionalRotation)
        m.shouldRedraw = false
    end sub
    return instance
end function
function BGE_DrawableRectangle(owner as object, canvasBitmap as object, width as float, height as float, args = {} as object)
    instance = __BGE_DrawableRectangle_builder()
    instance.new(owner, canvasBitmap, width, height, args)
    return instance
end function'//# sourceMappingURL=./DrawableRectangle.bs.map