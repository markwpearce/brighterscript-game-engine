function __BGE_TriangleCacheEntry_builder()
    instance = {}
    instance.new = sub(triangle as object)
        m.triangle = invalid
        m.timeLastUsed = invalid
        m.triangle = Triangle
    end sub
    instance.updateTime = sub(newTime as integer)
        m.timeLastUsed = newTime
    end sub
    return instance
end function
function BGE_TriangleCacheEntry(triangle as object)
    instance = __BGE_TriangleCacheEntry_builder()
    instance.new(triangle)
    return instance
end function
function __BGE_TriangleCache_builder()
    instance = {}
    'roDateTime
    instance.new = sub(cacheKeepSeconds = 60 as integer)
        m.cache = {}
        m.dateTime = invalid
        m.cacheKeepTime = invalid
        m.dateTime = CreateObject("roDateTime")
        m.cacheKeepSeconds = cacheKeepSeconds
    end sub
    instance.getTriangle = function(id as string, points as object) as object
        if id = ""
            return invalid
        end if
        key = m.makeKey(id, points)
        if invalid <> m.cache[key]
            triangleEntry = m.cache[key]
            m.dateTime.mark()
            triangleEntry.updateTime(m.dateTime.asSeconds())
            return triangleEntry.triangle
        end if
        return invalid
    end function
    instance.addTriangle = sub(id as string, points as object, triangleBmp as object)
        if id = "" or invalid = triangleBmp
            return
        end if
        key = m.makeKey(id, points)
        cacheEntry = BGE_TriangleCacheEntry(triangleBmp)
        m.dateTime.mark()
        cacheEntry.updateTime(m.dateTime.asSeconds())
        m.cache[key] = cacheEntry
    end sub
    instance.makeKey = function(id as string, points as object) as string
        return id + "-" + BGE_arrayToStr(points)
    end function
    instance.cleanCache = sub()
        m.dateTime.mark()
        currentTime = m.dateTime.asSeconds()
        for each item in m.cache.items()
            if invalid <> item.value
                cacheEntry = item.value
                timeDelta = currentTime - cacheEntry.timeLastUsed
                if timeDelta >= m.cacheKeepSeconds
                    m.cache.delete(item.key)
                end if
            end if
        end for
    end sub
    return instance
end function
function BGE_TriangleCache(cacheKeepSeconds = 60 as integer)
    instance = __BGE_TriangleCache_builder()
    instance.new(cacheKeepSeconds)
    return instance
end function'//# sourceMappingURL=./TriangleCache.bs.map