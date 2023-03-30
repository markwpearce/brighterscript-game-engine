function __BGE_Math_Transform_builder()
    instance = {}
    instance.new = sub()
        m.position = BGE_Math_Vector()
        m.rotation = BGE_Math_Vector()
        m.scale = BGE_Math_Vector(1)
    end sub
    return instance
end function
function BGE_Math_Transform()
    instance = __BGE_Math_Transform_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./Transform.bs.map