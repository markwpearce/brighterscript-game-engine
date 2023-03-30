function __BGE_ScratchBitmap_builder()
    instance = {}
    instance.new = sub(id as string, w as integer, h as integer)
        m.bitmap = invalid
        m.id = invalid
        m.bitmap = CreateObject("roBitmap", {
            width: w
            height: h
            alphaEnable: true
        })
        m.id = id
    end sub
    return instance
end function
function BGE_ScratchBitmap(id as string, w as integer, h as integer)
    instance = __BGE_ScratchBitmap_builder()
    instance.new(id, w, h)
    return instance
end function
function __BGE_ScratchRegion_builder()
    instance = {}
    instance.new = sub(region as object, scratchBmp as object)
        m.region = invalid
        m.scratchBmp = invalid
        m.region = region
        m.scratchBmp = scratchBmp
    end sub
    instance.getBitmapObject = function() as object
        return m.scratchBmp.bitmap
    end function
    return instance
end function
function BGE_ScratchRegion(region as object, scratchBmp as object)
    instance = __BGE_ScratchRegion_builder()
    instance.new(region, scratchBmp)
    return instance
end function
function __BGE_ZZScratchBitmapPool_builder()
    instance = {}
    instance.new = sub(initialCount = 0)
        m.pool = []
        m.scratchHeight = 1080
        m.scratchWidth = 1920
        m.nextId = 0
        m.reuseBitmaps = false
        m.maxPoolCount = 15
        m.activePoolCount = 0
        for i = 0 to initialCount - 1
            m.addNewBitmapToPool()
        end for
    end sub
    instance.addNewBitmapToPool = sub(w = - 1, h = - 1)
        id = m.nextId.toStr()
        m.nextId++
        if w = - 1
            w = m.scratchWidth
        end if
        if h = - 1
            h = m.scratchHeight
        end if
        m.pool.push(BGE_ScratchBitmap(id, w, h))
    end sub
    instance.getRegion = function(width as float, height as float) as object
        width = BGE_Math_Clamp(fix(width + 1), 256, m.scratchWidth)
        height = BGE_Math_Clamp(fix(height + 1), 256, m.scratchHeight)
        if not m.reuseBitmaps
            bmp = BGE_ScratchBitmap("0", width, height)
            if invalid = bmp
                return invalid
            end if
            region = CreateObject("roRegion", bmp.bitmap, 0, 0, width, height)
            return BGE_ScratchRegion(region, bmp, false)
        end if
        if width > m.scratchWidth or height > m.scratchHeight
            return invalid
        end if
        bmp = invalid
        if m.pool.count() > 0
            i = 0
            for each sb in m.pool
                if sb.bitmap.getWidth() >= width and sb.bitmap.getHeight() >= height
                    bmp = sb
                    exit for
                end if
                i++
            end for
            if bmp <> invalid
                m.pool.delete(i)
            else if m.activePoolCount >= m.maxPoolCount
                ' make some room in the pool
                m.pool.pop()
                m.activePoolCount--
            end if
        end if
        if bmp = invalid
            m.addNewBitmapToPool(width, height)
            bmp = m.pool.pop()
            if bmp = invalid or bmp.bitmap = invalid
                return invalid
            end if
            m.activePoolCount++
        end if
        region = invalid
        if bmp = invalid
            return invalid
        end if
        region = CreateObject("roRegion", bmp.bitmap, 0, 0, width, height)
        if invalid = region
            m.pool.push(bmp)
            return invalid
        end if
        bmp.bitmap.clear(0)
        return BGE_ScratchRegion(region, bmp, true)
    end function
    instance.returnRegion = sub(usedRegion as object)
        if usedRegion = invalid or not m.reuseBitmaps
            return
        end if
        if not usedRegion.fromPool
            return
        end if
        inProgBmp = usedRegion.scratchBmp
        inProgBmp.bitmap.finish()
        m.pool.push(inProgBmp)
    end sub
    instance.returnRegions = sub(usedRegions as object)
        if not m.reuseBitmaps
            return
        end if
        for i = usedRegions.count() - 1 to 0 step - 1
            region = usedRegions[i]
            m.returnRegion(region)
        end for
    end sub
    instance.clearPool = sub()
        m.pool = []
        m.activePoolCount = 0
    end sub
    return instance
end function
function BGE_ZZScratchBitmapPool(initialCount = 0)
    instance = __BGE_ZZScratchBitmapPool_builder()
    instance.new(initialCount)
    return instance
end function

function BGE_getScratchRegion(width as float, height as float) as object
    if width < 1 or height < 1
        return invalid
    end if
    bmp = BGE_ScratchBitmap("temp", width, height)
    if invalid = bmp
        return invalid
    end if
    region = CreateObject("roRegion", bmp.bitmap, 0, 0, width, height)
    return BGE_ScratchRegion(region, bmp)
end function'//# sourceMappingURL=./ScratchBitmap.bs.map