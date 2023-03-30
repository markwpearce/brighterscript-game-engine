

function __BGE_SceneObject_builder()
    instance = {}
    ' Unique Id
    ' The Current Transformation Matrix
    instance.new = sub(name as string, drawableObj as object, objType as dynamic)
        m.name = invalid
        m.id = ""
        m.drawable = invalid
        m.type = invalid
        m.negDistanceFromCamera = 0
        m.previousTransform = {}
        m.worldPosition = BGE_Math_Vector()
        m.transformationMatrix = BGE_Math_Matrix44()
        m.lastBitmap = invalid
        m.framesSinceDrawn = 0
        m.hasValidWorldPosition = false
        m.hasValidCanvasPosition = false
        m.wasEnabledLastFrame = false
        m.isFirstFrameSinceEnabled = false
        m.drawMode = 0
        m.name = name
        m.drawable = drawableObj
        m.type = objType
    end sub
    instance.setId = sub(id as string)
        if m.id = ""
            m.id = id
        end if
    end sub
    instance.update = sub(cameraObj as object)
        objMovedLastFrame = m.drawable.movedLastFrame(true)
        m.isFirstFrameSinceEnabled = (m.isEnabled() and not m.wasEnabledLastFrame)
        forceRecompute = objMovedLastFrame or not m.hasValidWorldPosition or m.isFirstFrameSinceEnabled
        if forceRecompute
            m.drawable.computeTransformationMatrix()
            m.transformationMatrix.setFrom(m.drawable.transformationMatrix.multiply(m.drawable.owner.transformationMatrix))
            sceneObjDrawMode = m.getActualDrawMode(cameraObj)
            m.hasValidWorldPosition = m.updateWorldPosition(sceneObjDrawMode)
        end if
        if cameraObj.movedLastFrame() or objMovedLastFrame
            drawModeToUse = m.getActualDrawMode(cameraObj)
            m.negDistanceFromCamera = - cameraObj.distanceFromCameraFront(m.getPositionForCameraDistance(drawModeToUse))
        end if
        m.wasEnabledLastFrame = m.isEnabled()
    end sub
    instance.getPositionForCameraDistance = function(drawMode as dynamic) as object
        return m.worldPosition
    end function
    instance.isEnabled = function() as boolean
        return m.drawable.isEnabled()
    end function
    instance.updateWorldPosition = function(drawMode as dynamic) as boolean
        m.worldPosition = m.drawable.getWorldPosition()
        return true
    end function
    instance.draw = sub(renderer as object)
        ' No op - needs to be overriden in Specific types of scene objects
        didDraw = false
        if m.isPotentiallyOnScreen(renderer.camera)
            drawModeToUse = m.getActualDrawMode(renderer.camera)
            if m.objMovedInRelationToCamera(renderer.camera) or not m.hasValidCanvasPosition or m.isFirstFrameSinceEnabled
                m.hasValidCanvasPosition = m.findCanvasPosition(renderer, drawModeToUse)
            end if
            if m.hasValidCanvasPosition
                didDraw = m.performDraw(renderer, drawModeToUse)
                if didDraw
                    m.afterDraw()
                end if
            end if
        end if
        if didDraw
            m.resetFrameSinceDrawn()
        else
            m.framesSinceDrawn++
        end if
        m.isFirstFrameSinceEnabled = false
    end sub
    instance.getActualDrawMode = function(cam as object) as dynamic
        if m.drawMode = 0
            return cam.getDrawMode()
        end if
        return m.drawMode
    end function
    instance.findCanvasPosition = function(renderer as object, drawMode as dynamic) as boolean
        return true
    end function
    instance.performDraw = function(renderer as object, drawMode as dynamic) as boolean
        ' No op - needs to be overriden in Specific types of scene objects
        return false
    end function
    instance.afterDraw = sub()
        ' No op - needs to be overriden in Specific types of scene objects
    end sub
    instance.resetFrameSinceDrawn = sub()
        m.framesSinceDrawn = 0
    end sub
    instance.objMovedInRelationToCamera = function(cameraObj as object) as boolean
        return m.drawable.movedLastFrame(true) or cameraObj.movedLastFrame()
    end function
    instance.isPotentiallyOnScreen = function(cameraObj as object) as boolean
        if m.framesSinceDrawn = 0 or m.isFirstFrameSinceEnabled
            return true
        end if
        if not m.objMovedInRelationToCamera(cameraObj)
            return false
        end if
        inCamera = false
        frustumCheckPositions = m.getPositionsForFrustumCheck(m.getActualDrawMode(cameraObj))
        for each checkPos in frustumCheckPositions
            inCamera = cameraObj.isInView(checkPos)
            if inCamera
                exit for
            end if
        end for
        return inCamera
    end function
    instance.getPositionsForFrustumCheck = function(drawMode as dynamic) as object
        return [
            m.worldPosition
        ]
    end function
    return instance
end function
function BGE_SceneObject(name as string, drawableObj as object, objType as dynamic)
    instance = __BGE_SceneObject_builder()
    instance.new(name, drawableObj, objType)
    return instance
end function'//# sourceMappingURL=./SceneObject.bs.map