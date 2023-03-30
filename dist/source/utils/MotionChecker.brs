function __BGE_MotionChecker_builder()
    instance = {}
    instance.new = sub()
        m.previousTransform = BGE_Math_Transform()
        m.movedLastFrame = true
    end sub
    ' Is the current transform as given different from the previous?
    '
    ' @param {BGE.Math.Vector} [position=invalid]
    ' @param {BGE.Math.Vector} [rotation=invalid]
    ' @param {BGE.Math.Vector} [scale=invalid]
    ' @return {boolean} True if different from previous
    instance.check = function(position = invalid as object, rotation = invalid as object, scale = invalid as object) as boolean
        if m.previousTransform = invalid
            return true
        end if
        if rotation <> invalid and not m.previousTransform.rotation.equals(rotation)
            return true
        end if
        if invalid <> position and not m.previousTransform.position.equals(position)
            return true
        end if
        if invalid <> scale and not m.previousTransform.scale.equals(scale)
            return true
        end if
        return false
    end function
    instance.resetMovedFlag = sub()
        m.movedLastFrame = false
    end sub
    instance.setTransform = sub(position as object, rotation as object, scale = invalid as object) as boolean
        m.previousTransform.position = position.copy()
        m.previousTransform.rotation = rotation.copy()
        if scale <> invalid
            m.previousTransform.scale = scale.copy()
        end if
        m.movedLastFrame = true
    end sub
    instance.getPositionDifference = function(currentPosition as object) as object
        return currentPosition.subtract(m.previousTransform.position)
    end function
    instance.getRotationDifference = function(currentRotation as object) as object
        return currentRotation.subtract(m.previousTransform.rotation)
    end function
    return instance
end function
function BGE_MotionChecker()
    instance = __BGE_MotionChecker_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./MotionChecker.bs.map