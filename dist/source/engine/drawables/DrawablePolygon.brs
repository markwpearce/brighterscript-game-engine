' @module BGE
function __BGE_DrawablePolygon_builder()
    instance = __BGE_DrawableWithOutline_builder()
    ' the set of points defining a convex polygon
    ' The number of frames before the polygon is completely finished
    ' Draw mode for the polygon, bitmask of:
    '  1 wireframe (just edges of triangles)
    '  2 fill (render with rectangles)
    '  4 rays (render with rays)
    instance.super1_new = instance.new
    instance.new = sub(owner as object, canvasBitmap as object, points = [] as object, args = {} as object)
        m.super1_new(owner, canvasBitmap, args)
        m.points = []
        m.drawLevels = 2
        m.drawModeMask = 3
        m.tempCanvas = invalid
        m.lastPoints = []
        m.triangles = []
        m.hulledPoints = []
        m.lastDrawMode = 3
        m.currentDrawLevel = 0
        m.minimumFrameRateTarget = 10
        m.maxDrawLevels = 16
        m.points = BGE_cloneArray(points)
        m.append(args)
    end sub
    instance.super1_addToScene = instance.addToScene
    instance.addToScene = sub(renderer as object)
        m.addSceneObjectToRenderer(BGE_SceneObjectPolygon(m.getSceneObjectName("polygon"), m), renderer)
    end sub
    instance.super1_draw = instance.draw
    instance.draw = sub(additionalRotation = invalid as object)
        if m.drawLevels < 1
            m.drawLevels = 1
        end if
        if not m.enabled or invalid = m.points
            return
        end if
        m.automaticallyAdjustDrawLevels()
        if BGE_pointArraysEqual(m.points, m.lastPoints) and not m.shouldRedraw and m.lastDrawMode = m.drawModeMask
            if m.currentDrawLevel < m.drawLevels
                m.drawNextLevelOfPolygons()
            end if
            m.drawRegionToCanvas(m.tempCanvas, additionalRotation)
            return
        end if
        m.lastDrawMode = m.drawModeMask
        m.lastPoints = BGE_cloneArray(m.points)
        m.hulledPoints = BGE_QuickHull_QuickHull(m.points)
        m.triangles = BGE_QuickHull_getTrianglesFromPoints(m.hulledPoints, false)
        widthAndOffset = BGE_QuickHull_getMaxWidthAndHorizontalOffset(m.hulledPoints)
        heightAndOffset = BGE_QuickHull_getMaxHeightAndVerticalOffset(m.hulledPoints)
        m.width = widthAndOffset.width
        m.height = heightAndOffset.height
        m.offset.x = widthAndOffset.offset
        m.offset.y = heightAndOffset.offset
        m.lastWidth = m.width
        m.lastHeight = m.height
        m.currentDrawLevel = 0
        m.tempCanvas = CreateObject("roBitmap", {
            width: m.width
            height: m.height
            AlphaEnable: true
        })
        m.drawNextLevelOfPolygons()
        m.drawRegionToCanvas(m.tempCanvas, additionalRotation)
        m.shouldRedraw = false
    end sub
    ' Change the draw levels based on how long the last frame took to render
    ' If the last frame took longer than expected, increase the draw levels
    ' If the last frame took 1/2 as long as expected, decrease the draw levels
    instance.automaticallyAdjustDrawLevels = sub()
        frameExpectedPerTime = (m.owner.game.getDeltaTime() * m.minimumFrameRateTarget)
        if m.drawLevels < m.maxDrawLevels and frameExpectedPerTime > 1
            m.drawLevels *= 2
            if m.drawLevels < m.maxDrawLevels and frameExpectedPerTime > 2
                m.drawLevels *= 2
            end if
        else if frameExpectedPerTime < 1 and m.drawLevels > 4
            m.drawLevels /= 2
            if m.currentDrawLevel > m.drawLevels
                m.currentDrawLevel = 0
            end if
        end if
    end sub
    instance.drawNextLevelOfPolygons = sub()
        if m.drawModeMask and 2
            m.fillPolygonWithRectangles(m.hulledPoints, m.drawLevels, m.currentDrawLevel)
        end if
        for each tri in m.triangles
            if m.drawModeMask and 4
                m.fillTriangleWithRays(tri, m.drawLevels, m.currentDrawLevel)
            end if
            if m.drawModeMask and 1
                m.drawTriangleEdges(tri)
                if m.drawModeMask = 1
                    m.currentDrawLevel = m.drawLevels
                end if
            end if
        end for
        m.currentDrawLevel++
    end sub
    ' Draw a filled triangle with rays from the apex ato the shortest side of the triangle
    '
    ' @param {object} [tri=[]] an array with 3 {x,y} points
    ' @param {integer} [levelOfDetail=1] LOD of the triangle - how filled in it should be
    ' @param {integer} [levelOffset=0] which step of teh fill should be done (0-levelOfDetail)
    instance.fillTriangleWithRays = sub(tri = [] as object, levelOfDetail = 1 as integer, levelOffset = 0 as integer)
        if invalid = m.tempCanvas
            return
        end if
        len0 = BGE_Math_TotalDistance(tri[1], tri[2])
        len1 = BGE_Math_TotalDistance(tri[0], tri[2])
        len2 = BGE_Math_TotalDistance(tri[0], tri[1])
        apexIndex = 0
        shortLength = 0
        if len0 <= len1 and len0 <= len2
            apexIndex = 0
            shortLength = len0
        else if len1 <= len0 and len1 < len0
            apexIndex = 1
            shortLength = len1
        else ' if len2 < len0 and len2 < len1
            apexIndex = 2
            shortLength = len2
        end if
        apex = tri[apexIndex]
        startP = tri[(apexIndex + 1) mod 3]
        endP = tri[(apexIndex + 2) mod 3]
        if shortLength > 0
            rgba = m.getFillColorRGBA()
            for i = levelOffset to shortLength step levelOfDetail
                x = BGE_Tweens_LinearTween(startP.x, endP.x, i, shortLength)
                y = BGE_Tweens_LinearTween(startP.y, endP.y, i, shortLength)
                m.tempCanvas.drawLine(apex.x - m.offset.x, apex.y - m.offset.y, x - m.offset.x, y - m.offset.y, rgba)
            end for
        end if
    end sub
    ' Draw a triangle edges - uses outlineRGBA if drawOutline is true
    '
    ' @param {object} [tri=[]] an array with 3 {x,y} points
    instance.drawTriangleEdges = sub(tri as object)
        if invalid = m.tempCanvas or tri.count() <> 3
            return
        end if
        rgba = m.getFillColorRGBA()
        outlineColor = rgba
        if m.drawOutline
            outlineColor = m.outlineRGBA
        end if
        p1 = tri[0]
        p2 = tri[1]
        p3 = tri[2]
        m.tempCanvas.drawLine(p1.x - m.offset.x, p1.y - m.offset.y, p2.x - m.offset.x, p2.y - m.offset.y, outlineColor)
        m.tempCanvas.drawLine(p1.x - m.offset.x, p1.y - m.offset.y, p3.x - m.offset.x, p3.y - m.offset.y, outlineColor)
        m.tempCanvas.drawLine(p2.x - m.offset.x, p2.y - m.offset.y, p3.x - m.offset.x, p3.y - m.offset.y, outlineColor)
    end sub
    ' Draw a filled convex polygon with rectangles
    '
    ' @param {object} [points=[]] an array of {x,y} points
    ' @param {integer} [levelOfDetail=1] How many steps it should take to get a crisp polygon
    ' @param {integer} [levelOffset=0] which step of the fill should be done (0-levelOfDetail)
    instance.fillPolygonWithRectangles = sub(points = [] as object, levelOfDetail = 1 as integer, levelOffset = 0 as integer)
        if invalid = m.tempCanvas or points.count() < 3
            return
        end if
        nodeX = []
        nPoints = points.count()
        x1 = m.offset.x
        y1 = m.offset.y
        maxX = m.width + m.offset.x
        maxY = m.height + m.offset.y
        rgba = m.getFillColorRGBA()
        precision = (levelOfDetail - levelOffset) * 1.0
        if precision <= 1
            return
        end if
        for pixelY = y1 to maxY step precision
            nodes = 0
            j = nPoints - 1
            for i = 0 to (nPoints - 1)
                if (points[i].y < pixelY and points[j].y >= pixelY) or (points[j].y < pixelY and points[i].y >= pixelY)
                    if (points[j].y - points[i].y) = 0
                        nodeX[nodes] = points[i].x
                    else
                        nodeX[nodes] = points[i].x + (pixelY - points[i].y) / (points[j].y - points[i].y) * (points[j].x - points[i].x)
                    end if
                    nodes++
                end if
                j = i
            end for
            nodeX.sort()
            for i = 0 to (nodes - 1) step precision
                if nodeX[i] > maxX
                    exit for
                end if
                pixelX = nodeX[i]
                if precision > 1 and i < nodes - precision
                    if nodeX[i + precision] < pixelX
                        pixelX = nodeX[i + precision]
                    end if
                end if
                rectX = BGE_Math_Max(0, x1 + pixelX - 2 * m.offset.x)
                rectY = BGE_Math_Max(0, y1 + pixelY - 2 * m.offset.y - precision / 2)
                endX = BGE_Math_Min(cint(i + precision / 2 + 1), nodes - 1)
                width = nodeX[endX] - pixelX
                m.tempCanvas.DrawRect(rectX, rectY, width, precision, rgba)
            end for
        end for
    end sub
    return instance
end function
function BGE_DrawablePolygon(owner as object, canvasBitmap as object, points = [] as object, args = {} as object)
    instance = __BGE_DrawablePolygon_builder()
    instance.new(owner, canvasBitmap, points, args)
    return instance
end function'//# sourceMappingURL=./DrawablePolygon.bs.map