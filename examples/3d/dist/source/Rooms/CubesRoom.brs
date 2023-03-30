function __CubesRoom_builder()
    instance = __BaseRoom_builder()
    instance.super2_new = instance.new
    instance.new = sub(game)
        m.super2_new(game)
        m.cubeCount = 4
        m.cubes = []
        m.name = "CubesRoom"
        m.instructions = "Rotation Toggle: OK | Redraw Cubes: *"
    end sub
    instance.super2_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        m.addCubes()
    end sub
    instance.addCube = sub(x, y, z)
        cube1 = Cube(m.game)
        cube1.position.x = Rnd(x * 2) - x
        cube1.position.y = Rnd(y * 2) - y
        cube1.position.z = Rnd(z)
        cube1.rotation.x = rnd(0)
        cube1.rotation.y = rnd(0)
        cube1.rotation.z = rnd(0)
        m.game.addEntity(cube1)
        m.cubes.push(cube1)
    end sub
    instance.super2_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = sub(newRoom as object)
        m.clearCubes()
    end sub
    instance.addCubes = sub()
        for i = 0 to m.cubeCount - 1
            m.addCube(500, 400, 300)
        end for
    end sub
    instance.clearCubes = sub()
        for each cubeObj in m.cubes
            cubeObj.invalidate()
        end for
        m.cubes = []
    end sub
    instance.super2_onInput = instance.onInput
    instance.onInput = sub(input)
        if input.press and input.isButton("options")
            m.clearCubes()
            m.addCubes()
        end if
        m.super2_onInput(input)
    end sub
    return instance
end function
function CubesRoom(game)
    instance = __CubesRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./CubesRoom.bs.map