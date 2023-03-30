function __BGE_SceneObjectImage_builder()
    instance = __BGE_SceneObjectBillboard_builder()
    instance.super1_new = instance.new
    instance.new = sub(name as string, drawableObj as object)
        m.super1_new(name, drawableObj, "Bitmap")
        m.drawable = invalid
        m.frameNumber = 0
        m.lastFrameNumberDrawn = 0
    end sub
    instance.getUniqueRegionName = function() as string
        return bslib_toString(m.name) + "_" + bslib_toString(m.frameNumber.toStr())
    end function
    instance.getRegionWithIdToDraw = function() as object
        regionId = m.getUniqueRegionName()
        drawableRegion = BGE_RegionWithId(m.drawable.region, regionId)
        return drawableRegion
    end function
    instance.super1_afterDraw = instance.afterDraw
    instance.afterDraw = sub()
        m.lastFrameNumberDrawn = m.frameNumber
    end sub
    instance.super1_didRegionToDrawChange = instance.didRegionToDrawChange
    instance.didRegionToDrawChange = function() as boolean
        return m.lastFrameNumberDrawn <> m.frameNumber
    end function
    return instance
end function
function BGE_SceneObjectImage(name as string, drawableObj as object)
    instance = __BGE_SceneObjectImage_builder()
    instance.new(name, drawableObj)
    return instance
end function'//# sourceMappingURL=./SceneObjectImage.bs.map