function __BGE_SceneObjectLine_builder()
    instance = __BGE_SceneObject_builder()
    instance.super0_new = instance.new
    instance.new = sub(name as string, drawableObj as object)
        m.super0_new(name, drawableObj, "Line")
        m.drawable = invalid
        m.worldStart = BGE_Math_Vector()
        m.worldEnd = BGE_Math_Vector()
        m.canvasStart = BGE_Math_Vector()
        m.canvasEnd = BGE_Math_Vector()
    end sub
    instance.super0_updateWorldPosition = instance.updateWorldPosition
    instance.updateWorldPosition = function(drawMode as dynamic) as boolean
        if m.drawable.movedLastFrame(true) or invalid = m.worldStart or invalid = m.worldEnd
            m.worldStart = m.transformationMatrix.multVecMatrix(m.drawable.startPosition)
            m.worldEnd = m.transformationMatrix.multVecMatrix(m.drawable.endPosition)
        end if
        return true
    end function
    instance.super0_getPositionsForFrustumCheck = instance.getPositionsForFrustumCheck
    instance.getPositionsForFrustumCheck = function(drawMode as dynamic) as object
        return [
            m.worldStart
            m.worldEnd
        ]
    end function
    instance.super0_getPositionForCameraDistance = instance.getPositionForCameraDistance
    instance.getPositionForCameraDistance = function(drawMode as dynamic)
        return BGE_Math_midPointBetweenPoints(m.worldStart, m.worldEnd)
    end function
    instance.super0_findCanvasPosition = instance.findCanvasPosition
    instance.findCanvasPosition = function(renderer as object, drawMode as dynamic) as boolean
        m.canvasStart = renderer.worldPointToCanvasPoint(m.worldStart)
        m.canvasEnd = renderer.worldPointToCanvasPoint(m.worldEnd)
        return true
    end function
    instance.super0_performDraw = instance.performDraw
    instance.performDraw = function(renderer as object, drawMode as dynamic) as boolean
        if m.canvasStart = invalid or m.canvasEnd = invalid
            return false
        else
            return renderer.drawLine(m.canvasStart.x, m.canvasStart.y, m.canvasEnd.x, m.canvasEnd.y, m.drawable.getFillColorRGBA())
        end if
    end function
    return instance
end function
function BGE_SceneObjectLine(name as string, drawableObj as object)
    instance = __BGE_SceneObjectLine_builder()
    instance.new(name, drawableObj)
    return instance
end function'//# sourceMappingURL=./SceneObjectLine.bs.map