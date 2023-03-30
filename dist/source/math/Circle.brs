function __BGE_Math_Circle_builder()
    instance = __BGE_Math_Vector_builder()
    instance.super0_new = instance.new
    instance.new = sub(x = 0 as float, y = 0 as float, radius = 0 as float) as object
        m.super0_new(x, y)
        m.radius = 0
        m.radius = radius
    end sub
    instance.super0_copy = instance.copy
    instance.copy = function() as object
        return BGE_Math_Circle(m.x, m.y, m.radius)
    end function
    return instance
end function
function BGE_Math_Circle(x = 0 as float, y = 0 as float, radius = 0 as float)
    instance = __BGE_Math_Circle_builder()
    instance.new(x, y, radius)
    return instance
end function'//# sourceMappingURL=./Circle.bs.map