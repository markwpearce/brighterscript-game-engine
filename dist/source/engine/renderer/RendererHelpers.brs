function __BGE_TriangleBitmap_builder()
    instance = __BGE_Math_Triangle_builder()
    ' roBitmap
    instance.super0_new = instance.new
    instance.new = sub(bitmap as object, points as object)
        m.super0_new(points)
        m.bitmap = invalid
        m.bitmap = bitmap
    end sub
    return instance
end function
function BGE_TriangleBitmap(bitmap as object, points as object)
    instance = __BGE_TriangleBitmap_builder()
    instance.new(bitmap, points)
    return instance
end function
function __BGE_RegionWithId_builder()
    instance = {}
    ' roRegion
    instance.new = sub(region as object, id = "" as string)
        m.region = invalid
        m.id = invalid
        m.region = region
        m.id = id
    end sub
    return instance
end function
function BGE_RegionWithId(region as object, id = "" as string)
    instance = __BGE_RegionWithId_builder()
    instance.new(region, id)
    return instance
end function'//# sourceMappingURL=./RendererHelpers.bs.map