function __BGE_Math_CornerPoints_builder()
    instance = {}
    instance.new = sub()
        m.topLeft = BGE_Math_Vector()
        m.topRight = BGE_Math_Vector()
        m.bottomLeft = BGE_Math_Vector()
        m.bottomRight = BGE_Math_Vector()
    end sub
    instance.toArray = function() as object
        return [
            m.topLeft
            m.topRight
            m.bottomLeft
            m.bottomRight
        ]
    end function
    instance.setPointByIndex = sub(index as integer, newValue as object)
        m.toArray()[index].setFrom(newValue)
    end sub
    instance.getNormal = function() as object
        topVector = m.topRight.subtract(m.topLeft)
        downVector = m.bottomLeft.subtract(m.topLeft)
        crossProd = topVector.crossProduct(downVector)
        crossProd.normalize()
        return crossProd
    end function
    instance.getAvgWidth = function() as float
        topXDelta = BGE_Math_TotalDistance(m.topLeft, m.topRight)
        bottomXDelta = BGE_Math_TotalDistance(m.bottomLeft, m.bottomRight)
        avg = BGE_Math_average(topXDelta, bottomXDelta)
        return avg
    end function
    instance.getMaxWidth = function() as float
        topXDelta = BGE_Math_TotalDistance(m.topLeft, m.topRight)
        bottomXDelta = BGE_Math_TotalDistance(m.bottomLeft, m.bottomRight)
        maxVal = BGE_Math_Max(topXDelta, bottomXDelta)
        return maxVal
    end function
    instance.getAvgHeight = function() as float
        leftYDelta = BGE_Math_TotalDistance(m.topLeft, m.bottomLeft)
        rightYDelta = BGE_Math_TotalDistance(m.topRight, m.bottomRight)
        maxVal = BGE_Math_max(leftYDelta, rightYDelta)
        return maxVal
    end function
    instance.getMaxHeight = function() as float
        leftYDelta = BGE_Math_TotalDistance(m.topLeft, m.bottomLeft)
        rightYDelta = BGE_Math_TotalDistance(m.topRight, m.bottomRight)
        avg = BGE_Math_average(leftYDelta, rightYDelta)
        return avg
    end function
    instance.getAvgRotation = function() as float
        origin = BGE_Math_Vector()
        piOver4 = BGE_Math_halfPi() / 2
        return - BGE_Math_constrainAngle(BGE_Math_GetAngle(m.getCenter(), BGE_Math_midPointBetweenPoints(m.topRight, m.bottomRight)))
    end function
    instance.getRotationOfTopLeftBottomRightDiagonal = function(originalDiagonal = BGE_Math_Vector(1, 0, 0) as object) as float
        origNormal = originalDiagonal.getNormalizedCopy()
        diagNormal = m.bottomRight.subtract(m.topLeft).getNormalizedCopy()
        return - BGE_Math_getAngle(origNormal, diagNormal)
    end function
    instance.getRotationOfTopRightBottomLeftDiagonal = function(originalDiagonal = BGE_Math_Vector(1, 0, 0) as object) as float
        origNormal = originalDiagonal.getNormalizedCopy()
        diagNormal = m.bottomLeft.subtract(m.topRight).getNormalizedCopy()
        return - BGE_Math_getAngle(origNormal, diagNormal)
    end function
    instance.computeSideLengths = function() as object
        lengths = []
        lengths.push(BGE_Math_TotalDistance(m.topLeft, m.topRight))
        lengths.push(BGE_Math_TotalDistance(m.topRight, m.bottomRight))
        lengths.push(BGE_Math_TotalDistance(m.bottomRight, m.bottomLeft))
        lengths.push(BGE_Math_TotalDistance(m.bottomLeft, m.topLeft))
        return lengths
    end function
    instance.computeDiagonalLengths = function() as object
        tLBrDistance = BGE_Math_TotalDistance(m.topLeft, m.bottomRight)
        trBlDistance = BGE_Math_TotalDistance(m.topRight, m.bottomLeft)
        return [
            tLBrDistance
            trBlDistance
        ]
    end function
    instance.getCenter = function() as object
        return BGE_Math_midPointBetweenPoints(m.topLeft, m.bottomRight)
    end function
    instance.getBounds = function() as object
        return BGE_Math_getBounds(m.toArray())
    end function
    instance.copy = function() as object
        copiedPoints = BGE_Math_CornerPoints()
        copiedPoints.topLeft = m.topLeft.copy()
        copiedPoints.topRight = m.topRight.copy()
        copiedPoints.bottomLeft = m.bottomLeft.copy()
        copiedPoints.bottomRight = m.bottomRight.copy()
        return copiedPoints
    end function
    instance.subtract = function(vect as object) as object
        copiedPoints = BGE_Math_CornerPoints()
        copiedPoints.topLeft = m.topLeft.subtract(vect)
        copiedPoints.topRight = m.topRight.subtract(vect)
        copiedPoints.bottomLeft = m.bottomLeft.subtract(vect)
        copiedPoints.bottomRight = m.bottomRight.subtract(vect)
        return copiedPoints
    end function
    instance.add = function(vect as object) as object
        copiedPoints = BGE_Math_CornerPoints()
        copiedPoints.topLeft = m.topLeft.add(vect)
        copiedPoints.topRight = m.topRight.add(vect)
        copiedPoints.bottomLeft = m.bottomLeft.add(vect)
        copiedPoints.bottomRight = m.bottomRight.add(vect)
        return copiedPoints
    end function
    instance.toStr = function() as string
        return "[" + bslib_toString(m.topLeft.toStr()) + ", " + bslib_toString(m.topRight.toStr()) + "," + chr(10) + " " + bslib_toString(m.bottomLeft.toStr()) + ", " + bslib_toString(m.bottomRight.toStr()) + "]"
    end function
    return instance
end function
function BGE_Math_CornerPoints()
    instance = __BGE_Math_CornerPoints_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./CornerPoints.bs.map