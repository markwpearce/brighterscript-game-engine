function __PolyRoom_builder()
    instance = __BaseRoom_builder()
    instance.super2_new = instance.new
    instance.new = sub(game)
        m.super2_new(game)
        m.polyCount = 10
        m.polys = []
        m.name = "PolyRoom"
        m.instructions = "Rotation Toggle: OK"
    end sub
    instance.super2_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.addPolys()
    end sub
    instance.addPoly = sub(x, y, z)
        polyItem = Poly(m.game)
        m.game.addEntity(polyItem)
        m.polys.push(polyItem)
    end sub
    instance.super2_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = sub(newRoom as object)
        m.clearPolys()
    end sub
    instance.addPolys = sub()
        for i = 0 to m.polyCount - 1
            m.addPoly(500, 400, 300)
        end for
    end sub
    instance.clearPolys = sub()
        for each obj in m.polys
            obj.invalidate()
        end for
        m.polys = []
    end sub
    instance.super2_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.press and input.isButton("options")
            m.clearPolys()
            m.addPolys()
        end if
        m.super2_onInput(input)
    end sub
    return instance
end function
function PolyRoom(game)
    instance = __PolyRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./PolyRoom.bs.map