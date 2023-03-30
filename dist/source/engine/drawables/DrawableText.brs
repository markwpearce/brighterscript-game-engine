' @module BGE
' Class to draw text
function __BGE_DrawableText_builder()
    instance = __BGE_Drawable_builder()
    ' The text to write on the screen
    ' The Font object to use ( get this from the font registry)
    ' The Horizontal alignment for the text
    instance.super0_new = instance.new
    instance.new = sub(owner as object, canvasBitmap as object, text = "" as string, font = invalid as object, args = {} as object) as void
        m.super0_new(owner, canvasBitmap, args)
        m.text = ""
        m.font = invalid
        m.alignment = "left"
        m.lastTextValue = ""
        m.tempCanvas = invalid
        m.text = text
        m.font = font
        if invalid <> m.owner and invalid <> m.owner.game and invalid = m.font
            m.font = m.owner.game.getFont("default")
        end if
        m.append(args)
    end sub
    instance.super0_draw = instance.draw
    instance.draw = sub(additionalRotation = invalid as object) as void
        if not m.enabled
            return
        end if
        if m.text = m.lastTextValue and invalid <> m.tempCanvas and not m.shouldRedraw
            m.drawRegionToCanvas(m.tempCanvas, additionalRotation, true)
            return
        end if
        m.lastTextValue = m.text
        m.width = m.font.GetOneLineWidth(m.text, 10000)
        m.height = m.font.GetOneLineHeight() * BGE_getNumberOfLinesInAString(m.text)
        m.tempCanvas = CreateObject("roBitmap", {
            width: m.width
            height: m.height
            AlphaEnable: true
        })
        m.owner.game.canvas.renderer.DrawTextTo(m.tempCanvas, m.text, 0, 0, BGE_Colors().White, m.font, "left")
        m.drawRegionToCanvas(m.tempCanvas, additionalRotation, true)
        m.shouldRedraw = false
    end sub
    instance.super0_getWorldPosition = instance.getWorldPosition
    instance.getWorldPosition = function() as object
        ' TODO - Fix this for rotated in Z axis
        position = m.owner.position.add(m.offset) 'super.getWorldPosition()
        if m.alignment = "center"
            position.x -= m.width / 2
        else if m.alignment = "right"
            position.x -= m.height
        end if
        return position
    end function
    return instance
end function
function BGE_DrawableText(owner as object, canvasBitmap as object, text = "" as string, font = invalid as object, args = {} as object)
    instance = __BGE_DrawableText_builder()
    instance.new(owner, canvasBitmap, text, font, args)
    return instance
end function'//# sourceMappingURL=./DrawableText.bs.map