function __BGE_TagList_builder()
    instance = {}
    instance.new = sub()
        m.tags = []
    end sub
    instance.clear = sub()
        m.tags.clear()
    end sub
    instance.add = sub(tagName as string)
        if not m.hasTag(tagName)
            m.tags.push(lcase(tagName))
        end if
    end sub
    instance.remove = sub(tagName as string)
        tagName = lcase(tagName)
        i = 0
        for each tag in m.tags
            if tag = tagName
                m.tags.delete(i)
                return
            end if
            i++
        end for
        return
    end sub
    instance.contains = function(tagName as string) as boolean
        tagName = lcase(tagName)
        for each tag in m.tags
            if tag = tagName
                return true
            end if
        end for
        return false
    end function
    instance.count = function() as integer
        return m.tags.count()
    end function
    return instance
end function
function BGE_TagList()
    instance = __BGE_TagList_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./TagList.bs.map