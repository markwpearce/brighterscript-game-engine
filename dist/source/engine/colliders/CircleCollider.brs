' @module BGE
' Collider with the shape of a circle centered at (offset.x, offset.y), with given radius
function __BGE_CircleCollider_builder()
    instance = __BGE_Collider_builder()
    ' Radius of the collider
    ' Create a new CircleCollider
    '
    ' @param {string} colliderName - name of this collider
    ' @param {object} [args={}] - additional properties (e.g {radius: 10})
    instance.super0_new = instance.new
    instance.new = sub(colliderName as string, args = {} as object)
        m.super0_new(colliderName, args)
        m.radius = 0
        m.colliderType = "circle"
        m.append(args)
    end sub
    ' Refreshes the collider
    '
    instance.super0_refreshColliderRegion = instance.refreshColliderRegion
    instance.refreshColliderRegion = sub()
        region = m.compositorObject.GetRegion()
        region.SetCollisionType(2)
        region.SetCollisionCircle(m.offset.x, m.offset.y, m.radius)
    end sub
    ' Draws the circle outline around the collider
    instance.super0_debugDraw = instance.debugDraw
    instance.debugDraw = sub(renderObj as object, position as object, color = &hFF0000FF as integer, addName = false as boolean, font = invalid)
        ' This function is slow as I'm making draw calls for every section of the line.
        ' It's for debugging purposes only!
        offsetPosition = renderObj.worldPointToCanvasPoint(position.subtract(m.offset))
        renderObj.DrawCircleOutline(16, offsetPosition.x, offsetPosition.y, m.radius, color)
        if addName
            textOffset = 10
            renderObj.drawText(m.name, offsetPosition.x + textOffset, offsetPosition.y - textOffset, color, font)
        end if
    end sub
    return instance
end function
function BGE_CircleCollider(colliderName as string, args = {} as object)
    instance = __BGE_CircleCollider_builder()
    instance.new(colliderName, args)
    return instance
end function'//# sourceMappingURL=./CircleCollider.bs.map