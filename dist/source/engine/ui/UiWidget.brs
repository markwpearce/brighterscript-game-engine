' Base Abstract class for all UI Elements
function __BGE_UI_UiWidget_builder()
    instance = __BGE_GameEntity_builder()
    ' If position = "custom", then m.customX is horizontal position of this element from the parent position
    ' and m.customY is the vertical position of this element from the parent position (positive is down)
    ' If customPosition is false, this dictates where horizontally in the container this element should go. Can be: "left", "center" or "right"
    ' as HorizAlignment = HorizAlignment.left
    ' If customPosition is false, this dictates where vertically in the container this element should go. Can be: "top", "center" or "bottom"
    'as VertAlignment = VertAlignment.top
    ' Width of the element
    ' Height of the element
    instance.super0_new = instance.new
    instance.new = sub(game as object)
        m.super0_new(game)
        m.customPosition = false
        m.customX = 0
        m.customY = 0
        m.horizAlign = "left"
        m.vertAlign = "top"
        m.width = 0
        m.height = 0
        m.canvas = invalid
        m.padding = invalid
        m.margin = invalid
        m.padding = BGE_UI_Offset()
        m.margin = BGE_UI_Offset()
        m.setCanvas(game.getCanvas())
    end sub
    ' Function to get the value of the UI element
    '
    ' @return {dynamic} - the value of this element
    instance.getValue = function() as dynamic
        return invalid
    end function
    ' Method called each frame to draw any images of this entity
    '
    ' @param {object} [parent=invalid] - the parent of this Ui Element - will be an object with {x, y, width, height}
    instance.draw = sub(parent = invalid as object)
    end sub
    ' Set the canvas this UIWidgetDraws to
    '
    ' @param {object} [canvas=invalid] The canvas this should draw to - if invalid, then will draw to the game canvas
    instance.setCanvas = sub(canvas = invalid as object)
        if canvas <> invalid
            m.canvas = canvas
        else
            m.canvas = m.game.getCanvas()
        end if
    end sub
    ' Method called each frame to reposition
    '
    ' @param {UiWidget} [parent=invalid] - the parent of this Ui Element - will be an object with {x, y, width, height}
    instance.repositionBasedOnParent = sub(parent = invalid as object)
        m.position = m.getWorldPosition(parent)
    end sub
    ' Method called each frame to draw any images of this entity
    '
    ' @param {UiWidget} [parent=invalid] - the parent of this Ui Element
    ' @return {BGE.Math.Vector} - x,y coordinates of where this widget should be positioned
    instance.getWorldPosition = function(parent = invalid as object) as object
        drawPosition = BGE_Math_Vector()
        parentPadding = BGE_UI_Offset()
        if invalid <> parent
            drawPosition.x += parent.position.x
            drawPosition.y += parent.position.y
            if invalid <> parent.padding
                parentPadding = parent.padding
            end if
        else
            parent = BGE_Math_Vector()
        end if
        if m.customPosition or invalid = parent.width or invalid = parent.height
            drawPosition.x += m.customX
            drawPosition.y += m.customY
        else
            if m.horizAlign = "left" 'HorizAlignment.left
                drawPosition.x += m.margin.left + parentPadding.left
            else if m.horizAlign = "center" 'HorizAlignment.center
                drawPosition.x += parent.width / 2 - m.width / 2
            else if m.horizAlign = "right" 'HorizAlignment.right
                drawPosition.x += parent.width - m.width - parentPadding.right - m.margin.right
            end if
            if m.vertAlign = "top" 'VertAlignment.top
                drawPosition.y += m.margin.top + parentPadding.top
            else if m.vertAlign = "center" 'VertAlignment.center
                drawPosition.y += parent.height / 2 - m.height / 2
            else if m.vertAlign = "bottom" 'VertAlignment.bottom
                drawPosition.y += parent.height - m.height - m.margin.bottom - parentPadding.bottom
            end if
        end if
        return drawPosition
    end function
    return instance
end function
function BGE_UI_UiWidget(game as object)
    instance = __BGE_UI_UiWidget_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./UiWidget.bs.map