function __BGE_Camera_builder()
    instance = {}
    ' TODO: do something with zoom!
    instance.new = sub()
        m.orientation = BGE_Math_Vector(0, 0, - 1)
        m.position = BGE_Math_Vector(0, 0, 1000)
        m.motionChecker = BGE_MotionChecker()
        m.frameSize = BGE_Math_Vector()
        m.zoom = 1
        m.worldToCamera = invalid
    end sub
    instance.setFrameSize = sub(width as integer, height as integer)
        m.frameSize.x = width
        m.frameSize.y = height
    end sub
    instance.setTarget = sub(targetPos as object)
        ' m.orientation = targetPos.subtract(m.position).normalize()
    end sub
    instance.useDefaultCameraTarget = sub()
        halfW = m.frameSize.x / 2
        halfH = m.frameSize.y / 2
        m.setTarget(BGE_Math_Vector(halfW, HalfH))
    end sub
    instance.rotate = sub(rotation as object)
        'm.orientation = BGE.Math.getRotationMatrix(rotation).multDirMatrix(m.orientation).normalize()
    end sub
    instance.checkMovement = sub()
        currentlyMoved = m.motionChecker.check(m.position, m.orientation)
        if m.movedLastFrame() and not currentlyMoved
            m.motionChecker.resetMovedFlag()
            return
        end if
        if currentlyMoved
            m.onCameraMovement()
            m.motionChecker.setTransform(m.position, m.orientation)
        end if
    end sub
    instance.onCameraMovement = sub()
    end sub
    instance.movedLastFrame = function() as boolean
        return m.motionChecker.movedLastFrame
    end function
    instance.distanceFromCameraFront = function(point as object) as float
        return point.z
    end function
    instance.isInView = function(point as object) as boolean
        return point.x >= 0 and point.x <= m.frameSize.x and point.y >= 0 and point.y <= m.frameSize.y
    end function
    instance.computeWorldToCameraMatrix = sub()
        m.worldToCamera = BGE_Math_Matrix44Identity()
    end sub
    instance.getDrawMode = function() as dynamic
        return 1
    end function
    instance.worldPointToCanvasPoint = function(pWorld as object) as object
        return pWorld
    end function
    return instance
end function
function BGE_Camera()
    instance = __BGE_Camera_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./Camera.bs.map