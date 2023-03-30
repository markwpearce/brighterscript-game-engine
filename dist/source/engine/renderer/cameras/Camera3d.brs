
function __BGE_CameraFrustumNormals_builder()
    instance = {}
    instance.new = sub()
        m.top = invalid
        m.bottom = invalid
        m.left = invalid
        m.right = invalid
        m.near = invalid
    end sub
    instance.setNormals = sub(cameraOrientation as object, fovDegrees as float)
        'near
        m.near = cameraOrientation.copy()
        fovRad = BGE_Math_DegreesToRadians(fovDegrees)
        rotVect = BGE_Math_Vector()
        'top
        rotVect.x = fovRad / 2
        rotVect.y = 0
        m.top = BGE_Math_getRotationMatrix(rotVect).multDirMatrix(cameraOrientation)
        'bottom
        rotVect.x = - fovRad / 2
        rotVect.y = 0
        m.bottom = BGE_Math_getRotationMatrix(rotVect).multDirMatrix(cameraOrientation)
        'left
        rotVect.x = 0
        rotVect.y = fovRad / 2
        m.left = BGE_Math_getRotationMatrix(rotVect).multDirMatrix(cameraOrientation)
        'right
        rotVect.x = 0
        rotVect.y = - fovRad / 2
        m.right = BGE_Math_getRotationMatrix(rotVect).multDirMatrix(cameraOrientation)
    end sub
    return instance
end function
function BGE_CameraFrustumNormals()
    instance = __BGE_CameraFrustumNormals_builder()
    instance.new()
    return instance
end function
function __BGE_Camera3d_builder()
    instance = __BGE_Camera_builder()
    instance.super0_new = instance.new
    instance.new = sub()
        m.super0_new()
        m.fieldOfViewDegrees = 90
        m.frustumNormals = BGE_CameraFrustumNormals()
        m.frustrumConvergence = BGE_Math_Vector()
    end sub
    instance.super0_setTarget = instance.setTarget
    instance.setTarget = sub(targetPos as object)
        m.orientation = targetPos.subtract(m.position).normalize()
    end sub
    instance.super0_rotate = instance.rotate
    instance.rotate = sub(rotation as object)
        m.orientation = BGE_Math_getRotationMatrix(rotation).multDirMatrix(m.orientation).normalize()
    end sub
    instance.super0_onCameraMovement = instance.onCameraMovement
    instance.onCameraMovement = sub()
        if m.motionChecker.getRotationDifference(m.orientation).norm() > 0
            m.frustumNormals.setNormals(m.orientation, m.fieldOfViewDegrees)
        end if
        ' make the frustrum converge BEHIND the camera, instead of at the camera's position, so
        ' items on edge of frame don't get cut off
        ' This simply puts the convergence such that the whole frame will be in the frustrum
        ' There are probably better ways of doing this
        fovRad = BGE_Math_DegreesToRadians(m.fieldOfViewDegrees)
        halfFrameSize = BGE_Math_max(m.frameSize.x, m.frameSize.y) / 2
        m.frustrumConvergence = m.position.subtract(m.orientation.scale(halfFrameSize * cos(fovRad / 2)))
    end sub
    instance.super0_distanceFromCameraFront = instance.distanceFromCameraFront
    instance.distanceFromCameraFront = function(point as object) as float
        return m.distanceFromFrustumSide("near", point)
    end function
    instance.distanceFromFrustumSide = function(frustumSide as string, point as object) as float
        frusNorm = m.frustumNormals[frustumSide]
        return BGE_Math_distanceFromPlane(m.frustrumConvergence, frusNorm, point)
    end function
    instance.super0_isInView = instance.isInView
    instance.isInView = function(point as object) as boolean
        frustumSides = [
            "near"
            "top"
            "left"
            "right"
            "bottom"
        ]
        for each side in frustumSides
            distance = m.distanceFromFrustumSide(side, point)
            if distance < 0
                return false
            end if
        end for
        return true
    end function
    instance.super0_computeWorldToCameraMatrix = instance.computeWorldToCameraMatrix
    instance.computeWorldToCameraMatrix = sub()
        lookTarget = m.position.add(m.orientation)
        m.worldToCamera = BGE_Math_lookAt(m.position, lookTarget).inverse()
    end sub
    instance.super0_getDrawMode = instance.getDrawMode
    instance.getDrawMode = function() as dynamic
        return 2
    end function
    instance.super0_worldPointToCanvasPoint = instance.worldPointToCanvasPoint
    instance.worldPointToCanvasPoint = function(pWorld as object) as object
        if invalid = m.worldToCamera
            m.computeWorldToCameraMatrix()
        end if
        pCamera = m.worldToCamera.multVecMatrix(pWorld)
        if pCamera.z >= 0
            return invalid
        end if
        pScreen = {
            x: 0
            y: 0
        }
        near = (m.frameSize.x / 2) / tan(BGE_Math_DegreesToRadians(m.fieldOfViewDegrees) / 2)
        pScreen.x = near * pCamera.x / - pCamera.z
        pScreen.y = near * pCamera.y / - pCamera.z
        pNDC = {
            x: 0
            y: 0
        }
        canvasWidth = m.frameSize.x
        canvasHeight = m.frameSize.y
        pNDC.x = (pScreen.x + canvasWidth * 0.5) / canvasWidth
        pNDC.y = (pScreen.y + canvasHeight * 0.5) / canvasHeight
        pRaster = BGE_Math_Vector()
        imageWidth = canvasWidth
        imageHeight = canvasHeight
        pRaster.x = fix(pNDC.x * imageWidth)
        pRaster.y = cint((1 - pNDC.y) * imageHeight)
        '? "pCamera: "; pCamera.toStr();" -> screen: [";pScreen.x;pScreen.y;"] -> NDC [";pNDC.x;pNDC.y;"] -> Raster [";pRaster.x;pRaster.y;"]"
        return pRaster
    end function
    instance.super0_useDefaultCameraTarget = instance.useDefaultCameraTarget
    instance.useDefaultCameraTarget = sub()
        m.setTarget(BGE_Math_Vector())
    end sub
    return instance
end function
function BGE_Camera3d()
    instance = __BGE_Camera3d_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./Camera3d.bs.map