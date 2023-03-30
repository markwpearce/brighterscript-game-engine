' @module BGE
function __BGE_SpriteAnimation_builder()
    instance = {}
    ' Name of the animation
    ' Frames per second the animation should play at
    ' Array of the regions of the each cell of this animation
    ' Play mode for the sprite: loop, forward, reverse, pingpong
    '
    ' CReate a new SpriteAnimation
    '
    ' @param {string} name Name of the animation
    ' @param {object} frameList Wither an array of cell indexes, or an object {startFrame, frameCount}
    ' @param {integer} frameRate Frames per second the animation should play at
    ' @param {string} [playMode="loop"] Play mode for the sprite: loop, forward, reverse, pingpong
    instance.new = sub(name as string, frameList as object, frameRate as integer, playMode = "loop" as string)
        m.name = invalid
        m.frameRate = invalid
        m.frameList = invalid
        m.playMode = "loop"
        m.name = name
        m.frameRate = frameRate
        m.playMode = lcase(playMode)
        m.setFrameList(frameList)
    end sub
    instance.setFrameList = sub(frameList as object)
        m.frameList = []
        if invalid <> frameList.startFrame and invalid <> frameList.frameCount and frameList.startFrame >= 0 and frameList.frameCount >= 0
            for i = frameList.startFrame to frameList.startFrame + frameList.frameCount - 1
                m.frameList.push(i)
            end for
        else if 0 < frameList.count()
            m.frameList = frameList
        end if
    end sub
    return instance
end function
function BGE_SpriteAnimation(name as string, frameList as object, frameRate as integer, playMode = "loop" as string)
    instance = __BGE_SpriteAnimation_builder()
    instance.new(name, frameList, frameRate, playMode)
    return instance
end function
function __BGE_Sprite_builder()
    instance = __BGE_AnimatedImage_builder()
    ' roBitmap to pick cells from
    ' Width of each animation cell in the sprite image in pixels
    ' Height of each animation cell in the sprite image in pixels
    ' Lookup map of animation name -> SpriteAnimation object
    ' The current animation being played
    instance.super2_new = instance.new
    instance.new = function(owner as object, canvasBitmap as object, spriteSheet as object, cellWidth as integer, cellHeight as integer, args = {} as object)
        m.super2_new(owner, canvasBitmap, invalid, args)
        m.spriteSheet = invalid
        m.cellWidth = invalid
        m.cellHeight = invalid
        m.animations = {}
        m.activeAnimation = invalid
        m.spriteSheet = spriteSheet
        m.cellWidth = cellWidth
        m.cellHeight = cellHeight
        m.width = cellWidth
        m.height = cellHeight
        m.setCellRegions()
        m.append(args)
    end function
    instance.setCellRegions = sub()
        cols = cint(m.spriteSheet.getWidth() / m.cellWidth)
        rows = cint(m.spriteSheet.getHeight() / m.cellHeight)
        m.regions = []
        for row = 0 to rows - 1
            for col = 0 to cols - 1
                cellRegion = CreateObject("roRegion", m.spriteSheet, col * m.cellWidth, row * m.cellHeight, m.cellWidth, m.cellHeight)
                m.regions.push(cellRegion)
            end for
        end for
    end sub
    ' Apply a pre-translation to set the pivot point for the sprite cell
    '
    ' @param {float} x
    ' @param {float} y
    instance.applyPreTranslation = sub(x as float, y as float)
        for each region in m.regions
            region.SetPreTranslation(x, y)
        end for
    end sub
    instance.addAnimation = function(name as string, frameList as object, frameRate as integer, playMode = "loop" as string) as object
        if invalid = m.animations[name]
            spriteAnim = BGE_SpriteAnimation(name, frameList, frameRate, playMode)
            m.animations[name] = spriteAnim
            return spriteAnim
        end if
        print "addAnimation() - An animation named '" + bslib_toString(name) + "' already exists"
        return invalid
    end function
    ' Play an animation from the set of animations in this SpriteSheet
    '
    ' @param {string} animationName
    instance.playAnimation = sub(animationName as string)
        spriteAnim = m.animations[animationName]
        if invalid <> spriteAnim
            m.animationDurationMs = spriteAnim.frameList.count() * 1000.0 / spriteAnim.frameRate
        else
            print "playAnimation() - No animation named '" + bslib_toString(animationName) + "' exists"
        end if
        m.activeAnimation = spriteAnim
    end sub
    instance.super2_getCellDrawIndex = instance.getCellDrawIndex
    instance.getCellDrawIndex = function() as integer
        if invalid = m.activeAnimation
            return - 1
        end if
        frameCount = m.activeAnimation.frameList.Count()
        currentTimeMs = m.animationTimer.TotalMilliseconds()
        if currentTimeMs > m.animationDurationMs
            if "loop" = m.activeAnimation.playMode
                currentTimeMs -= m.animationDurationMs
                m.animationTimer.RemoveTime(m.animationDurationMs)
            else if "forward" = m.activeAnimation.playMode or "reverse" = m.activeAnimation.playMode
                currentTimeMs = m.animationDurationMs
            else if "pingpong" = m.activeAnimation.playMode
                if currentTimeMs > (2 * m.animationDurationMs)
                    currentTimeMs -= m.animationDurationMs
                    m.animationTimer.RemoveTime(m.animationDurationMs * 2)
                else
                    currentTimeMs = m.animationDurationMs - currentTimeMs
                end if
            end if
        end if
        tweenFunc = m.tweensReference[m.animationTween]
        if "reverse" = m.activeAnimation.playMode
            index = cint(tweenFunc(frameCount - 1, 0, currentTimeMs, m.animationDurationMs))
        else
            index = cint(tweenFunc(0, frameCount - 1, currentTimeMs, m.animationDurationMs))
        end if
        if index > frameCount - 1
            index = frameCount - 1
        else if index < 0
            index = 0
        end if
        return m.activeAnimation.frameList[index]
    end function
    return instance
end function
function BGE_Sprite(owner as object, canvasBitmap as object, spriteSheet as object, cellWidth as integer, cellHeight as integer, args = {} as object)
    instance = __BGE_Sprite_builder()
    instance.new(owner, canvasBitmap, spriteSheet, cellWidth, cellHeight, args)
    return instance
end function'//# sourceMappingURL=./Sprite.bs.map