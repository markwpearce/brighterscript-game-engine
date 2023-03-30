' @module BGE
function __BGE_AnimatedImage_builder()
    instance = __BGE_Image_builder()
    ' -------------Only To Be Changed For Animation---------------
    ' The following values should only be changed if the image is a spritesheet that needs to be animated.
    ' The spritesheet can have any assortment of multiple columns and rows.
    ' The current index of image - this would not normally be changed manually, but if you wanted to stop on a specific image in the spritesheet this could be set.
    ' The time in milliseconds for a single cycle through the animation to play.
    ' The name of the tween to use for choosing the next image
    ' -------------Never To Be Manually Changed-----------------
    ' These values should never need to be manually changed.
    instance.super1_new = instance.new
    instance.new = function(owner as object, canvasBitmap as object, regions as object, args = {} as object)
        m.super1_new(owner, canvasBitmap, invalid, args)
        m.index = 0
        m.animationDurationMs = 0
        m.animationTween = "LinearTween"
        m.regions = invalid
        m.animationTimer = BGE_GameTimer()
        m.tweensReference = BGE_Tweens_GetTweens()
        m.sceneObjectAnimId = ""
        m.regions = regions
        m.update()
        m.append(args)
    end function
    instance.super1_update = instance.update
    instance.update = sub()
        if m.animationDurationMs > 0 and not m.owner.game.isPaused()
            m.index = m.getCellDrawIndex()
        end if
        if m.regions <> invalid and m.index >= 0 and m.index < m.regions.Count()
            m.region = m.regions[m.index]
            m.width = m.region.getWidth()
            m.height = m.region.getHeight()
            if "" <> m.sceneObjectAnimId and invalid <> m.sceneObjects[m.sceneObjectAnimId]
                sceneObj = m.sceneObjects[m.sceneObjectAnimId]
                sceneObj.frameNumber = m.index
            end if
        end if
    end sub
    instance.super1_draw = instance.draw
    instance.draw = function(additionalRotation = invalid as object)
        if m.enabled
            totalRotation = (function(__bsCondition, additionalRotation, m)
                    if __bsCondition then
                        return m.rotation
                    else
                        return m.rotation.add(additionalRotation)
                    end if
                end function)(additionalRotation = invalid, additionalRotation, m)
            m.drawRegionToCanvas(m.region, totalRotation)
        end if
    end function
    instance.getCellDrawIndex = function() as integer
        frame_count = m.regions.Count()
        currentTimeMs = m.animationTimer.TotalMilliseconds()
        if currentTimeMs > m.animationDurationMs
            currentTimeMs -= m.animationDurationMs
            m.animationTimer.RemoveTime(m.animationDurationMs)
        end if
        index = m.tweensReference[m.animationTween](0, frame_count, currentTimeMs, m.animationDurationMs)
        if index > frame_count - 1
            index = frame_count - 1
        else if m.index < 0
            index = 0
        end if
        return index
    end function
    instance.super1_onResume = instance.onResume
    instance.onResume = function(pausedTime as integer)
        m.animationTimer.RemoveTime(pausedTime)
    end function
    instance.super1_addToScene = instance.addToScene
    instance.addToScene = sub(renderer as object)
        sceneObj = m.addSceneObjectToRenderer(BGE_SceneObjectImage(m.getSceneObjectName("animatedImage"), m), renderer)
        m.sceneObjectAnimId = sceneObj.id
    end sub
    return instance
end function
function BGE_AnimatedImage(owner as object, canvasBitmap as object, regions as object, args = {} as object)
    instance = __BGE_AnimatedImage_builder()
    instance.new(owner, canvasBitmap, regions, args)
    return instance
end function'//# sourceMappingURL=./AnimatedImage.bs.map