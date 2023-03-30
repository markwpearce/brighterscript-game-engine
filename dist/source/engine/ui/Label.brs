function __BGE_UI_Label_builder()
    instance = __BGE_UI_UiWidget_builder()
    instance.super1_new = instance.new
    instance.new = sub(game as object)
        m.super1_new(game)
        m.drawableText = invalid
        m.drawableText = BGE_DrawableText(m, m.canvas)
    end sub
    instance.setText = sub(text = "" as string)
        m.drawableText.text = text
    end sub
    ' Set the canvas this UIWidget Draws to
    '
    ' @param {object} [canvas=invalid] The canvas this should draw to - if invalid, then will draw to the game canvas
    instance.super1_setCanvas = instance.setCanvas
    instance.setCanvas = sub(canvas = invalid as object)
        m.super1_setCanvas(canvas)
        if invalid <> m.drawableText
            m.drawableText.setCanvas(m.canvas)
        end if
    end sub
    instance.super1_draw = instance.draw
    instance.draw = sub(parent = invalid as object)
        if invalid <> m.drawableText
            m.drawableText.draw()
            size = m.drawableText.getDrawnSize()
            m.width = size.width
            m.height = size.height
        end if
    end sub
    return instance
end function
function BGE_UI_Label(game as object)
    instance = __BGE_UI_Label_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Label.bs.map