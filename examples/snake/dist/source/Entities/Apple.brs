function __Apple_builder()
    instance = __GridEntity_builder()
    instance.super1_new = instance.new
    instance.new = function(game) as void
        m.super1_new(game)
        m.color = BGE_Colors().Red
        m.name = "apple"
    end function
    instance.super1_onCreate = instance.onCreate
    instance.onCreate = function(args)
        m.gridX = args.gridX
        m.gridY = args.gridY
        m.grid = args.grid
        m.position.x = m.grid
        m.refreshPosition()
        m.addRectangleCollider("apple", m.grid, m.grid, 0, 0)
    end function
    instance.super1_onDrawBegin = instance.onDrawBegin
    instance.onDrawBegin = function(renderObj as object)
        m.drawRectangleOnGrid(renderObj, m.gridX, m.gridY, m.color)
    end function
    return instance
end function
function Apple(game)
    instance = __Apple_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./Apple.bs.map