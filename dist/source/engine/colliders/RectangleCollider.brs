' @module BGE
' Collider with the shape of a rectangle with top left at (offset.x, offset.y), with given width and height
function __BGE_RectangleCollider_builder()
    instance = __BGE_Collider_builder()
    ' Create a new RectangleCollider
    '
    ' @param {string} colliderName - name of this collider
    ' @param {object} [args={}] - additional properties (e.g {width: 10, height: 20})
    instance.super0_new = instance.new
    instance.new = sub(colliderName as string, args = {} as object)
        m.super0_new(colliderName, args)
        m.width = 0.0
        m.height = 0.0
        m.colliderType = "rectangle"
        m.append(args)
    end sub
    ' Refreshes the collider
    '
    instance.super0_refreshColliderRegion = instance.refreshColliderRegion
    instance.refreshColliderRegion = sub()
        region = m.compositorObject.GetRegion()
        region.SetCollisionType(1)
        region.SetCollisionRectangle(m.offset.x, - m.offset.y, m.width, m.height)
    end sub
    ' Draws the rectangle outline around the collider
    instance.super0_debugDraw = instance.debugDraw
    instance.debugDraw = sub(renderObj as object, position as object, color = &hFF0000FF as integer, addName = false as boolean, font = invalid)
        offsetPosition = renderObj.worldPointToCanvasPoint(position.add(m.offset))
        renderObj.DrawRectangleOutline(offsetPosition.x, offsetPosition.y, m.width, m.height, color)
        if addName
            textOffset = 10
            renderObj.drawText(m.name, offsetPosition.x + textOffset, offsetPosition.y + textOffset, color, font)
        end if
    end sub
    return instance
end function
function BGE_RectangleCollider(colliderName as string, args = {} as object)
    instance = __BGE_RectangleCollider_builder()
    instance.new(colliderName, args)
    return instance
end function'//# sourceMappingURL=./RectangleCollider.bs.map