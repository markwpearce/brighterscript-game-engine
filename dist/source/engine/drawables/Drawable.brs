' @module BGE
' Abstract drawable class - all drawables extend from this
function __BGE_Drawable_builder()
    instance = {}
    ' --------------Values That Can Be Changed------------
    ' The offset of the image from the owner's position
    ' The image scale
    ' Rotation of the image
    ' This can be used to tint the image with the provided color if desired. White makes no change to the original image.
    ' Change the image alpha (transparency).
    ' Whether or not the image will be drawn.
    ' The canvas this will be drawn to (e.g. m.game.getCanvas())
    ' -------------Never To Be Manually Changed-----------------
    ' These values should never need to be manually changed.
    ' owner GameEntity
    instance.new = sub(owner as object, canvasBitmap as object, args = {} as object)
        m.name = ""
        m.offset = BGE_Math_Vector()
        m.scale = BGE_Math_Vector(1, 1, 1)
        m.rotation = BGE_Math_Vector()
        m.color = &hFFFFFF
        m.alpha = 255
        m.enabled = true
        m.drawTo = invalid
        m.transformationMatrix = BGE_Math_Matrix44()
        m.motionChecker = BGE_MotionChecker()
        m.shouldRedraw = false
        m.owner = invalid
        m.width = 0
        m.height = 0
        m.sceneObjects = {}
        m.owner = owner
        m.drawTo = canvasBitmap
        m.append(args)
    end sub
    ' Sets the canvas this will draw to
    '
    ' @param {object} [canvas] The canvas (roBitmap) this should draw to
    instance.setCanvas = sub(canvas as object)
        m.drawTo = canvas
    end sub
    instance.addToScene = sub(rendererScene as object)
    end sub
    instance.removeFromScene = sub(rendererScene as object)
        for each item in m.sceneObjects.Items()
            rendererScene.removeSceneObject(item.value)
        end for
        m.sceneObjects = {}
    end sub
    instance.computeTransformationMatrix = sub()
        currentlyMoved = m.motionChecker.check(m.offset, m.rotation, m.scale)
        if m.movedLastFrame() and not currentlyMoved
            m.motionChecker.resetMovedFlag()
            return
        end if
        if currentlyMoved
            m.motionChecker.setTransform(m.offset, m.rotation, m.scale)
            m.transformationMatrix.setFrom(BGE_Math_getTransformationMatrix(m.offset, m.rotation, m.scale))
        end if
    end sub
    instance.movedLastFrame = function(includeOwner = false as boolean) as boolean
        if includeOwner
            return m.motionChecker.movedLastFrame or m.owner.movedLastFrame()
        end if
        return m.motionChecker.movedLastFrame
    end function
    instance.update = sub()
    end sub
    instance.draw = sub(additionalRotation = invalid as object)
    end sub
    instance.onResume = sub(pausedTimeMs as integer)
    end sub
    ' Forces a redraw of this drawable on next frame
    ' By default, some drawables that need to do preprocessing (text, polygons, etc) will only redraw automatically
    ' if their dimensions or underlying values change --
    '
    instance.forceRedraw = sub()
        m.shouldRedraw = true
    end sub
    instance.isEnabled = function() as boolean
        return m.enabled and m.owner.enabled
    end function
    instance.getSize = function() as object
        return {
            width: m.width
            height: m.height
        }
    end function
    instance.getDrawnSize = function() as object
        return {
            width: m.width * m.scale.x
            height: m.height * m.scale.y
        }
    end function
    instance.getWorldPosition = function() as object
        return m.owner.transformationMatrix.multVecMatrix(m.offset)
    end function
    instance.getPretranslation = function() as object
        return BGE_Math_Vector()
    end function
    instance.getFillColorRGBA = function(ignoreColor = false as boolean) as integer
        rgba = BGE_Colors().White
        if not ignoreColor and invalid <> m.color
            rgba = (m.color << 8) + int(m.alpha)
        end if
        return rgba
    end function
    instance.getSceneObjectName = function(extraBit = "" as string) as string
        return bslib_toString(m.owner.name) + "_" + bslib_toString(m.name) + "_" + bslib_toString(extraBit)
    end function
    instance.addSceneObjectToRenderer = function(sceneObj as object, renderScene as object) as object
        sceneObj.drawable = m
        renderScene.addSceneObject(sceneObj)
        m.sceneObjects[sceneObj.id] = sceneObj
        return sceneObj
    end function
    instance.drawRegionToCanvas = sub(draw2d as object, additionalRotation = invalid as object, ignoreColor = false as boolean)
        position = m.getWorldPosition()
        x = position.x
        y = position.y
        rgba = m.getFillColorRGBA(ignoreColor)
        totalRotation = m.rotation.z
        if invalid <> additionalRotation
            totalRotation = additionalRotation.add(m.rotation).z
        end if
        m.owner.game.canvas.renderer.drawRegion(draw2d, x, y, m.scale.x, m.scale.y, - totalRotation, rgba)
    end sub
    return instance
end function
function BGE_Drawable(owner as object, canvasBitmap as object, args = {} as object)
    instance = __BGE_Drawable_builder()
    instance.new(owner, canvasBitmap, args)
    return instance
end function
function __BGE_DrawableWithOutline_builder()
    instance = __BGE_Drawable_builder()
    ' Draw an outline stroke of outlineRGBA color
    ' RGBA color for outline stroke
    instance.super0_new = instance.new
    instance.new = function(owner as object, canvasBitmap as object, args = {} as object)
        m.super0_new(owner, canvasBitmap, args)
        m.drawOutline = false
        m.outlineRGBA = BGE_Colors().White
    end function
    return instance
end function
function BGE_DrawableWithOutline(owner as object, canvasBitmap as object, args = {} as object)
    instance = __BGE_DrawableWithOutline_builder()
    instance.new(owner, canvasBitmap, args)
    return instance
end function'//# sourceMappingURL=./Drawable.bs.map