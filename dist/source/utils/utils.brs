' @module BGE
' TODO: figure this out... is useful for sprites with different size frames
function BGE_TexturePacker_GetRegions(atlas as dynamic, bitmap as object) as object
    if type(atlas) = "String" or type(atlas) = "roString"
        atlas = ParseJson(atlas)
    end if
    regions = {}
    for each key in atlas.frames
        item = atlas.frames[key]
        region = CreateObject("roRegion", bitmap, item.frame.x, item.frame.y, item.frame.w, item.frame.h)
        if invalid <> item and invalid <> item.pivot
            translation_x = item.spriteSourceSize.x - item.sourceSize.w * item.pivot.x
            translation_y = item.spriteSourceSize.y - item.sourceSize.h * item.pivot.y
            region.SetPretranslation(translation_x, translation_y)
        end if
        regions[key] = region
    end for
    return regions
end function

' -----------------------Utilities Used By Game Engine---------------------------
function BGE_ArrayInsert(array as object, index as integer, value as dynamic) as object
    for i = array.Count() to index + 1 step - 1
        array[i] = array[i - 1]
    end for
    array[index] = value
    return array
end function

sub BGE_DrawCircleOutline(draw2d as object, line_count as integer, x as float, y as float, radius as float, rgba as integer)
    if draw2d = invalid
        return
    end if
    previous_x = radius
    previous_y = 0
    for i = 0 to line_count
        degrees = 360 * (i / line_count)
        current_x = cos(degrees * .01745329) * radius
        current_y = sin(degrees * .01745329) * radius
        draw2d.DrawLine(x + previous_x, y + previous_y, x + current_x, y + current_y, rgba)
        previous_x = current_x
        previous_y = current_y
    end for
end sub

sub BGE_DrawRectangleOutline(draw2d as object, x as float, y as float, width as float, height as float, rgba as integer)
    if draw2d = invalid
        return
    end if
    draw2d.DrawLine(x, y, x + width, y, rgba)
    draw2d.DrawLine(x, y, x, y + height, rgba)
    draw2d.DrawLine(x + width, y, x + width, y + height, rgba)
    draw2d.DrawLine(x, y + height, x + width, y + height, rgba)
end sub

function BGE_isValidEntity(entity as object) as boolean
    return invalid <> entity and entity.id <> invalid
end function

' 	' -------Button Code Reference--------
' 	' Button  Pressed Released  Held
'   ' ------------------------------
' 	' Back         0      100   1000
' 	' Up           2      102   1002
' 	' Down         3      103   1003
' 	' Left         4      104   1004
' 	' Right        5      105   1005
' 	' OK           6      106   1006
' 	' Replay       7      107   1007
' 	' Rewind       8      108   1008
' 	' FastForward  9      109   1009
' 	' Options     10      110   1010
' 	' Play        13      113   1013
function BGE_buttonNameFromCode(buttonCode as integer) as string
    buttonId = buttonCode mod 100
    possibleButtonNames = [
        "back"
        "unknown"
        "up"
        "down"
        "left"
        "right"
        "OK"
        "replay"
        "rewind"
        "fastforward"
        "options"
        "audioguide"
        "unknown"
        "play"
    ]
    if buttonId < possibleButtonNames.count()
        return possibleButtonNames[buttonId]
    end if
    return invalid
end function

' Clone an array (shallow)
'
' @param {object} [original=[]] the original array to be clones
' @return {object} A shallow copy of the original array
function BGE_cloneArray(original = [] as object) as object
    retVal = []
    for each item in original
        retVal.push(item)
    end for
    return retVal
end function

' Check if two arrays of points are teh same - that is, if each point, in order has same x and y values
'
' @param {object} [a=[]] the first array
' @param {object} [b=[]] the second array
' @return {boolean} true if both arrays have same number of points and x and y values are the same for each point
function BGE_pointArraysEqual(a = [] as object, b = [] as object) as boolean
    if a.count() <> b.count()
        return false
    end if
    same = true
    for i = 0 to a.count() - 1
        same = a[i].x = b[i].x and a[i].y = b[i].y
        if not same
            exit for
        end if
    end for
    return same
end function

function BGE_isTrue(value) as boolean
    return rodash_isBoolean(value) and value = true
end function'//# sourceMappingURL=./utils.bs.map