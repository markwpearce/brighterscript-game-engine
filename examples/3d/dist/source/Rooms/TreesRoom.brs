function __TreesRoom_builder()
    instance = __BaseRoom_builder()
    instance.super2_new = instance.new
    instance.new = sub(game)
        m.super2_new(game)
        m.treeRowCount = 4
        m.trees = []
        m.name = "TreesRoom"
        m.instructions = "Rotation Toggle: OK"
    end sub
    instance.super2_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        for i = 0 to m.treeRowCount - 1
            for j = 0 to m.treeRowCount - 1
                m.addTree(- 400 + 250 * i, 0, - 500 * j * - 1)
            end for
        end for
    end sub
    instance.addTree = sub(x, y, z)
        tree = LineTree(m.game)
        tree.position.x = x
        tree.position.y = y
        tree.position.z = z
        m.game.addEntity(tree)
        m.trees.push(tree)
    end sub
    instance.super2_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = sub(newRoom as object)
        for each obj in m.trees
            obj.invalidate()
        end for
        m.trees = []
    end sub
    return instance
end function
function TreesRoom(game)
    instance = __TreesRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./TreesRoom.bs.map