function __BGE_SceneObjectPolygon_builder()
    instance = __BGE_SceneObjectBillboard_builder()
    instance.super1_new = instance.new
    instance.new = sub(name as string, drawableObj as object)
        m.super1_new(name, drawableObj, "Polygon")
        m.drawable = invalid
        m.frameNumber = 0
        m.lastFrameNumberDrawn = 0
        m.lastPolygonPoints = []
        m.polygonCanvasPoints = []
        m.polygonWorldPoints = []
        m.useTempBitmapMap[0] = true
        m.useTempBitmapMap[1] = true
        m.useTempBitmapMap[2] = true
    end sub
    instance.super1_didRegionToDrawChange = instance.didRegionToDrawChange
    instance.didRegionToDrawChange = function() as boolean
        return not BGE_Math_vectorArraysEqual(m.lastPolygonPoints, m.drawable.points)
    end function
    instance.super1_drawToCanvas = instance.drawToCanvas
    instance.drawToCanvas = function(renderer as object, drawMode as dynamic) as boolean
        return renderer.drawPolygon(m.polygonCanvasPoints, 0, 0, m.drawable.getFillColorRGBA())
    end function
    instance.super1_getCanvasBounds = instance.getCanvasBounds
    instance.getCanvasBounds = function() as object
        return BGE_Math_getBounds(m.polygonCanvasPoints)
    end function
    instance.super1_drawToTempBitmap = instance.drawToTempBitmap
    instance.drawToTempBitmap = function(renderer as object, tempBitmap as object, canvasPointsTopLeftBound as object, drawMode as dynamic) as boolean
        if tempBitmap = invalid
            return false
        end if
        offsetCanvasPoints = []
        for each point in m.polygonCanvasPoints
            offsetP = point.subtract(canvasPointsTopLeftBound)
            if invalid <> offsetP
                offsetCanvasPoints.push(offsetP)
            end if
        end for
        tempBmpDidDraw = renderer.drawPolygonTo(tempBitmap, offsetCanvasPoints, 0, 0, m.drawable.getFillColorRGBA())
        return tempBmpDidDraw
    end function
    instance.super1_updateWorldPosition = instance.updateWorldPosition
    instance.updateWorldPosition = function(drawMode as dynamic) as boolean
        m.polygonWorldPoints = []
        m.worldPosition = m.drawable.getWorldPosition()
        for each point in m.drawable.points
            worldPoint = m.transformationMatrix.multVecMatrix(point)
            if invalid <> worldPoint
                m.polygonWorldPoints.push(worldPoint)
            end if
        end for
    end function
    instance.super1_getPositionForCameraDistance = instance.getPositionForCameraDistance
    instance.getPositionForCameraDistance = function(drawMode as dynamic) as object
        if drawMode = 2
            return m.worldPoints.getCenter()
        end if
        return m.worldPosition
    end function
    instance.super1_getPositionsForFrustumCheck = instance.getPositionsForFrustumCheck
    instance.getPositionsForFrustumCheck = function(drawMode as dynamic) as object
        'TODO: this is probably too slow - this gives 8 points and needs to loop through all points
        return BGE_Math_getBoundingCubePoints(m.polygonWorldPoints)
    end function
    instance.super1_afterDraw = instance.afterDraw
    instance.afterDraw = sub()
        m.lastPolygonPoints = BGE_Math_vectorArrayCopy(m.drawable.points)
    end sub
    instance.super1_updateCanvasPosition = instance.updateCanvasPosition
    instance.updateCanvasPosition = function(renderer as object, drawMode as dynamic) as boolean
        m.polygonCanvasPoints = []
        for each point in m.polygonWorldPoints
            canvasPoint = renderer.worldPointToCanvasPoint(point)
            if invalid <> canvasPoint
                m.polygonCanvasPoints.push(canvasPoint)
            end if
        end for
        return true
    end function
    return instance
end function
function BGE_SceneObjectPolygon(name as string, drawableObj as object)
    instance = __BGE_SceneObjectPolygon_builder()
    instance.new(name, drawableObj)
    return instance
end function'//# sourceMappingURL=./SceneObjectPolygon.bs.map