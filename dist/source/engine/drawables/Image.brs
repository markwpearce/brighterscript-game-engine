' @module BGE
' Used to draw a bitmap image to the screen
function __BGE_Image_builder()
    instance = __BGE_Drawable_builder()
    ' -------------Never To Be Manually Changed-----------------
    ' These values should never need to be manually changed.
    instance.super0_new = instance.new
    instance.new = sub(owner as object, canvasBitmap as object, region as object, args = {} as object)
        m.super0_new(owner, canvasBitmap, args)
        m.region = invalid
        m.region = region
        if m.region <> invalid
            m.width = m.region.getWidth()
            m.height = m.region.getHeight()
        end if
        m.append(args)
    end sub
    instance.super0_getPretranslation = instance.getPretranslation
    instance.getPretranslation = function() as object
        return BGE_Math_Vector(m.region.GetPretranslationX(), m.region.GetPretranslationY())
    end function
    instance.super0_draw = instance.draw
    instance.draw = sub(additionalRotation = invalid as object)
        m.width = m.region.getWidth()
        m.height = m.region.getHeight()
        if m.enabled
            m.drawRegionToCanvas(m.region, additionalRotation)
        end if
    end sub
    instance.super0_addToScene = instance.addToScene
    instance.addToScene = sub(renderer as object)
        m.addSceneObjectToRenderer(BGE_SceneObjectImage(m.getSceneObjectName("image"), m), renderer)
    end sub
    return instance
end function
function BGE_Image(owner as object, canvasBitmap as object, region as object, args = {} as object)
    instance = __BGE_Image_builder()
    instance.new(owner, canvasBitmap, region, args)
    return instance
end function'//# sourceMappingURL=./Image.bs.map