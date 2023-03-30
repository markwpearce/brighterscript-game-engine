function __BGE_Camera2d_builder()
    instance = __BGE_Camera_builder()
    instance.super0_new = instance.new
    instance.new = sub()
        m.super0_new()
        m.top = invalid
        m.bottom = invalid
        m.right = invalid
        m.left = invalid
        m.near = 1000
        m.far = - 10000
    end sub
    'protected orthoProj as BGE.Math.Matrix44
    instance.super0_setTarget = instance.setTarget
    instance.setTarget = sub(targetPos as object)
        ' moves camera to center on target
        m.position.x = targetPos.x
        m.position.y = targetPos.y
    end sub
    instance.super0_rotate = instance.rotate
    instance.rotate = sub(rotation as object)
        ' 2d Cameras don't rotate
        ' TODO: The probably could rotate in in Z axis. hmmm
    end sub
    instance.super0_isInView = instance.isInView
    instance.isInView = function(point as object) as boolean
        ' add a bit of fudge value here, so things don't disappear when still in screen
        xFudge = m.frameSize.x / 4
        yFudge = m.frameSize.y / 4
        inViewHorizontally = point.x >= (m.left - xFudge) and point.x <= (m.right + xFudge)
        inViewHorizontally = point.y >= (m.top - yFudge) and point.y <= (m.bottom + yFudge)
        return inViewHorizontally and inViewHorizontally
    end function
    instance.super0_computeWorldToCameraMatrix = instance.computeWorldToCameraMatrix
    instance.computeWorldToCameraMatrix = sub()
        halfW = m.frameSize.x / 2
        halfH = m.frameSize.y / 2
        m.top = m.position.y + halfH
        m.bottom = m.position.y - halfH
        m.right = m.position.x + halfW
        m.left = m.position.x - halfW
        m.near = m.position.z + 1
        m.far = - 10000
        m.worldToCamera = BGE_Math_orthographicMatrix(m.top, m.bottom, m.left, m.right, m.far, m.near)
    end sub
    instance.super0_distanceFromCameraFront = instance.distanceFromCameraFront
    instance.distanceFromCameraFront = function(point as object) as float
        return m.position.z - point.z
    end function
    instance.super0_worldPointToCanvasPoint = instance.worldPointToCanvasPoint
    instance.worldPointToCanvasPoint = function(pWorld as object) as object
        if invalid = m.worldToCamera
            m.computeWorldToCameraMatrix()
        end if
        'pCamera = m.orthoProj.multVecMatrix(m.worldToCamera.multVecMatrix(pWorld))
        pCamera = m.worldToCamera.multVecMatrix(pWorld)
        if pCamera.z >= 0
            return invalid
        end if
        canvasWidth = m.frameSize.x
        canvasHeight = m.frameSize.y
        pScreen = {
            x: 0
            y: 0
        }
        pScreen.x = pCamera.x * canvasWidth * 0.5
        pScreen.y = pCamera.y * canvasHeight * 0.5
        pNDC = {
            x: 0
            y: 0
        }
        pNDC.x = (pScreen.x + canvasWidth * 0.5) '/ canvasWidth
        pNDC.y = (- pScreen.y + canvasHeight * 0.5) '/ canvasHeight
        pRaster = BGE_Math_Vector()
        pRaster.x = fix(pNDC.x)
        pRaster.y = fix(pNDC.y)
        '? "pWorld: "; pWorld.toStr();" -> screen: [";pScreen.x;pScreen.y;"] -> NDC [";pNDC.x;pNDC.y;"] -> Raster [";pRaster.x;pRaster.y;"]"
        return pRaster
    end function
    return instance
end function
function BGE_Camera2d()
    instance = __BGE_Camera2d_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./Camera2d.bs.map