function __BGE_Math_Rectangle_builder()
    instance = __BGE_Math_Vector_builder()
    instance.super0_new = instance.new
    instance.new = sub(x = 0 as float, y = 0 as float, width = 0 as float, height = 0 as float)
        m.super0_new(x, y)
        m.width = 0
        m.height = 0
        m.width = width
        m.height = height
    end sub
    instance.right = function() as float
        return m.x + m.width
    end function
    instance.left = function() as float
        return m.x
    end function
    instance.top = function() as float
        return m.position.y
    end function
    instance.bottom = function() as float
        return m.position.y + m.height
    end function
    instance.center = function() as object
        return BGE_Math_Vector(m.x + m.width / 2, m.y + m.height / 2)
    end function
    instance.super0_copy = instance.copy
    instance.copy = function() as object
        return BGE_Math_Rectangle(m.x, m.y, m.width, m.height)
    end function
    return instance
end function
function BGE_Math_Rectangle(x = 0 as float, y = 0 as float, width = 0 as float, height = 0 as float)
    instance = __BGE_Math_Rectangle_builder()
    instance.new(x, y, width, height)
    return instance
end function'//# sourceMappingURL=./Rectangle.bs.map