' @module BGE
function __BGE_DrawableLine_builder()
    instance = __BGE_Drawable_builder()
    instance.super0_new = instance.new
    instance.new = sub(owner as object, canvasBitmap as object, startPos as object, endPos as object, args = {} as object)
        m.super0_new(owner, canvasBitmap, args)
        m.startPosition = BGE_Math_Vector()
        m.endPosition = BGE_Math_Vector()
        m.startPosition = startPos
        m.endPosition = endPos
        m.append(args)
    end sub
    instance.super0_draw = instance.draw
    instance.draw = sub(additionalRotation = invalid as object)
        if not m.enabled
            return
        end if
        rgba = m.getFillColorRGBA()
        'TODO: maybe deal with offset here?
        m.drawTo.DrawLine(m.startPosition.x, m.startPosition.y, m.endPosition.x, m.endPosition.y, rgba)
    end sub
    instance.super0_addToScene = instance.addToScene
    instance.addToScene = sub(renderer as object)
        m.addSceneObjectToRenderer(BGE_SceneObjectLine(m.getSceneObjectName("line"), m), renderer)
    end sub
    return instance
end function
function BGE_DrawableLine(owner as object, canvasBitmap as object, startPos as object, endPos as object, args = {} as object)
    instance = __BGE_DrawableLine_builder()
    instance.new(owner, canvasBitmap, startPos, endPos, args)
    return instance
end function'//# sourceMappingURL=./DrawableLine.bs.map