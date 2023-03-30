function __ImagesRoom_builder()
    instance = __BaseRoom_builder()
    instance.super2_new = instance.new
    instance.new = sub(game)
        m.super2_new(game)
        m.imgCubes = []
        m.name = "ImagesRoom"
        m.instructions = "Rotation Toggle: OK | Change Axis: *"
    end sub
    instance.super2_onCreate = instance.onCreate
    instance.onCreate = sub(args)
        numCubes = 0
        if numCubes = 0
            m.addImageCube(0, 0, 0, BGE_Math_Pi(), 400)
        else
            cubeSize = 400 / numCubes
            cubeSpace = cubeSize * 2
            startX = 0 - (((numCubes + 1) / 2) * cubeSpace)
            for i = 0 to numCubes
                m.addImageCube(startX + cubeSpace * i, 100, 0, BGE_Math_HalfPi() * i, cubeSize)
            end for
        end if
    end sub
    instance.addImageCube = sub(x, y, z, yTheta, size)
        imgCube = ImageCube(m.game)
        imgCube.position.x = x
        imgCube.position.y = y
        imgCube.position.z = z
        imgCube.rotation.y = yTheta
        imgCube.rotation.z = BGE_Math_PI() / 6
        imgCube.size = size
        m.game.addEntity(imgCube)
        m.imgCubes.push(imgCube)
    end sub
    instance.super2_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = sub(newRoom as object)
        for each obj in m.imgCubes
            obj.invalidate()
        end for
        m.imgCubes = []
    end sub
    return instance
end function
function ImagesRoom(game)
    instance = __ImagesRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./ImagesRoom.bs.map