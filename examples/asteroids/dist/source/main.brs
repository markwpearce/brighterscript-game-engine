sub Main()
    game = BGE_Game(1280, 720, true) ' This initializes the game engine
    game.loadBitmap("rocket", "pkg:/sprites/rocket_off.png")
    game.loadBitmap("rocket_on", "pkg:/sprites/rocket_on.png")
    game.loadBitmap("rock", "pkg:/sprites/rock_a.png")
    game.loadBitmap("boom", "pkg:/sprites/boom3.png")
    game.loadBitmap("background", "pkg:/sprites/spacebackground.jpg")
    game.loadSound("die", "pkg:/sounds/big_explosion_3.wav")
    game.loadSound("laser", "pkg:/sounds/laser.wav")
    game.loadSound("engine", "pkg:/sounds/engine.wav")
    for i = 1 to 9
        explosionSoundName = "explosion0" + stri(i).trim()
        game.loadSound(explosionSoundName, "pkg:/sounds/explosions/" + bslib_toString(explosionSoundName) + ".wav")
    end for
    main_room = MainRoom(game)
    game.defineRoom(main_room)
    game.changeRoom(main_room.name)
    game.getDebugUI().addChild(BGE_Debug_FpsDisplay(game))
    game.getDebugUI().addChild(BGE_Debug_InputDisplay(game))
    'game.getDebugUI().addChild(new BGE.Debug.MemoryDisplay(game))
    'game.getDebugUI().addChild(new BGE.Debug.GarbageCollectorDisplay(game))
    'game.debugDrawColliders(false)
    'game.debugDrawEntityDetails(true)
    'game.debugDrawSafeZones(true)
    'game.debugShowUi(true)
    use3d = false
    if use3d
        game.setCamera(BGE_Camera3d())
        frameCenter = game.canvas.renderer.getCanvasCenter()
        game.canvas.renderer.camera.position.x = frameCenter.x
        game.canvas.renderer.camera.position.y = frameCenter.y
        game.canvas.renderer.camera.setTarget(frameCenter)
    end if
    game.Play()
end sub'//# sourceMappingURL=./main.bs.map