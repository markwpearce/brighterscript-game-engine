' @module BGE
function BGE_Math_Min(a as dynamic, b as dynamic) as dynamic
    if a <= b
        return a
    end if
    return b
end function

function BGE_Math_Max(a as dynamic, b as dynamic) as dynamic
    if a >= b
        return a
    end if
    return b
end function

function BGE_Math_Clamp(number as dynamic, minVal as dynamic, maxVal as dynamic) as dynamic
    if number < minVal
        return minVal
    else if number > maxVal
        return maxVal
    else
        return number
    end if
end function

function BGE_Math_PI() as float
    return 3.14159265358
end function

function BGE_Math_halfPI() as float
    return 1.57079632679
end function

function BGE_Math_Atan2(y as float, x as float) as float
    piValue = BGE_Math_PI()
    piOver2 = BGE_Math_halfPi()
    if x > 0
        angle = Atn(y / x)
    else if y >= 0 and x < 0
        angle = Atn(y / x) + piValue
    else if y < 0 and x < 0
        angle = Atn(y / x) - piValue
    else if y > 0 and x = 0
        angle = piOver2
    else if y < 0 and x = 0
        angle = (piOver2) * - 1
    else
        angle = 0
    end if
    return angle
end function

function BGE_Math_IsIntegerEven(number as integer) as boolean
    return (number mod 2 = 0)
end function

function BGE_Math_IsIntegerOdd(number as integer) as boolean
    return (number mod 2 <> 0)
end function

function BGE_Math_Power(number as dynamic, pow as integer) as dynamic
    n = 1
    for i = 0 to pow - 1
        n *= number
    end for
    return n
end function

function BGE_Math_Round(number as float, decimals = 0 as integer) as float
    if 0 = decimals
        return cint(number)
    else
        magnitude = BGE_Math_Power(10, decimals)
        return cint(number * magnitude) / magnitude
    end if
end function

function BGE_Math_DegreesToRadians(degrees as float) as float
    return (degrees / 180) * BGE_Math_PI()
end function

function BGE_Math_RadiansToDegrees(radians as float) as float
    return (180 / BGE_Math_PI()) * radians
end function

function BGE_Math_RandomInRange(lowestInt as integer, highestInt as integer) as integer
    return rnd(highestInt - (lowestInt - 1)) + (lowestInt - 1)
end function

function BGE_Math_constrainAngle(angleRad as float) as float
    twoPi = 2 * BGE_Math_Pi()
    while angleRad < 0
        angleRad += twoPi
    end while
    while angleRad > twoPi
        angleRad -= twoPi
    end while
    return angleRad
end function

function BGE_Math_RotateVectorAroundVector2d(vector1 as object, vector2 as object, radians as float) as object
    v = BGE_Math_Vector(vector1.x, vector1.y)
    s = sin(radians)
    c = cos(radians)
    v.x -= vector2.x
    v.y -= vector2.y
    new_x = v.x * c + v.y * s
    new_y = - v.x * s + v.y * c
    v.x = new_x + vector2.x
    v.y = new_y + vector2.y
    return v
end function

function BGE_Math_TotalDistance(vector1 as object, vector2 as object) as float
    x_distance = vector1.x - vector2.x
    y_distance = vector1.y - vector2.y
    z_distance = 0
    if invalid <> vector1.z and invalid <> vector2.z
        z_distance = vector1.z - vector2.z
    end if
    total_distance = Sqr(x_distance * x_distance + y_distance * y_distance + z_distance * z_distance)
    return total_distance
end function

function BGE_Math_GetAngle(point1 as object, point2 as object) as float
    vectorP1P2 = point2.subtract(point1)
    angle = BGE_Math_Atan2(vectorP1P2.y, vectorP1P2.x)
    return angle
end function

function BGE_Math_GetAngleBetweenVectors(center as object, point1 as object, point2 as object) as float
    return BGE_Math_constrainAngle(BGE_Math_GetAngle(center, point1) - BGE_Math_GetAngle(center, point2))
end function

function BGE_Math_average(num1 as float, num2 as float) as float
    return (num1 + num2) / 2
end function

function BGE_Math_arraySum(nums as object) as float
    sum = 0
    for each num in nums
        sum += num
    end for
    return sum
end function

function BGE_Math_arrayAverage(nums as object) as float
    return BGE_Math_arraySum(nums) / nums.count()
end function'//# sourceMappingURL=./math.bs.map