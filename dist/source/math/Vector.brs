function __BGE_Math_Vector_builder()
    instance = {}
    instance.new = sub(x = 0.0 as float, y = 0.0 as float, z = 0.0 as float)
        m.x = 0.0
        m.y = 0.0
        m.z = 0.0
        m.x = x * 1.0
        m.y = y * 1.0
        m.z = z * 1.0
    end sub
    instance.getIndex = function(index as integer) as float
        if index = 0
            return m.x
        else if index = 1
            return m.y
        else if index = 2
            return m.z
        end if
        return invalid
    end function
    instance.setFrom = function(b as object) as object
        m.x = b.x
        m.y = b.y
        m.z = b.z
        return m
    end function
    instance.add = function(v as object) as object
        return BGE_Math_Vector(m.x + v.x, m.y + v.y, m.z + v.z)
    end function
    instance.equals = function(v as object) as boolean
        return m.x = v.x and m.y = v.y and m.z = v.z
    end function
    instance.plusEquals = sub(v as object)
        m.x += v.x
        m.y += v.y
        m.z += v.z
    end sub
    instance.subtract = function(v as object) as object
        return BGE_Math_Vector(m.x - v.x, m.y - v.y, m.z - v.z)
    end function
    instance.minusEquals = sub(v as object)
        m.x -= v.x
        m.y -= v.y
        m.z -= v.z
    end sub
    instance.negative = function() as object
        return BGE_Math_Vector(- m.x, - m.y, - m.z)
    end function
    instance.flipX = function() as object
        return BGE_Math_Vector(- m.x, m.y, m.z)
    end function
    instance.flipY = function() as object
        return BGE_Math_Vector(m.x, - m.y, m.z)
    end function
    instance.scale = function(r as float) as object
        return BGE_Math_Vector(m.x * r, m.y * r, m.z * r)
    end function
    instance.scaleEquals = sub(r as float)
        m.x *= r
        m.y *= r
        m.z *= r
    end sub
    instance.multiply = function(v as object) as object
        return BGE_Math_Vector(m.x * v.x, m.y * v.y, m.z * v.z)
    end function
    instance.multEquals = sub(v as object)
        m.x *= v.x
        m.y *= v.y
        m.z *= v.z
    end sub
    instance.dotProduct = function(v as object) as float
        return m.x * v.x + m.y * v.y + m.z * v.z
    end function
    instance.divide = function(r as float) as object
        return BGE_Math_Vector(m.x / r, m.y / r, m.z / r)
    end function
    ' Makes a copy of this vector
    '
    ' @return {Vector}
    instance.copy = function() as object
        return BGE_Math_Vector(m.x, m.y, m.z)
    end function
    instance.crossProduct = function(v as object) as object
        return BGE_Math_Vector(m.y * v.z - m.z * v.y, m.z * v.x - m.x * v.z, m.x * v.y - m.y * v.x)
    end function
    ' Gets the square of the length of a vector
    '
    ' @return {float}
    instance.norm = function() as float
        return m.x * m.x + m.y * m.y + m.z * m.z
    end function
    ' Gets the length of a vector
    '
    ' @return {float}
    instance.length = function() as float
        return sqr(m.norm())
    end function
    instance.normalize = function() as object
        n = m.norm()
        if (n > 0)
            factor = 1 / sqr(n)
            m.x *= factor
            m.y *= factor
            m.z *= factor
        end if
        return m
    end function
    instance.getNormalizedCopy = function() as object
        return m.copy().normalize()
    end function
    instance.cint = function() as object
        return BGE_Math_Vector(cint(m.x), cint(m.y), cint(m.z))
    end function
    instance.toStr = function() as string
        return "[" + bslib_toString(m.x) + " " + bslib_toString(m.y) + " " + bslib_toString(m.z) + "]"
    end function
    instance.toArray = function() as object
        return [
            m.x
            m.y
            m.z
        ]
    end function
    instance.isParallel = function(v as object) as boolean
        div = 1
        one = m.toArray()
        two = v.toArray()
        if two[0] <> 0
            div = one[0] / two[0]
        else if two[1] <> 0
            div = one[1] / two[1]
        else if two[2] <> 0
            div = one[2] / two[2]
        end if
        for i = 0 to 2
            if one[i] <> div * two[i]
                return false
            end if
        end for
        return true
    end function
    instance.isZero = function() as boolean
        return m.x = 0 and m.y = 0 and m.z = 0
    end function
    return instance
end function
function BGE_Math_Vector(x = 0.0 as float, y = 0.0 as float, z = 0.0 as float)
    instance = __BGE_Math_Vector_builder()
    instance.new(x, y, z)
    return instance
end function

function BGE_Math_VectorIdentity() as object
    return BGE_Math_Vector()
end function

' @param {float} scale_x - horizontal scale
' @param {dynamic} [scale_y=invalid] - vertical scale, or if invalid, use the horizontal scale as vertical scale
function BGE_Math_createScaleVector(scale_x as float, scale_y = invalid as dynamic, scale_z = invalid as dynamic) as object
    result = BGE_Math_VectorIdentity()
    if invalid = scale_y
        scale_y = scale_x
    end if
    if invalid = scale_z
        scale_z = scale_x
    end if
    result.x = scale_x
    result.y = scale_y
    result.z = scale_z
    return result
end function

function BGE_Math_distanceFromPlane(planePoint as object, planeNormal as object, targetPoint as object) as float
    diff = targetPoint.subtract(planePoint)
    return diff.dotProduct(planeNormal)
end function

function BGE_Math_midPointBetweenPoints(a as object, b as object) as object
    return a.add(b.subtract(a).divide(2))
end function

function BGE_Math_getBounds(points as object) as object
    if invalid = points or points.count() < 1
        return []
    end if
    minPoint = points[0].copy()
    maxPoint = points[0].copy()
    for i = 1 to points.count() - 1
        p = points[i]
        minPoint.x = BGE_Math_min(minPoint.x, p.x)
        minPoint.y = BGE_Math_min(minPoint.y, p.y)
        minPoint.z = BGE_Math_min(minPoint.z, p.z)
        maxPoint.x = BGE_Math_max(maxPoint.x, p.x)
        maxPoint.y = BGE_Math_max(maxPoint.y, p.y)
        maxPoint.z = BGE_Math_max(maxPoint.z, p.z)
    end for
    return [
        minPoint
        maxPoint
    ]
end function

function BGE_Math_getBoundingCubePoints(points as object) as object
    bounds = BGE_Math_getBounds(points)
    if bounds.count() < 2
        return []
    end if
    minP = bounds[0]
    maxP = bounds[1]
    return [
        minP
        BGE_Math_Vector(minP.x, minP.y, maxP.z)
        BGE_Math_Vector(minP.x, maxP.y, minP.z)
        BGE_Math_Vector(minP.x, maxP.y, maxP.z)
        BGE_Math_Vector(maxP.x, minP.y, minP.z)
        BGE_Math_Vector(maxP.x, minP.y, maxP.z)
        BGE_Math_Vector(maxP.x, maxP.y, minP.z)
        maxP
    ]
end function

function BGE_Math_vectorArraysEqual(a = [] as object, b = [] as object) as object
    if a.count() <> b.count()
        return false
    end if
    same = true
    for i = 0 to a.count() - 1
        same = a[i].equals(b[i])
        if not same
            exit for
        end if
    end for
    return same
end function

function BGE_Math_vectorArrayCopy(a = [] as object) as object
    out = []
    for i = 0 to a.count() - 1
        out.push(a[i].copy())
    end for
    return out
end function'//# sourceMappingURL=./Vector.bs.map