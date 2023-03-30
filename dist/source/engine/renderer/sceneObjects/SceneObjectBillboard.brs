function __BGE_SceneObjectBillboard_builder()
    instance = __BGE_SceneObject_builder()
    instance.super0_new = instance.new
    instance.new = sub(name as string, drawableObj as object, objType as dynamic)
        m.super0_new(name, drawableObj, objType)
        m.worldPoints = BGE_Math_CornerPoints()
        m.canvasPoints = BGE_Math_CornerPoints()
        m.canvasPosition = invalid
        m.isMirror = false
        m.surfaceToCameraDotProduct = invalid
        m.surfaceNormal = invalid
        m.normalOnCanvasStart = invalid
        m.normalOnCanvasEnd = invalid
        m.tempBitmap = invalid
        m.useTempBitmapMap = [
            false
            false
            false
        ]
        m.useTempBitmapMap[0] = false
        m.useTempBitmapMap[1] = false
        m.useTempBitmapMap[2] = true
    end sub
    instance.super0_performDraw = instance.performDraw
    instance.performDraw = function(renderer as object, drawMode as dynamic) as boolean
        retVal = false
        if m.isRedrawToCanvasRequired(renderer, drawMode)
            ' either this moved recently, changed or not supposed to use temp bitmap in this drawMode
            m.tempBitmap = invalid
            retVal = m.drawToCanvas(renderer, drawMode)
        else ' nothing changed since last frame, draw a static image that can be used later
            canvasBounds = m.getCanvasBounds()
            if invalid = m.tempBitmap
                canvasBounds = m.getCanvasBounds()
                if invalid = canvasBounds or canvasBounds.count() < 2
                    return false
                end if
                canvasSize = canvasBounds[1].subtract(canvasBounds[0])
                m.tempBitmap = createObject("roBitmap", {
                    width: canvasSize.x + 1
                    height: canvasSize.y + 1
                    alphaEnable: true
                })
                tempBitmapDrawn = m.drawToTempBitmap(renderer, m.tempBitmap, canvasBounds[0], drawMode)
                if not tempBitmapDrawn
                    return false
                end if
            end if
            retVal = renderer.drawObject(canvasBounds[0].x, canvasBounds[0].y, m.tempBitmap)
        end if
        if drawMode = 2 and invalid <> m.normalOnCanvasStart and invalid <> m.normalOnCanvasEnd
            renderer.drawLine(m.normalOnCanvasStart.x, m.normalOnCanvasStart.y, m.normalOnCanvasEnd.x, m.normalOnCanvasEnd.y, BGE_Colors().Pink)
        end if
        return retVal
    end function
    instance.isRedrawToCanvasRequired = function(renderer as object, drawMode as dynamic) as boolean
        return not m.useTempBitmapMap[drawMode] or m.objMovedInRelationToCamera(renderer.camera) or m.didRegionToDrawChange()
    end function
    instance.drawToCanvas = function(renderer as object, drawMode as dynamic) as boolean
        regionToDraw = m.getRegionWithIdToDraw()
        regionObj = regionToDraw.region
        if invalid = regionToDraw or invalid = regionObj
            return false
        end if
        if drawMode = 1
            drawPos = m.canvasPosition
            totalScaleX = 1.0 * m.drawable.scale.x * m.drawable.owner.scale.x
            totalScaleY = 1.0 * m.drawable.scale.y * m.drawable.owner.scale.y
            theta = m.drawable.rotation.z + m.drawable.owner.rotation.z
            retVal = renderer.drawRegion(regionToDraw.region, drawPos.x, drawPos.y, totalScaleX, totalScaleY, - theta)
        else if drawMode = 2
            retVal = renderer.drawPinnedCorners(m.canvasPoints, regionToDraw, m.isMirror, m.drawable.getFillColorRGBA())
        end if
        return retVal
    end function
    instance.getCanvasBounds = function() as object
        return m.canvasPoints.getBounds()
    end function
    instance.drawToTempBitmap = function(renderer as object, tempBitmap as object, canvasPointsTopLeftBound as object, drawMode as dynamic) as boolean
        if invalid = tempBitmap
            return false
        end if
        regionToDraw = m.getRegionWithIdToDraw()
        if invalid = regionToDraw or invalid = regionToDraw.region
            return false
        end if
        regionObj = regionToDraw.region
        preTransX = regionObj.getPretranslationX()
        preTransY = regionObj.getPretranslationY()
        offsetCanvasPoints = m.canvasPoints.subtract(canvasPointsTopLeftBound)
        regionObj.setPretranslation(0, 0)
        tempBmpDidDraw = renderer.drawPinnedCornersTo(tempBitmap, offsetCanvasPoints, regionToDraw, m.isMirror, m.drawable.getFillColorRGBA())
        regionObj.setPretranslation(preTransX, preTransY)
        return tempBmpDidDraw
    end function
    instance.didRegionToDrawChange = function() as boolean
        return false
    end function
    instance.super0_updateWorldPosition = instance.updateWorldPosition
    instance.updateWorldPosition = function(drawMode as dynamic) as boolean
        if drawMode = 1
            m.worldPosition = m.drawable.getWorldPosition()
        else if drawMode = 2
            origin = BGE_Math_Vector()
            totalScaleX = 1 * m.drawable.scale.x
            totalScaleY = 1 * m.drawable.scale.y
            scaledSize = m.drawable.getDrawnSize()
            scaledWidth = scaledSize.width
            scaledHeight = scaledSize.height
            pretrans = m.drawable.getPretranslation()
            topLeft = BGE_Math_Vector(pretrans.x * totalScaleX, - pretrans.y * totalScaleY, 0)
            topRight = topLeft.add(BGE_Math_Vector(scaledWidth, 0, 0))
            bottomLeft = topLeft.add(BGE_Math_Vector(0, - scaledHeight, 0))
            bottomRight = topLeft.add(BGE_Math_Vector(scaledWidth, - scaledHeight, 0))
            m.worldPoints.topLeft = m.transformationMatrix.multVecMatrix(topLeft)
            m.worldPoints.topRight = m.transformationMatrix.multVecMatrix(topRight)
            m.worldPoints.bottomLeft = m.transformationMatrix.multVecMatrix(bottomLeft)
            m.worldPoints.bottomRight = m.transformationMatrix.multVecMatrix(bottomRight)
            m.worldPosition = m.worldPoints.topLeft
            m.surfaceNormal = m.worldPoints.getNormal()
        end if
        return true
    end function
    instance.super0_getPositionForCameraDistance = instance.getPositionForCameraDistance
    instance.getPositionForCameraDistance = function(drawMode as dynamic) as object
        if drawMode = 2
            return m.worldPoints.getCenter()
        end if
        return m.worldPosition
    end function
    instance.super0_getPositionsForFrustumCheck = instance.getPositionsForFrustumCheck
    instance.getPositionsForFrustumCheck = function(drawMode as dynamic) as object
        if drawMode = 2
            return m.worldPoints.toArray()
        end if
        return [
            m.worldPosition
        ]
    end function
    instance.super0_findCanvasPosition = instance.findCanvasPosition
    instance.findCanvasPosition = function(renderer as object, drawMode as dynamic) as boolean
        result = m.updateCanvasPosition(renderer, drawMode)
        if result and drawMode = 2
            m.computeNormalDebugInfo(renderer)
            m.isMirror = false
            if invalid <> m.surfaceNormal
                m.surfaceToCameraDotProduct = m.surfaceNormal.dotProduct(renderer.camera.orientation)
                if m.surfaceToCameraDotProduct < 0
                    m.isMirror = true
                end if
            end if
        end if
        return result
    end function
    instance.updateCanvasPosition = function(renderer as object, drawMode as dynamic) as boolean
        if drawMode = 1
            m.canvasPosition = renderer.worldPointToCanvasPoint(m.worldPosition)
            if invalid = m.canvasPosition
                return false
            end if
        else if drawMode = 2
            index = 0
            for each corner in m.worldPoints.toArray()
                canvasPoint = renderer.worldPointToCanvasPoint(corner)
                if invalid = canvasPoint
                    return false
                end if
                m.canvasPoints.setPointByIndex(index, canvasPoint)
                index++
            end for
        end if
        return true
    end function
    instance.computeNormalDebugInfo = sub(renderer as object)
        if BGE_isTrue(m.drawable.owner.game.getDebugValue("draw_scene_object_normals")) and invalid <> m.surfaceNormal and invalid <> m.worldPoints
            normalCenter = m.getNormalDebugPoint()
            m.normalOnCanvasStart = renderer.worldPointToCanvasPoint(m.worldPoints.getCenter())
            m.normalOnCanvasEnd = renderer.worldPointToCanvasPoint(m.worldPoints.getCenter().subtract(m.surfaceNormal.scale(100)))
        else
            m.normalOnCanvasStart = invalid
            m.normalOnCanvasEnd = invalid
        end if
    end sub
    instance.getNormalDebugPoint = function() as object
        return m.worldPoints.getCenter()
    end function
    return instance
end function
function BGE_SceneObjectBillboard(name as string, drawableObj as object, objType as dynamic)
    instance = __BGE_SceneObjectBillboard_builder()
    instance.new(name, drawableObj, objType)
    return instance
end function'//# sourceMappingURL=./SceneObjectBillboard.bs.map