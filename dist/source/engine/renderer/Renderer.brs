' Wrapper for Draw2D calls, so that we can keep track of how much is being drawn per frame
function __BGE_Renderer_builder()
    instance = {}
    ' Frame rate target - the game will reduce quality if this target is not met
    instance.new = sub(game as object, draw2d as object, cam = invalid as object)
        m.nextSceneObjectId = 0
        m.minimumFrameRateTarget = 12
        m.onlyDrawWhenInFrame = true
        m.drawCallsLastFrame = 0
        m.activeDebugCells = 0
        m.debugCellSize = 100
        m.debugCellStart = BGE_Math_Vector(100, 100)
        m.drawDebugCells = false
        m.draw2d = invalid
        m.sceneObjects = []
        m.camera = invalid
        m.triangleCache = BGE_TriangleCache(30)
        m.game = invalid
        m.maxBitmapWidth = 1920
        m.maxBitmapHeight = 1080
        m.game = game
        m.draw2d = draw2d
        if invalid = cam
            cam = BGE_Camera2d()
            cam.setFrameSize(m.draw2d.getWidth(), m.draw2d.getHeight())
            cam.useDefaultCameraTarget()
        end if
        m.camera = cam
    end sub
    instance.resetDrawCallCounter = sub()
        m.drawCallsLastFrame = 0
        m.activeDebugCells = 0
    end sub
    instance.addSceneObject = sub(sceneObj as object)
        sceneObj.setId(m.nextSceneObjectId.toStr().trim())
        m.nextSceneObjectId++
        m.sceneObjects.push(sceneObj)
    end sub
    instance.removeSceneObject = sub(sceneObj as object)
        indexToDelete = - 1
        for i = 0 to m.sceneObjects.count()
            if m.sceneObjects[i].id = sceneObj.id
                indexToDelete = i
                exit for
            end if
        end for
        if indexToDelete >= 0
            m.sceneObjects.delete(indexToDelete)
        end if
        sceneObj.id = ""
    end sub
    instance.updateSceneObjects = sub()
        for each sceneObj in m.sceneObjects
            if sceneObj.isEnabled()
                sceneObj.update(m.camera)
            end if
        end for
    end sub
    instance.setupCameraForFrame = sub()
        m.camera.setFrameSize(m.draw2d.getWidth(), m.draw2d.getHeight())
        m.camera.checkMovement()
        if m.camera.movedLastFrame() or invalid = m.camera.worldToCamera
            m.camera.computeWorldToCameraMatrix()
        end if
    end sub
    instance.drawScene = sub()
        m.updateSceneObjects()
        m.sceneObjects.sortBy("negDistanceFromCamera")
        ' draw sceneObjects in sorted order
        ' ignore any that are too far away (TBD) or behind camera
        for each sceneObj in m.sceneObjects
            if sceneObj.isEnabled()
                if sceneObj.negDistanceFromCamera < 0 'and sceneObj.normnegDistanceFromCamera < 10000
                    sceneObj.draw(m)
                end if
            end if
        end for
    end sub
    instance.onSwapBuffers = sub()
        ' m.bmpPool.clearPool()
        '      '
    end sub
    instance.worldPointToCanvasPoint = function(pWorld as object) as object
        return m.camera.worldPointToCanvasPoint(pWorld)
    end function
    instance.drawLine = function(x as float, y as float, endX as float, endY as float, rgba as integer) as boolean
        return m.drawLineTo(m.draw2d, x, y, endX, endY, rgba)
    end function
    instance.drawLineTo = function(draw2D as object, x as float, y as float, endX as float, endY as float, rgba as integer) as boolean
        width = abs(x - endx) + 1
        height = abs(y - endY) + 1
        if not m.shouldDrawTo(draw2D, x, y, width, height)
            return false
        end if
        m.draw2d.DrawLine(x, y, endX, endY, rgba)
        m.drawCallsLastFrame++
        return true
    end function
    instance.drawSquare = function(x as float, y as float, sideLength as float, rgba as integer) as boolean
        return m.drawSquareTo(m.draw2d, x, y, sideLength, rgba)
    end function
    instance.drawSquareTo = function(draw2D as object, x as float, y as float, sideLength as float, rgba as integer) as boolean
        if not m.shouldDrawTo(draw2D, x - sideLength / 2, y - sideLength / 2, sideLength, sideLength)
            return false
        end if
        draw2d.DrawPoint(x, y, sideLength, rgba)
        m.drawCallsLastFrame++
        return true
    end function
    instance.drawRectangle = function(x as float, y as float, width as float, height as float, rgba as integer) as boolean
        return m.drawRectangleTo(m.draw2d, x, y, width, height, rgba)
    end function
    instance.drawRectangleTo = function(draw2D as object, x as float, y as float, width as float, height as float, rgba as integer) as boolean
        if not m.shouldDrawTo(draw2D, x, y, width, height)
            return false
        end if
        draw2d.DrawRect(x, y, width, height, rgba)
        m.drawCallsLastFrame++
        return true
    end function
    ' Draws text to the screen
    '
    ' @param {string} text the test to display
    ' @param {integer} x
    ' @param {integer} y
    ' @param {integer} [color=-1] RGBA color to use
    ' @param {object} [font=invalid] Font object to use (uses default font if none provided)
    ' @param {string} [horizAlign="left"] Horizontal Alignment - "left", "right" or "center"
    ' @param {string} [vertAlign="left"] Vertical Alignment - "top", "bottom" or "center"
    instance.drawText = function(text as string, x as integer, y as integer, color = - 1 as integer, font = invalid as object, horizAlign = "left" as string, vertAlign = "top" as string) as boolean
        return m.drawTextTo(m.draw2d, text, x, y, color, font, horizAlign, vertAlign)
    end function
    ' Draws text to a canvas
    '
    ' @param {string} text the test to display
    ' @param {integer} x
    ' @param {integer} y
    ' @param {integer} [color=-1] RGBA color to use
    ' @param {object} [font=invalid] Font object to use (uses default font if none provided)
    ' @param {string} [horizAlign="left"] Horizontal Alignment - "left", "right" or "center"
    ' @param {string} [vertAlign="left"] Vertical Alignment - "top", "bottom" or "center"
    instance.drawTextTo = function(draw2D as object, text as string, x as integer, y as integer, color = - 1 as integer, font = invalid as object, horizAlign = "left" as string, vertAlign = "top" as string) as boolean
        if font = invalid
            font = m.game.getFont("default")
        end if
        width = font.GetOneLineWidth(text, 10000)
        height = font.GetOneLineHeight() * BGE_getNumberOfLinesInAString(text)
        textX = x
        textY = y
        if horizAlign = "right"
            textX = x - width
        else if horizAlign = "center"
            textX = x - width / 2
        end if
        if vertAlign = "bottom"
            textY = y - height
        else if vertAlign = "center"
            textY = y - height / 2
        end if
        if m.shouldDrawTo(draw2D, textX, textY, width, height)
            draw2d.DrawText(text, textX, textY, color, font)
            m.drawCallsLastFrame++
            return true
        end if
        return false
    end function
    ' NOTE: This function is unsafe! It creates an roBitmap of the required size to be able to both scale and rotate the drawing, this action requires free video memory of the appropriate amount.
    instance.drawScaledAndRotatedObject = function(x as float, y as float, scaleX as float, scaleY as float, theta as float, drawable as object, rgba = - 1 as integer, rotateAroundX = 0, rotateAroundY = 0) as boolean
        return m.drawScaledAndRotatedObjectTo(m.draw2d, x, y, scaleX, scaleY, theta, drawable, rgba)
    end function
    instance.drawScaledAndRotatedObjectTo = function(draw2D as object, x as float, y as float, scale_x as float, scale_y as float, theta as float, drawable as object, color = - 1 as integer, rotateAroundX = 0, rotateAroundY = 0) as boolean
        new_width = Abs(int(drawable.GetWidth() * scale_x))
        new_height = Abs(int(drawable.GetHeight() * scale_y))
        xToDraw = x
        yToDraw = y
        if scale_x < 0 and scale_y > 0
            xToDraw = x + new_width
            ' scale_x = abs(scale_x)
        else if scale_y < 0 and scale_x > 0
            ' yToDraw = y + new_height
            '  scale_y = abs(scale_y)
        else if scale_y < 0 and scale_x < 0
            '  yToDraw = y + new_height
            ' xToDraw = x + new_width
            '  scale_y = abs(scale_y)
        end if
        if new_width <> 0 and new_height <> 0 and m.shouldDrawTo(draw2d, xToDraw, yToDraw, new_width, new_height, theta)
            'scaledBitmap = m.scratchBitmaps[0]'CreateObject("roBitmap", {width: new_width, height: new_height, AlphaEnable: true})
            scratchRegion = BGE_getScratchRegion(new_width, new_height)
            'scaledRegion = CreateObject("roRegion", scaledBitmap, 0, 0, new_width, new_height)
            if invalid = scratchRegion
                return false
            end if
            scaledRegion = scratchRegion.region
            scaledRegion.clear(0)
            pretranslation_x = drawable.GetPretranslationX()
            pretranslation_y = drawable.GetPretranslationY()
            newPreX = pretranslation_x * scale_x
            scaleXdrawAdjustment = 0 ' need to change draw position if scale is negative
            scaleYdrawAdjustment = 0
            if scale_x < 0
                newPreX = - newPreX
                scaleXdrawAdjustment = new_width
            end if
            newPreY = pretranslation_y * scale_y
            if scale_y < 0
                newPreY = - newPreY
                scaleYDrawAdjustment = new_height
            end if
            scaledRegion.setPretranslation(- Abs(newPreX) + rotateAroundY, - Abs(newPreY) + rotateAroundY)
            scaled_draw_x = Abs(newPreX) + scaleXdrawAdjustment
            scaled_draw_y = Abs(newPreY) + scaleYdrawAdjustment
            scaledRegion.DrawScaledObject(fix(scaled_draw_x), fix(scaled_draw_y), scale_x, scale_y, drawable)
            m.drawCallsLastFrame++
            thetaDeg = BGE_Math_RadiansToDegrees(theta)
            draw2d.DrawRotatedObject(fix(xToDraw), fix(yToDraw), thetaDeg, scaledRegion, color)
            m.drawCallsLastFrame++
            return true
        end if
        return false
    end function
    instance.drawPinnedCorners = function(cornerPoints as object, drawableRegion as object, isMirror = false as boolean, color = - 1 as integer) as boolean
        return m.drawPinnedCornersTo(m.draw2d, cornerPoints, drawableRegion, isMirror, color)
    end function
    instance.drawRotatedImageWithCenterTo = function(draw2D as object, srcRegion as object, center as object, theta as float, translation = BGE_Math_Vector() as object) as boolean
        distanceToCenter = center.length()
        angleToCenter = BGE_Math_GetAngle(BGE_Math_Vector(), center)
        centerRotationAngle = theta - angleToCenter
        rotatedCenter = BGE_Math_Vector(distanceToCenter * cos(centerRotationAngle), - distanceToCenter * sin(centerRotationAngle))
        finalTranslation = translation.add(center.subtract(rotatedCenter))
        return m.drawRotatedObjectTo(draw2D, finalTranslation.x, finalTranslation.y, theta, srcRegion)
    end function
    instance.makeIntoTriangle = function(srcRegionWithId as object, points as object, makeAcute = false, useCache = false) as object
        if useCache
            existingItem = m.triangleCache.getTriangle(srcRegionWithId.id, points)
            if invalid <> existingItem
                return existingItem
            end if
        end if
        srcRegion = srcRegionWithId.region
        srcPreX = 0
        srcPreY = 0
        srcRegion.GetPretranslationX()
        srcRegion.GetPretranslationY()
        if srcPreX <> 0 or srcPreY <> 0
            m.addDebugCell(srcRegion, "srcRegionPreTran")
            scratchRegion1 = BGE_getScratchRegion(srcRegion.getWidth(), srcRegion.getHeight())
            'unPreTranslatedBitmap = m.scratchBitmaps[0]'CreateObject("roBitmap", {width: srcRegion.getWidth(), height: srcRegion.getHeight(), AlphaEnable: true})
            unPreTranslated = CreateObject("roRegion", unPreTranslatedBitmap, 0, 0, srcRegion.getWidth(), srcRegion.getHeight())
            if invalid = scratchRegion1
                return false
            end if
            unPreTranslated = scratchRegion1.region
            if not m.drawObjectTo(unPreTranslated, - srcPreX, - srcPreY, srcRegion)
                return invalid
            end if
            srcRegion = unPreTranslated
        end if
        if points.count() < 3
            return invalid
        end if
        canGetPoints = true
        for i = 0 to 2
            canGetPoints = canGetPoints and m.isInsideCanvas(srcRegion, points[i].x, points[i].y, 1, 1, 0)
            if not canGetPoints
                exit for
            end if
        end for
        if not canGetPoints
            return invalid
        end if
        srcTri = BGE_Math_Triangle(points, false)
        m.addDebugCell(srcRegion, "srcRegion")
        halfPi = BGE_Math_halfPI()
        longestIndex = srcTri.longestIndex
        startIndex = srcTri.nextIndex(longestIndex)
        longestSide = srcTri.getLongestSide()
        bmpSizeW = BGE_math_min(longestSide, m.maxBitmapWidth)
        bmpSizeH = BGE_math_min(longestSide, m.maxBitmapHeight)
        originPoint = srcTri.points[startIndex]
        ' bitmap = m.scratchBitmaps[1]'CreateObject("roBitmap", {width: longestSide, height: longestSide, AlphaEnable: true})
        scratchRegion2 = BGE_getScratchRegion(bmpSizeW, bmpSizeH)
        if invalid = scratchRegion2
            return invalid
        end if
        initialRegion = scratchRegion2.region
        initialAngle = srcTri.anglesToPrevious[startIndex]
        initialCenter = originPoint.negative()
        m.drawRotatedImageWithCenterTo(initialRegion, srcRegion, originPoint, initialAngle, initialCenter)
        m.addDebugCell(initialRegion, "initialRegion")
        ' At this point, we have region where the top line is the longest side of the triangle
        ' find the angle to rotate to cut off the right side
        prevIndex = srcTri.previousIndex(startIndex)
        rightSideTheta = - initialAngle - halfPi + srcTri.anglesToPrevious[prevIndex] ' - halfPi - srcTri.anglesToPrevious[prevIndex]
        'bitmap2 = m.scratchBitmaps[0]'CreateObject("roBitmap", {width: longestSide, height: longestSide, AlphaEnable: true})
        scratchRegion3 = BGE_getScratchRegion(bmpSizeW, bmpSizeH)
        if invalid = scratchRegion3
            return invalid
        end if
        region2 = scratchRegion3.region
        m.drawRotatedImageWithCenterTo(region2, initialRegion, BGE_Math_Vector(bmpSizeW, 0), rightSideTheta)
        m.addDebugCell(region2, "region2")
        bitmap3 = CreateObject("roBitmap", {
            width: fix(bmpSizeW + 1)
            height: fix(bmpSizeH + 1)
            AlphaEnable: true
        })
        region3 = CreateObject("roRegion", bitmap3, 0, 0, bmpSizeW, bmpSizeH)
        if invalid = region3
            return invalid
        end if
        region3.SetScaleMode(1)
        prevIndex = srcTri.previousIndex(prevIndex)
        lastRotCenter = BGE_Math_Vector(longestSide - longestSide * cos(rightSideTheta), longestSide * sin(rightSideTheta))
        leftSideTheta = - srcTri.angles[prevIndex]
        m.drawRotatedImageWithCenterTo(region3, region2, lastRotCenter, leftSideTheta, lastRotCenter.negative())
        resultPoints = [
            BGE_Math_Vector()
            BGE_Math_Vector()
            BGE_Math_Vector()
        ]
        ' next point is always mapped to (0,0)
        index = (longestIndex + 1) mod 3
        resultPoints[index].x = 0
        resultPoints[index].y = 0
        ' prevPoint is always on the y-axis
        nextLength = srcTri.lengths[index]
        index = (index + 1) mod 3
        resultPoints[index].y = nextLength ' prevpoint is where the next leg ends
        ' last point(longestPoint) is found via trig
        index = longestIndex
        finalAngle = srcTri.angles[(longestIndex + 1) mod 3]
        resultPoints[index].x = fix(longestSide * cos(halfPi - finalAngle))
        resultPoints[index].y = fix(longestSide * sin(halfPi - finalAngle))
        'm.drawTrianglePointsTo(region3, resultPoints)
        result = BGE_TriangleBitmap(region3, resultPoints)
        result.angleRotatedFromOriginal = BGE_Math_halfPi() - srcTri.anglesToNext[srcTri.nextIndex(longestIndex)]
        m.addDebugCell(region3, "triangle")
        if not result.isAcute() and makeAcute
            ' Make the cached triangles Acute, so it is easier to transform them into obtuse triangles later
            result = m.scaleTriangleToBeAcuteTriangle(result)
            if result = invalid
                return invalid
            end if
            m.addDebugCell(result.bitmap, "acutetriangle")
        end if
        if useCache
            m.triangleCache.addTriangle(srcRegionWithId.id, points, result)
        end if
        return result
    end function
    instance.drawBitmapTriangleTo = function(draw2D as object, srcRegionWithId as object, srcPoints as object, destPoints as object) as boolean
        if srcPoints.count() < 3 or destPoints.count() < 3
            return false
        end if
        shouldDraw = false
        for i = 0 to 3
            shouldDraw = shouldDraw or m.shouldDrawTo(draw2d, destPoints[i].x, destPoints[i].y, 1, 1, 0)
            if shouldDraw
                exit for
            end if
        end for
        if not shouldDraw
            return false
        end if
        srcTriangle = m.makeIntoTriangle(srcRegionWithId, srcPoints, true, true)
        srcRegion = srcRegionWithId.region
        if invalid = srcTriangle
            return false
        end if
        destTriangle = BGE_Math_Triangle(destPoints)
        srcOriginIndex = srcTriangle.getOriginIndex()
        if srcOriginIndex <> destTriangle.nextIndex(destTriangle.longestIndex) and destTriangle.isObtuse()
            'rearrange srcTriangle so side that corresponds to dest's longest side is on top of a bitmap
            srcTriangle = m.rotateAcuteTriangleForDesiredOrigin(srcTriangle, destTriangle.nextIndex(destTriangle.longestIndex))
        end if
        if invalid = srcTriangle
            return false
        end if
        pivotIndex = srcTriangle.previousIndex(srcTriangle.getOriginIndex())
        nextIndex = srcTriangle.nextIndex(pivotIndex)
        prevIndex = srcTriangle.nextIndex(nextIndex)
        finalBitmapWidth = BGE_Math_min(destTriangle.getLongestSide() * 1.33, m.maxBitmapWidth)
        finalBitmapHeight = BGE_Math_min(finalBitmapWidth, m.maxBitmapHeight)
        mappedLongestLength = destTriangle.lengths[pivotIndex]
        mappedPreviousLength = destTriangle.lengths[prevIndex]
        mappedNextLength = destTriangle.lengths[nextIndex]
        srcScales = m.getScalesForTriangleMapping(srcTriangle, destTriangle)
        srcXScale = srcScales.x
        srcYScale = srcScales.y
        srcPivot = srcTriangle.points[pivotIndex]
        mappedOriginPointAfterLengthSet = BGE_Math_Vector(srcPivot.x * srcXScale, srcPivot.y * srcYScale)
        changedPointOnYAxis = srcTriangle.points[prevIndex].copy()
        changedPointOnYAxis.y *= srcYScale
        angleToMappedLongest = BGE_Math_GetAngle(BGE_Math_Vector(), mappedOriginPointAfterLengthSet)
        distanceToMappedLongest = BGE_Math_min(mappedOriginPointAfterLengthSet.length(), m.maxBitmapWidth)
        newHeightAfterChange = BGE_Math_min(changedPointOnYAxis.y, m.maxBitmapHeight)
        'scaledSrcBitmap = m.scratchBitmaps[0]'CreateObject("roBitmap", {width: distanceToMappedLongest, height: changedPointOnYAxis.y, AlphaEnable: true})
        'scaledSrcRegion = CreateObject("roRegion", scaledSrcBitmap, 0, 0, distanceToMappedLongest, changedPointOnYAxis.y)
        'if invalid = scaledSrcRegion
        ' return false
        'end if
        scratchRegion1 = BGE_getScratchRegion(distanceToMappedLongest, newHeightAfterChange)
        if invalid = scratchRegion1
            return false
        end if
        scaledSrcRegion = scratchRegion1.region
        m.drawScaledObjectTo(scaledSrcRegion, 0, 0, srcXScale, srcYScale, srcTriangle.bitmap)
        m.drawTrianglePointsTo(scaledSrcRegion, [
            BGE_Math_Vector()
            BGE_Math_Vector(0, newHeightAfterChange) ' was changedPointOnYAxis, but this is not safe - could be too big
            mappedOriginPointAfterLengthSet
        ])
        m.addDebugCell(scaledSrcRegion, "scaledSrcRegion")
        destOrigin = destTriangle.points[nextIndex]
        finalAngle = BGE_Math_GetAngle(destOrigin, destTriangle.points[pivotIndex])
        rotatedTriHeight = changedPointOnYAxis.y * cos(angleToMappedLongest)
        rotatedRegionHeight = BGE_math_min(rotatedTriHeight, m.maxBitmapHeight)
        ' rotatedBitmap = m.scratchBitmaps[1]'CreateObject("roBitmap", {width: distanceToMappedLongest, height: rotatedRegionHeight, AlphaEnable: true})
        ' rotatedRegion = CreateObject("roRegion", rotatedBitmap, 0, 0, distanceToMappedLongest, rotatedRegionHeight)
        ' if rotatedRegion = invalid
        '   return false
        ' end if
        ' rotatedRegion.clear(0)
        ' rotatedRegion.SetScaleMode(1)
        scratchRegion2 = BGE_getScratchRegion(distanceToMappedLongest, rotatedRegionHeight)
        if invalid = scratchRegion2
            return false
        end if
        rotatedRegion = scratchRegion2.region
        angleToMappedLongest = Bge_Math_Max(angleToMappedLongest, 0.05)
        m.drawRotatedObjectTo(rotatedRegion, 0, 0, angleToMappedLongest, scaledSrcRegion)
        m.addDebugCell(rotatedRegion, "rotatedRegion")
        firstPartLength = BGE_Math_Max(changedPointOnYAxis.y * sin(angleToMappedLongest), 0)
        secondPartLength = distanceToMappedLongest - firstPartLength
        firstPartRegion = CreateObject("roRegion", scratchRegion2.getBitmapObject(), 0, 0, firstPartLength, rotatedTriHeight)
        if invalid = firstPartRegion
            return false
        end if
        firstPartRegion.SetScaleMode(1)
        secondPartRegion = CreateObject("roRegion", scratchRegion2.getBitmapObject(), BGE_Math_Max(0, firstPartLength - 1), 0, secondPartLength, rotatedTriHeight)
        if invalid = secondPartRegion
            return false
        end if
        secondPartRegion.SetScaleMode(1)
        destFirstPartWidth = mappedNextLength * cos(destTriangle.angles[nextIndex])
        destSecondPartWidth = mappedLongestLength - destFirstPartWidth
        firstPartScaleX = 0
        if firstPartLength > 0
            firstPartScaleX = destFirstPartWidth / firstPartLength
        end if
        secondPartScaleX = 0
        if secondPartLength > 0
            secondPartScaleX = destSecondPartWidth / secondPartLength
        end if
        if rotatedTriHeight = 0
            return false
        end if
        finalScaleY = destTriangle.getHeightByTangentIndex(nextIndex) / rotatedTriHeight
        ' finalBitmap = m.scratchBitmaps[2]'CreateObject("roBitmap", {width: finalBitmapWidth, height: finalBitmapHeight, AlphaEnable: true})
        ' finalRegion = CreateObject("roRegion", finalBitmap, 0, 0, finalBitmapWidth, finalBitmapHeight)
        ' if invalid = finalRegion
        '   return false
        ' end if
        ' finalRegion.clear(0)
        scratchRegion3 = BGE_getScratchRegion(finalBitmapWidth, finalBitmapHeight)
        if invalid = scratchRegion3 or scratchRegion3.region = invalid
            return false
        end if
        finalRegion = scratchRegion3.region
        m.addDebugCell(firstPartRegion, "firstPartRegion")
        m.addDebugCell(secondPartRegion, "secondPartRegion")
        finalRegion.SetScaleMode(1)
        didDraw = true
        if firstPartScaleX <> 0
            didDraw = m.DrawScaledObjectTo(finalRegion, 0, 0, firstPartScaleX * 1.01, finalScaleY * 1.01, firstPartRegion)
        end if
        if didDraw and invalid <> secondPartRegion
            didDraw = m.DrawScaledObjectTo(finalRegion, destFirstPartWidth - 1, 0, secondPartScaleX * 1.01, finalScaleY * 1.01, secondPartRegion)
        end if
        m.addDebugCell(finalRegion, "finalRegion")
        if (didDraw)
            didDraw = m.drawRotatedObjectTo(draw2d, destOrigin.x, destOrigin.y, - finalAngle, finalRegion)
        end if
        return didDraw
    end function
    instance.getScalesForTriangleMapping = function(srcTriangle as object, destTriangle as object) as object
        srcXScale = 1
        srcYScale = 1
        foundXScale = false
        pivotIndex = srcTriangle.previousIndex(srcTriangle.getOriginIndex())
        nextIndex = srcTriangle.nextIndex(pivotIndex)
        prevIndex = srcTriangle.nextIndex(nextIndex)
        mappedLongestLength = destTriangle.lengths[pivotIndex]
        mappedPreviousLength = destTriangle.lengths[prevIndex]
        mappedNextLength = destTriangle.lengths[nextIndex]
        srcLongestLength = srcTriangle.lengths[pivotIndex]
        srcPreviousLength = srcTriangle.lengths[prevIndex]
        srcNextLength = srcTriangle.lengths[nextIndex]
        srcOriginPointX = srcTriangle.points[pivotIndex].x
        destFirstPartWidth = mappedNextLength * cos(destTriangle.angles[nextIndex])
        destSecondPartWidth = mappedLongestLength - destFirstPartWidth
        if destSecondPartWidth > 0 and destFirstPartWidth > 0
            k = destFirstPartWidth / destSecondPartWidth
            y = srcNextLength
            y1 = srcTriangle.points[pivotIndex].y
            y2 = y - y1
            insideSqr = ((y * y + y1 * y1 - y2 * y2) / (2 * k * k + 2 * k))
            if insideSqr > 0
                beta = sqr(insideSqr)
                alpha = beta * k
                c = alpha + beta
                insideSqr2 = c * c - y1 * y1
                if insideSqr2 > 0
                    whereSrcOriginPointXNeedsToBe = sqr(insideSqr2)
                    whereSrcOriginPointXNeedsToBe = BGE_Math_min(whereSrcOriginPointXNeedsToBe, 10 * mappedLongestLength)
                    foundXScale = true
                end if
            end if
        end if
        if not foundXScale
            srcYScale = mappedNextLength / srcTriangle.lengths[nextIndex]
            srcPointOnYAxis = srcTriangle.points[prevIndex]
            changedPointOnYAxis = srcPointOnYAxis.copy()
            changedPointOnYAxis.y *= srcYScale
            changedPointOnYAxisYDelta = mappedNextLength - srcTriangle.lengths[nextIndex]
            srcOriginPointYAfterScale = srcTriangle.points[pivotIndex].y * srcYScale
        end if
        if not foundXScale
            ' Scale so yAxis edge and bottom edge are correct length for dest
            pythagorasLeg = mappedNextLength - srcOriginPointYAfterScale
            insideSqrForLegs = mappedPreviousLength * mappedPreviousLength - pythagorasLeg * pythagorasLeg
            if insideSqrForLegs > 0
                whereSrcOriginPointXNeedsToBe = sqr(insideSqrForLegs)
                checkLength = whereSrcOriginPointXNeedsToBe * whereSrcOriginPointXNeedsToBe - srcOriginPointYAfterScale * srcOriginPointYAfterScale
                if checklength > 0
                    foundXScale = true
                end if
            end if
        end if
        if not foundXScale
            'make angle at origin the same as the "nextAngle" of destTri
            whereSrcOriginPointXNeedsToBe = srcOriginPointYAfterScale * tan(destTriangle.angles[nextIndex])
            checkLength = whereSrcOriginPointXNeedsToBe * whereSrcOriginPointXNeedsToBe - srcOriginPointYAfterScale * srcOriginPointYAfterScale
            if checklength > 0
                foundXScale = true
            end if
        end if
        if not foundXScale
            ' Scale so yAxis edge and top edge are correct length for dest
            insideSqrForTopSide = mappedLongestLength * mappedLongestLength - srcOriginPointYAfterScale * srcOriginPointYAfterScale
            if insideSqrForTopSide > 0
                whereSrcOriginPointXNeedsToBe = sqr(insideSqrForTopSide)
                foundXScale = true
            end if
        end if
        if not foundXScale
            ' Scale so point's x is equal to dest longest length
            whereSrcOriginPointXNeedsToBe = mappedLongestLength
            foundXScale = true
        end if
        if srcOriginPointX <> 0
            srcXScale = whereSrcOriginPointXNeedsToBe / srcOriginPointX
        end if
        return BGE_Math_Vector(srcXScale, srcYScale)
    end function
    ' There can be problems transforming a source triangle to a destination triangle when they are obtuse and the longest sides don't match up
    ' This function will scale a source triangle along the axis of its longest side so that it is an acute-triangle
    instance.scaleTriangleToBeAcuteTriangle = function(srcTriangle as object) as object
        pivotIndex = srcTriangle.previousIndex(srcTriangle.getOriginIndex())
        nextIndex = srcTriangle.nextIndex(pivotIndex)
        prevIndex = srcTriangle.nextIndex(nextIndex)
        pointA = srcTriangle.points[pivotIndex]
        pointB = srcTriangle.points[nextIndex]
        pointC = srcTriangle.points[prevIndex]
        srcLongestLength = srcTriangle.getLongestSide()
        srcNextLength = srcTriangle.lengths[nextIndex]
        srcPrevLength = srcTriangle.lengths[prevIndex]
        firstRotation = srcTriangle.anglesToPrevious[nextIndex]
        'rotatedSrcBitmap = CreateObject("roBitmap", {width: srcLongestLength, height: srcLongestLength, AlphaEnable: true})
        'rotatedSrcRegion = CreateObject("roRegion", rotatedSrcBitmap, 0, 0, finalBitmapWidth, finalBitmapHeight)
        scratchRegion1 = BGE_getScratchRegion(srcLongestLength, srcLongestLength)
        if invalid = scratchRegion1
            return invalid
        end if
        rotatedSrcRegion = scratchRegion1.region
        m.drawRotatedObjectTo(rotatedSrcRegion, 0, 0, firstRotation, srcTriangle.bitmap)
        newPrevPointY = srcNextLength * cos(firstRotation)
        newPrevPointX = srcNextLength * sin(firstRotation)
        m.addDebugCell(rotatedSrcRegion, "rotatedSrcRegion")
        ' Scaling from Y-axis will mean the ratio between triangle legs will be constant
        ' So we can set that ratio equal to tan(newNextAngle) and use atn() to get newNextAngle
        ' Once We know newNextAngle, we can use its complement to find the distance of the acuteAngle of the scaled triangle
        ' from the y-axis
        ' And from that, get the scale
        ratio = srcPrevLength / srcNextLength
        newNextAngle = atn(ratio)
        scaleYToMakeAcute = 1.2
        bottomYForRightTriangle = srcNextLength / sin(newNextAngle)
        ' = srcTriangle.height * tan(BGE.Math.halfPI() - newNextAngle)
        acuteNextY = scaleYToMakeAcute * bottomYForRightTriangle
        scaleY = acuteNextY / newPrevPointY
        newSrcLongest = srcLongestLength
        newNextLength = sqr(newPrevPointX * newPrevPointX + acuteNextY * acuteNextY)
        newBitmapSize = BGE_Math_Max(srcLongestLength * scaleYToMakeAcute, newNextLength)
        'acuteTriBitmap = CreateObject("roBitmap", {width: newBitmapSize, height: newBitmapSize, AlphaEnable: true})
        '  acuteTriangleSrcRegion = CreateObject("roRegion", rotatedSrcBitmap, 0, 0, finalBitmapWidth, finalBitmapHeight)
        scratchRegion2 = BGE_getScratchRegion(newBitmapSize, newBitmapSize)
        if invalid = scratchRegion2
            return invalid
        end if
        acuteTriRegion = scratchRegion2.region
        m.drawScaledObjectTo(acuteTriRegion, 0, 0, 1, scaleY, rotatedSrcRegion)
        m.addDebugCell(acuteTriRegion, "acuteTriRegion")
        acuteTriRotBmp = CreateObject("roBitmap", {
            width: newBitmapSize
            height: newBitmapSize
            AlphaEnable: true
        })
        '  acuteTriangleSrcRegion = CreateObject("roRegion", rotatedSrcBitmap, 0, 0, finalBitmapWidth, finalBitmapHeight)
        if invalid = acuteTriRotBmp
            return invalid
        end if
        afterScaleHeight = acuteNextY '(srcTriangle.height * scaleYToMakeAcute)
        afterScaleTheta = atn(newPrevPointX / afterScaleHeight)
        m.drawRotatedObjectTo(acuteTriRotBmp, 0, 0, - afterScaleTheta, acuteTriRegion)
        m.addDebugCell(acuteTriRotBmp, "acuteTriRotBmp")
        newLongestPoint = BGE_Math_Vector(cos(afterScaleTheta), sin(afterScaleTheta))
        yAxisPoint = newNextLength 'sqr(acuteAngleOffsetToMakeItARightTriangle * acuteAngleOffsetToMakeItARightTriangle + afterScaleHeight * afterScaleHeight)
        acuteTrianglePoints = [
            BGE_Math_Vector()
            BGE_Math_Vector()
            BGE_Math_Vector()
        ]
        yaxisPointIndex = srcTriangle.nextIndex(srcTriangle.getOriginIndex())
        acuteTrianglePoints[yaxisPointIndex] = BGE_Math_Vector(0, yAxisPoint)
        acuteTrianglePoints[srcTriangle.longestIndex] = newLongestPoint.scale(newSrcLongest)
        '  m.addDebugCell(acuteTriRotBmp, "acuteTriRotBmp")
        acuteTriangle = BGE_TriangleBitmap(acuteTriRotBmp, acuteTrianglePoints)
        return acuteTriangle
    end function
    instance.rotateAcuteTriangleForDesiredOrigin = function(srcTriangle as object, indexForOrigin as integer) as object
        if srcTriangle.points[indexForOrigin].x = 0 and srcTriangle.points[indexForOrigin].y = 0
            return srcTriangle
        end if
        bitmapSize = srcTriangle.getLongestSide()
        rotForCorrectOrigin = CreateObject("roBitmap", {
            width: bitmapSize
            height: bitmapSize
            AlphaEnable: true
        })
        beforeOrigin = srcTriangle.points[indexForOrigin]
        theta = BGE_Math_HalfPi() - srcTriangle.anglesToNext[indexForOrigin]
        translation = beforeOrigin.negative()
        m.drawRotatedImageWithCenterTo(rotForCorrectOrigin, srcTriangle.bitmap, beforeOrigin, - theta, translation)
        newTrianglePoints = [
            BGE_Math_Vector()
            BGE_Math_Vector()
            BGE_Math_Vector()
        ]
        nextIndex = srcTriangle.nextIndex(indexForOrigin)
        newOriginAngle = srcTriangle.angles[indexForOrigin]
        newTrianglePoints[nextIndex].y = srcTriangle.lengths[indexForOrigin]
        prevIndex = srcTriangle.nextIndex(nextIndex)
        newTrianglePoints[prevIndex].x = srcTriangle.lengths[prevIndex] * sin(srcTriangle.angles[indexForOrigin])
        newTrianglePoints[prevIndex].y = srcTriangle.lengths[prevIndex] * cos(srcTriangle.angles[indexForOrigin])
        m.drawTrianglePointsTo(rotForCorrectOrigin, newTrianglePoints)
        ' m.addDebugCell(rotForCorrectOrigin, "rotForCorrectOrigin")
        rotatedTriangle = BGE_TriangleBitmap(rotForCorrectOrigin, newTrianglePoints)
        return rotatedTriangle
    end function
    instance.drawPinnedCornersTo = function(draw2D as object, cornerPoints as object, drawableRegion as object, isMirror = false as boolean, color = - 1 as integer) as boolean
        diagonalLengths = cornerPoints.computeDiagonalLengths()
        sideLengths = cornerPoints.computeSideLengths()
        srcWidth = drawableRegion.region.getWidth()
        srcHeight = drawableRegion.region.getHeight()
        splitIntoFour = false
        if splitIntoFour
            worked = true
            srcPoints = BGE_Math_CornerPoints()
            srcPoints.topLeft = BGE_Math_Vector(0, 0)
            srcPoints.topRight = BGE_Math_Vector(srcWidth, 0)
            srcPoints.bottomLeft = BGE_Math_Vector(0, srcHeight)
            srcPoints.bottomRight = BGE_Math_Vector(srcWidth, srcHeight)
            srcCenter = srcPoints.getCenter()
            destCenter = cornerPoints.getCenter()
            src = [
                srcPoints.topLeft
                srcCenter
                srcPoints.topRight
            ]
            dest = [
                cornerPoints.topLeft
                destCenter
                cornerPoints.topRight
            ]
            worked = worked and m.drawBitmapTriangleTo(draw2d, drawableRegion, src, dest)
            src = [
                srcPoints.topRight
                srcCenter
                srcPoints.bottomRight
            ]
            dest = [
                cornerPoints.topRight
                destCenter
                cornerPoints.bottomRight
            ]
            worked = worked and m.drawBitmapTriangleTo(draw2d, drawableRegion, src, dest)
            src = [
                srcPoints.bottomRight
                srcCenter
                srcPoints.bottomLeft
            ]
            dest = [
                cornerPoints.bottomRight
                destCenter
                cornerPoints.bottomLeft
            ]
            worked = worked and m.drawBitmapTriangleTo(draw2d, drawableRegion, src, dest)
            src = [
                srcPoints.bottomLeft
                srcCenter
                srcPoints.topLeft
            ]
            dest = [
                cornerPoints.bottomLeft
                destCenter
                cornerPoints.topLeft
            ]
            worked = worked and m.drawBitmapTriangleTo(draw2d, drawableRegion, src, dest)
            return worked
        end if
        ' split into two triangles
        if true or diagonalLengths[0] > diagonalLengths[1]
            'topLeft to BottomRight Diag
            topRightSrc = [
                BGE_Math_Vector(0, 0)
                BGE_Math_Vector(srcWidth, srcHeight)
                BGE_Math_Vector(srcWidth, 0)
            ]
            bottomLeftSrc = [
                BGE_Math_Vector(srcWidth, srcHeight)
                BGE_Math_Vector(0, 0)
                BGE_Math_Vector(0, srcHeight)
            ]
            topRightDest = [
                cornerPoints.topLeft
                cornerPoints.bottomRight
                cornerPoints.topRight
            ]
            bottomLeftDest = [
                cornerPoints.bottomRight
                cornerPoints.topLeft
                cornerPoints.bottomLeft
            ]
            worked = m.drawBitmapTriangleTo(draw2d, drawableRegion, topRightSrc, topRightDest)
            worked = worked and m.drawBitmapTriangleTo(draw2d, drawableRegion, bottomLeftSrc, bottomLeftDest)
        else 'topRight to BottomLeft Diag
            topLeftSrc = [
                BGE_Math_Vector(0, srcHeight)
                BGE_Math_Vector(srcWidth, 0)
                BGE_Math_Vector(0, 0)
            ]
            bottomRightSrc = [
                BGE_Math_Vector(srcWidth, 0)
                BGE_Math_Vector(0, srcHeight)
                BGE_Math_Vector(srcWidth, srcHeight)
            ]
            topLeftDest = [
                cornerPoints.bottomLeft
                cornerPoints.topRight
                cornerPoints.topLeft
            ]
            bottomRightDest = [
                cornerPoints.topRight
                cornerPoints.bottomLeft
                cornerPoints.bottomRight
            ]
            worked = m.drawBitmapTriangleTo(draw2d, drawableRegion, topLeftSrc, topLeftDest)
            worked = worked and m.drawBitmapTriangleTo(draw2d, drawableRegion, bottomRightSrc, bottomRightDest)
        end if
        return worked
    end function
    instance.drawCircleOutline = function(line_count as integer, x as float, y as float, radius as float, rgba as integer) as boolean
        if not m.shouldDraw(x - radius, y - radius, radius * 2, radius * 2)
            return false
        end if
        previous_x = radius
        previous_y = 0
        for i = 0 to line_count
            degrees = 360 * (i / line_count)
            current_x = cos(degrees * .01745329) * radius
            current_y = sin(degrees * .01745329) * radius
            m.draw2d.DrawLine(x + previous_x, y + previous_y, x + current_x, y + current_y, rgba)
            m.drawCallsLastFrame++
            previous_x = current_x
            previous_y = current_y
        end for
        return true
    end function
    instance.drawRectangleOutline = function(x as float, y as float, width as float, height as float, rgba as integer) as boolean
        if not m.shouldDraw(x, y, width, height)
            return false
        end if
        m.draw2d.DrawLine(x, y, x + width, y, rgba)
        m.draw2d.DrawLine(x, y, x, y + height, rgba)
        m.draw2d.DrawLine(x + width, y, x + width, y + height, rgba)
        m.draw2d.DrawLine(x, y + height, x + width, y + height, rgba)
        m.drawCallsLastFrame += 4
        return true
    end function
    instance.drawPolygonOutline = function(pointsArray as object, colorRgba as integer) as boolean
        return m.drawPolygonOutlineTo(m.draw2d, pointsArray, colorRgba)
    end function
    instance.drawPolygonOutlineTo = function(draw2d as object, pointsArray as object, colorRgba as integer) as boolean
    end function
    instance.drawObject = function(x as integer, y as integer, src as object, rgba = - 1 as integer) as boolean
        return m.drawObjectTo(m.draw2d, x, y, src, rgba)
    end function
    instance.drawObjectTo = function(draw2d as object, x as integer, y as integer, src as object, rgba = - 1 as integer) as boolean
        if not m.shouldDrawTo(draw2d, x, y, src.getWidth(), src.getHeight())
            return false
        end if
        draw2d.drawObject(fix(x), fix(y), src, rgba)
        m.drawCallsLastFrame++
        return true
    end function
    instance.drawScaledObject = function(x as integer, y as integer, scaleX as float, scaleY as float, src as object) as boolean
        return m.drawScaledObjectTo(m.draw2d, x, y, scaleX, scaleY, src)
    end function
    instance.drawScaledObjectTo = function(draw2d as object, x as integer, y as integer, scaleX as float, scaleY as float, src as object) as boolean
        if src = invalid or not m.shouldDrawTo(draw2d, x, y, src.getWidth() * scaleX, src.getHeight() * scaleY)
            return false
        end if
        draw2d.DrawScaledObject(fix(x), fix(y), scaleX, scaleY, src)
        m.drawCallsLastFrame++
        return true
    end function
    instance.drawRotatedObject = function(x as integer, y as integer, theta as float, src as object) as boolean
        return m.drawRotatedObjectTo(m.draw2d, x, y, theta, src)
    end function
    instance.drawRotatedObjectTo = function(draw2d as object, x as integer, y as integer, theta as float, src as object) as boolean
        if draw2d = invalid or src = invalid or not m.shouldDrawTo(draw2d, x, y, src.getWidth(), src.getHeight(), theta)
            return false
        end if
        thetaDeg = BGe_Math_RadiansToDegrees(theta)
        draw2d.DrawRotatedObject(fix(x), fix(y), thetaDeg, src)
        m.drawCallsLastFrame++
        return true
    end function
    instance.drawRegion = function(regionToDraw as object, x as float, y as float, scaleX = 1 as float, scaleY = 1 as float, rotation = 0 as float, RGBA = - 1 as integer) as boolean
        return m.drawRegionTo(m.draw2d, regionTodraw, x, y, scaleX, scaleY, rotation, RGBA)
    end function
    instance.drawRegionTo = function(canvasDrawTo as object, regionToDraw as object, x as float, y as float, scaleX = 1 as float, scaleY = 1 as float, rotation = 0 as float, RGBA = - 1 as integer) as boolean
        if scaleX = 1 and scaleY = 1 and rotation = 0
            return m.DrawObjectTo(canvasDrawTo, x, y, regionToDraw, rgba)
        else if rotation = 0
            return m.DrawScaledObjectTo(canvasDrawTo, x, y, scaleX, scaleY, regionToDraw)
        else if scaleX = 1 and scaleY = 1
            return m.DrawRotatedObjectTo(canvasDrawTo, x, y, - rotation, regionToDraw)
        else
            return m.DrawScaledAndRotatedObjectTo(canvasDrawTo, x, y, scaleX, scaleY, - rotation, regionToDraw, rgba)
        end if
        return false
    end function
    instance.drawTriangle = function(points as object, x as float, y as float, rgba as integer) as boolean
        return m.drawTriangleTo(m.draw2d, points, x, y, rgba)
    end function
    instance.drawTriangleTo = function(canvasDrawTo as object, points as object, x as float, y as float, rgba as integer) as boolean
        if points.count() <> 3
            return false
        end if
        bounds = BGE_Math_getBounds(points)
        minP = bounds[0]
        maxP = bounds[1]
        totalXOffset = x + minP.x
        totalYOffset = y + minP.y
        newCenter = points[0].copy()
        newCenter.x += x
        newCenter.y += y
        srcSize = maxP.subtract(minP)
        offsetPoints = []
        for i = 0 to 2
            point = points[i]
            offsetPoints.push(point.subtract(minP))
        end for
        srcTriangle = BGE_Math_Triangle(points)
        polyId = "polyTriangle"
        ' polyBitmap = m.triangleCache.getTriangle(polyId, offsetPoints)
        'if invalid = polyBitmap
        scratchRegion = BGE_getScratchRegion(srcSize.x, srcSize.y)
        if invalid = scratchRegion or invalid = scratchRegion.region
            return false
        end if
        triSrcRegion = scratchRegion.region
        m.drawRectangleTo(triSrcRegion, 0, 0, srcSize.x, srcSize.y, rgba)
        polyBitmap = m.makeIntoTriangle(BGE_RegionWithId(triSrcRegion, polyId), offsetPoints, false, false)
        if invalid = polyBitmap
            return false
        end if
        longestPoint = offsetPoints[srcTriangle.nextIndex(srcTriangle.longestIndex)]
        'm.drawTrianglePointsTo(polyBitmap.bitmap, offsetPoints)
        ' theta = - +
        theta = polyBitmap.angleRotatedFromOriginal
        didDraw = m.drawRotatedObjectTo(canvasDrawTo, totalXOffset + longestpoint.x, totalYoffset + longestPoint.y, theta, polyBitmap.bitmap) ', 1, 1, 0, rgba)
        return didDraw
    end function
    instance.drawPolygon = function(points as object, x as float, y as float, rgba as integer) as boolean
        return m.drawPolygonTo(m.draw2d, points, x, y, rgba)
    end function
    instance.drawPolygonTo = function(canvasDrawTo as object, points as object, x as float, y as float, rgba as integer) as boolean
        if points.count() < 3
            return false
        end if
        if points.count() = 3
            return m.drawTriangleTo(canvasDrawTo, points, x, y, rgba)
        end if
        triangles = BGE_QuickHull_getTrianglesFromPoints(points, true)
        didDraw = true
        for each tri in triangles
            didDraw = m.drawTriangleTo(canvasDrawTo, tri, x, y, rgba) or didDraw
        end for
        return didDraw
    end function
    instance.getCanvasSize = function() as object
        return BGE_Math_Vector(m.draw2d.getWidth(), m.draw2d.getHeight())
    end function
    instance.getCanvasCenter = function() as object
        return BGE_Math_Vector(fix(m.draw2d.getWidth() / 2), fix(m.draw2d.getHeight() / 2))
    end function
    instance.shouldDraw = function(x as float, y as float, width as float, height as float, rotation = 0 as float) as boolean
        return m.shouldDrawTo(m.draw2d, x, y, width, height, rotation)
    end function
    instance.shouldDrawTo = function(draw2d as object, x as float, y as float, width as float, height as float, rotation = 0 as float) as boolean
        if draw2d = invalid or width = 0 or height = 0
            return false
        end if
        if not m.onlyDrawWhenInFrame
            return true
        end if
        return m.isInsideCanvas(draw2d, x, y, width, height, rotation)
    end function
    ' Checks to see if a rectangle will be in a Draw2d Canvas
    '
    ' @param {object} draw2d
    ' @param {float} x
    ' @param {float} y
    ' @param {float} width
    ' @param {float} height
    ' @return {boolean} true if this rectangle overlaps with the canvas
    instance.isInsideCanvas = function(draw2d as object, x as float, y as float, width as float, height as float, rotation = 0 as float) as boolean
        canvasWidth = draw2d.getWidth()
        canvasHeight = draw2d.getHeight()
        origx = x
        origy = y
        if rotation <> 0
            ' use diagonal as radius for seeing where rotated points could be
            ' this gives a bigger approximation for rotated objects, but is easier
            radius = Sqr(width * width + height * height)
            x = BGE_Math_Min(x, x + sin(rotation) * radius)
            y = BGE_Math_Min(y, y - sin(rotation) * radius)
            width = radius
            height = radius
        end if
        corners = [
            {
                x: x
                y: y
            }
            {
                x: x + width
                y: y
            }
            {
                x: x
                y: y + height
            }
            {
                x: x + width
                y: y + height
            }
        ]
        ' check each corner
        insideCanvas = false
        for each point in corners
            if point.x >= 0 and point.x <= canvasWidth and point.y >= 0 and point.y <= canvasHeight
                ' if one corner is in then this will be drawn
                insideCanvas = true
                exit for
            end if
        end for
        ' no corner is in the canvas, but this whole thing could overlap somehow
        if not insideCanvas and x < 0 and (x + width) > canvasWidth
            if y < 0
                insideCanvas = (y + height) >= 0
            else if y <= canvasHeight
                insideCanvas = true
            end if
        end if
        if not insideCanvas and y < 0 and (y + height) > canvasHeight
            if x < 0
                insideCanvas = (x + width) >= 0
            else if x <= canvasWidth
                insideCanvas = true
            end if
        end if
        return insideCanvas
    end function
    instance.drawTrianglePoints = function(points as object, size = 5 as integer) as boolean
        return m.drawTrianglePointsTo(m.draw2d, points, size)
    end function
    instance.drawTrianglePointsTo = function(draw2dRegion as object, points as object, size = 5 as integer) as boolean
        if not m.drawDebugCells
            return false
        end if
        if draw2dRegion = invalid or points = invalid or points.count() < 3
            return false
        end if
        m.drawSquareTo(draw2dRegion, points[0].x, points[0].y, size, BGE_Colors().Red)
        m.drawSquareTo(draw2dRegion, points[1].x, points[1].y, size, BGE_Colors().Green)
        m.drawSquareTo(draw2dRegion, points[2].x, points[2].y, size, BGE_Colors().Blue)
        return true
    end function
    instance.addDebugCell = sub(region as object, text = "" as string)
        if not m.drawDebugCells
            return
        end if
        regionWidth = region.getWidth()
        regionHeight = region.getHeight()
        scale = m.debugCellSize - 2
        offsetX = 1
        offsetY = 1
        if regionWidth > regionHeight
            scale = scale / regionWidth
            offsetY = m.debugCellSize / 2 - scale * regionHeight / 2 + 1
        else
            scale = scale / regionHeight
            offsetX = m.debugCellSize / 2 - scale * regionWidth / 2 + 1
        end if
        cellX = m.debugCellStart.x + m.debugCellSize * m.activeDebugCells
        cellY = m.debugCellStart.y
        textY = cellY + m.debugCellSize + 2
        m.drawRectangleOutline(cellX, cellY, m.debugCellSize, m.debugCellSize, BGE_Colors().White)
        m.draw2d.drawScaledObject(cellX + offsetX, cellY + offsetY, scale, scale, region)
        m.drawCallsLastFrame++
        debugText = "(" + bslib_toString(fix(regionWidth)) + ", " + bslib_toString(fix(regionHeight)) + ")"
        m.drawText(text, cellX, textY, BGE_Colors().White, m.game.getFont("debugUiSmall"))
        m.drawText(debugText, cellX, textY + 12, BGE_Colors().White, m.game.getFont("debugUiSmall"))
        m.activeDebugCells++
    end sub
    return instance
end function
function BGE_Renderer(game as object, draw2d as object, cam = invalid as object)
    instance = __BGE_Renderer_builder()
    instance.new(game, draw2d, cam)
    return instance
end function'//# sourceMappingURL=./Renderer.bs.map