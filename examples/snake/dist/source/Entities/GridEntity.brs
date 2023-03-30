function __GridEntity_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game) as void
        m.super0_new(game)
        m.grid = 20
        m.gridPadding = 4
        m.gridX = 0
        m.gridY = 0
    end function
    instance.refreshPosition = function() as void
        m.position.x = m.gridX * m.grid
        m.position.y = m.gridY * m.grid
    end function
    instance.drawRectangleOnGrid = function(renderObj as object, gridX, gridY, color)
        x = cint(gridX * m.grid + m.gridPadding / 2)
        y = cint(gridY * m.grid + m.gridPadding / 2)
        canvasPos = renderObj.worldPointToCanvasPoint(BGE_Math_Vector(x, y))
        sideLength = cint(m.grid - m.gridPadding / 2)
        renderObj.DrawRectangle(canvasPos.x, canvasPos.y, sideLength, sideLength, color)
    end function
    return instance
end function
function GridEntity(game)
    instance = __GridEntity_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./GridEntity.bs.map