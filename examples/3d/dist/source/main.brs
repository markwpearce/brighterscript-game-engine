sub main()
    'test()
    'return
    game = BGE_Game(1280, 720, true) ' This initializes the game engine
    game.setCamera(BGE_Camera3d())
    game.loadBitmap("roku", "pkg:/sprites/roku-logo-purple.png")
    cubes_room = CubesRoom(game)
    game.defineRoom(cubes_room)
    trees_room = TreesRoom(game)
    game.defineRoom(trees_room)
    images_room = ImagesRoom(game)
    game.defineRoom(images_room)
    poly_room = PolyRoom(game)
    game.defineRoom(poly_room)
    game.changeRoom(getRoomNames()[0])
    game.getDebugUI().addChild(BGE_Debug_FpsDisplay(game))
    game.getDebugUI().addChild(BGE_Debug_InputDisplay(game))
    game.getDebugUI().addChild(BGE_Debug_MemoryDisplay(game))
    game.getDebugUI().addChild(BGE_Debug_GarbageCollectorDisplay(game))
    ' game.debugDrawColliders(true)
    ' game.debugDrawEntityDetails(true)
    'game.debugShowUi(true)
    'game.canvas.renderer.drawDebugCells = true
    game.Play()
    ' vscode_rale_tracker_entry
end sub

function getRoomNames()
    return [
        "PolyRoom"
        "ImagesRoom"
        "TreesRoom"
        "CubesRoom"
    ]
end function

sub goToNextRoom(currentRoom as object, direction as integer)
    currentIndex = 0
    i = 0
    roomNames = getRoomNames()
    for each name in roomNames
        if currentRoom.name = name
            currentIndex = i
            exit for
        end if
        i++
    end for
    nextIndex = currentIndex + direction
    if nextIndex >= roomNames.count()
        nextIndex = 0
    else if nextIndex < 0
        nextIndex = roomNames.count() - 1
    end if
    currentRoom.game.changeRoom(roomNames[nextIndex])
    currentRoom.game.canvas.renderer.camera.useDefaultCameraTarget()
    currentRoom.game.canvas.renderer.camera.position.y = 30
end sub

sub test()
    game = BGE_Game(1280, 720, true) ' This initializes the game engine
    game.canvas.renderer.drawDebugCells = true
    game.loadBitmap("roku", "pkg:/sprites/roku-logo-purple.png")
    ' scratchBmp = CreateObject("roBitmap", {width: game.canvas.getWidth(), height: game.canvas.getHeight(), AlphaEnable: true})
    ' scratchRegion = CreateObject("roRegion", scratchBmp, 0, 0, 200, 200)
    'rokuBitmap = game.getBitmap("roku")
    'game.canvas.renderer.drawObjectTo(scratchRegion, 0, 0, rokuBitmap)
    'game.canvas.renderer.drawObject(0, 0, scratchRegion)
    'game.screen.swapBuffers()
    'sleep(2000)
    testRender2(game)
    return
    totalTimer = CreateObject("roTimeSpan")
    for i = 0 to 1000
        testRender2(game)
        'sleep(10)
    end for
    ? totalTimer.totalMilliseconds()
end sub

sub testRender(game)
    rokuBitmap = game.getBitmap("roku")
    rokuBitmapRegion = CreateObject("roRegion", rokuBitmap, 0, 0, rokuBitmap.getWidth(), rokuBitmap.getHeight())
    'rokuBitmapRegion.setPretranslation(50, 100)
    ' game.canvas.clear(0)
    srcPoints = [
        BGE_Math_Vector(0, 0)
        BGE_Math_Vector(0, 400)
        BGE_Math_Vector(400, 400)
        'new BGE.Math.Vector(0, 0),
        'new BGE.Math.Vector(400, 400)
        'new BGE.Math.Vector(400, 000),
        'new BGE.Math.Vector(200, 000),
        'new BGE.Math.Vector(100, 200)
        'new BGE.Math.Vector(300, 200),
        'new BGE.Math.Vector(400, 0),
        'new BGE.Math.Vector(200, 200)
        'new BGE.Math.Vector(400, 400),
    ]
    destPoints = [
        ' new BGE.Math.Vector(900, 400),
        ' new BGE.Math.Vector(700, 350),
        ' new BGE.Math.Vector(1000, 500),
        ' new BGE.Math.Vector(900, 400),
        ' new BGE.Math.Vector(700, 410),
        ' new BGE.Math.Vector(800, 600),
        ' new BGE.Math.Vector(850, 420),
        ' new BGE.Math.Vector(900, 350),
        ' new BGE.Math.Vector(550, 500),
        BGE_Math_Vector(600, 500)
        BGE_Math_Vector(800, 550)
        BGE_Math_Vector(810, 450)
        ' new BGE.Math.Vector(900, 700),
        ' new BGE.Math.Vector(870, 300),
        ' new BGE.Math.Vector(700, 320),
        ' new BGE.Math.Vector(950, 600),
        ' new BGE.Math.Vector(900, 300),
        ' new BGE.Math.Vector(500, 500),
    ]
    destPoints2 = [
        ' new BGE.Math.Vector(900, 400),
        ' new BGE.Math.Vector(700, 350),
        ' new BGE.Math.Vector(1000, 500),
        ' new BGE.Math.Vector(900, 400),
        ' new BGE.Math.Vector(700, 410),
        ' new BGE.Math.Vector(800, 600),
        ' new BGE.Math.Vector(850, 420),
        ' new BGE.Math.Vector(900, 350),
        ' new BGE.Math.Vector(550, 500),
        BGE_Math_Vector(800, 500)
        BGE_Math_Vector(1000, 550)
        BGE_Math_Vector(1010, 450)
        ' new BGE.Math.Vector(900, 700),
        ' new BGE.Math.Vector(870, 300),
        ' new BGE.Math.Vector(700, 320),
        ' new BGE.Math.Vector(950, 600),
        ' new BGE.Math.Vector(900, 300),
        ' new BGE.Math.Vector(500, 500),
    ]
    srcOffSetX = 100
    srcOffSetY = 300
    game.canvas.renderer.drawObject(srcOffSetX, srcOffSetY, rokuBitmapRegion)
    game.canvas.renderer.drawSquare(srcPoints[0].x + srcOffSetX, srcPoints[0].y + srcOffSetY, 4, BGE_Colors().Red)
    game.canvas.renderer.drawSquare(srcPoints[1].x + srcOffSetX, srcPoints[1].y + srcOffSetY, 4, BGE_Colors().Green)
    game.canvas.renderer.drawSquare(srcPoints[2].x + srcOffSetX, srcPoints[2].y + srcOffSetY, 4, BGE_Colors().Blue)
    rokuImageRegionId = BGE_RegionWithId(rokuBitmapRegion, "rokuBitmap")
    game.canvas.renderer.drawBitmapTriangleTo(game.canvas.renderer.draw2d, rokuImageRegionId, srcPoints, destPoints)
    game.canvas.renderer.drawDebugCells = true
    game.canvas.renderer.drawBitmapTriangleTo(game.canvas.renderer.draw2d, rokuImageRegionId, srcPoints, destPoints2)
    ? "Draw Calls: "; game.canvas.renderer.drawCallsLastFrame
    ' triangle = game.canvas.renderer.makeIntoTriangle(rokuBitmapRegion, points)
    ' game.canvas.renderer.drawObject(300, 300, triangle.bitmap)
    ' ?"Draw Calls: ";game.canvas.renderer.drawCallsLastFrame
    ' game.canvas.renderer.drawObject(700, 300, rokuBitmap)
    ' game.canvas.renderer.drawSquare(700 + points[0].x, 300 + points[0].y, 4, BGE.Colors().Red)
    ' game.canvas.renderer.drawSquare(700 + points[1].x, 300 + points[1].y, 4, BGE.Colors().Green)
    ' game.canvas.renderer.drawSquare(700 + points[2].x, 300 + points[2].y, 4, BGE.Colors().Blue)
    game.canvas.renderer.drawSquare(destPoints[0].x, destPoints[0].y, 4, BGE_Colors().Red)
    game.canvas.renderer.drawSquare(destPoints[1].x, destPoints[1].y, 4, BGE_Colors().Green)
    game.canvas.renderer.drawSquare(destPoints[2].x, destPoints[2].y, 4, BGE_Colors().Blue)
    game.screen.swapBuffers()
end sub

sub testRender2(game)
    triPoints = [
        BGE_Math_Vector(400, 300) 'getRandomScreenPoint(400, 1280, 720),
        BGE_Math_Vector(800, 400)
        BGE_Math_Vector(600, 200) 'getRandomScreenPoint(400, 1280, 720)
    ]
    for i = 0 to 2
        game.canvas.renderer.drawTriangle(triPoints, 0, 0, getColor())
        game.canvas.renderer.drawTrianglePoints(triPoints)
        game.screen.swapBuffers()
        game.canvas.renderer.onSwapBuffers()
        sleep(5)
    end for
    'game.canvas.renderer.triangleCache.cleanCache()
    'game.canvas.clear(&hff)
end sub

function getRandomScreenPoint(padding, w, h)
    x = rnd(w - 2 * padding) + padding
    y = rnd(h - 2 * padding) + padding
    return BGE_Math_Vector(x, y)
end function

function getColor(r = 255 as integer, g = 255 as integer, b = 255 as integer, a = 255 as integer) as integer
    red% = rnd(r)
    green% = rnd(g)
    blue% = rnd(b)
    color% = (red% << 24) + (green% << 16) + (blue% << 8) + a
    return color%
end function'//# sourceMappingURL=./main.bs.map