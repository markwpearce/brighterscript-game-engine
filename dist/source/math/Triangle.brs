
function __BGE_Math_Triangle_builder()
    instance = {}
    '
    '
    ' @param {BGE.Math.Vector[]} points Array of points in counter clockwise winding (i.e. follows right-hand-rule)
    instance.new = sub(points as object, rearrangeToLongestFirst = false as boolean)
        m.lengths = []
        m.angles = []
        m.anglesToNext = []
        m.anglesToPrevious = []
        m.points = []
        m.longestIndex = 0
        m.height = 0
        m.winding = 1
        m.angleRotatedFromOriginal = 0
        m.setPoints(points, rearrangeToLongestFirst)
    end sub
    instance.setPoints = sub(points as object, rearrangeToLongestFirst = false as boolean)
        crossProduct = points[2].subtract(points[0]).crossProduct(points[1].subtract(points[0]))
        if crossProduct.z < 0
            'this has clockwise winding, so swap points 1 & 2
            temp = points[2]
            points[2] = points[1]
            points[1] = temp
        end if
        longest = 0
        m.longestIndex = 0
        lengths = []
        angles = []
        anglesToNext = []
        anglesToPrevious = []
        twoPi = BGE_Math_PI() * 2
        for i = 0 to 2
            j = (i + 1) mod 3
            k = (j + 1) mod 3
            length = BGE_Math_TotalDistance(points[i], points[j])
            if length > longest
                m.longestIndex = i
                longest = length
            end if
            lengths.push(length)
            angles.push(twoPi - BGE_Math_GetAngleBetweenVectors(points[i], points[k], points[j]))
            anglesToNext.push(BGE_Math_GetAngle(points[i], points[j]))
            anglesToPrevious.push(BGE_Math_GetAngle(points[i], points[k]))
            if not rearrangeToLongestFirst
                m.points.push(points[i].copy())
            end if
        end for
        if rearrangeToLongestFirst
            for index = m.longestIndex to m.longestIndex + 3
                i = index mod 3
                m.lengths.push(lengths[i])
                m.angles.push(angles[i])
                m.anglesToNext.push(anglesToNext[i])
                m.points.push(points[i].copy())
            end for
            m.longestIndex = 0
        else
            m.lengths = lengths
            m.angles = angles
            m.anglesToNext = anglesToNext
            m.anglesToPrevious = anglesToPrevious
        end if
        m.height = m.getHeightByTangentIndex(m.nextIndex(m.longestIndex))
        if m.height < 0
            'winding error?
        end if
    end sub
    instance.getLongestSide = function() as float
        return m.lengths[m.longestIndex]
    end function
    instance.isObtuse = function() as boolean
        halfPiVal = BGE_Math_HalfPI()
        for i = 0 to 2
            if m.angles[i] > (halfPiVal * 1.01)
                return true
            end if
        end for
        return false
    end function
    instance.isAcute = function() as boolean
        halfPiVal = BGE_Math_HalfPI()
        for i = 0 to 2
            if m.angles[i] > (halfPiVal * 0.99)
                return false
            end if
        end for
        return true
    end function
    instance.getOriginIndex = function() as integer
        i = 0
        for each point in m.points
            if point.isZero()
                return i
            end if
            i++
        end for
        return - 1
    end function
    instance.getHeightByTangentIndex = function(tangentIndex) as float
        'tangentIndex = (m.longestIndex + 1) mod 3
        tangentLength = m.lengths[tangentIndex]
        return tangentLength * sin(m.angles[tangentIndex])
    end function
    instance.nextIndex = function(currentIndex as integer) as integer
        return (currentIndex + 1) mod 3
    end function
    instance.previousIndex = function(currentIndex as integer) as integer
        return (currentIndex + 3 - 1) mod 3
    end function
    instance.toStr = function() as string
        result = "Triangle {" + chr(10) + "points: " + bslib_toString(BGE_arrayToStr(m.points)) + chr(10) + "lengths: " + bslib_toString(BGE_arrayToStr(m.lengths)) + chr(10) + "angles: " + bslib_toString(BGE_arrayToStr(m.angles)) + chr(10) + "anglesToNext: " + bslib_toString(BGE_arrayToStr(m.anglesToNext)) + chr(10) + "anglesToPrevious: " + bslib_toString(BGE_arrayToStr(m.anglesToPrevious)) + chr(10) + "longestIndex: " + bslib_toString(m.longestIndex) + chr(10) + "height: " + bslib_toString(m.height) + chr(10) + "}"
        return result
    end function
    return instance
end function
function BGE_Math_Triangle(points as object, rearrangeToLongestFirst = false as boolean)
    instance = __BGE_Math_Triangle_builder()
    instance.new(points, rearrangeToLongestFirst)
    return instance
end function'//# sourceMappingURL=./Triangle.bs.map