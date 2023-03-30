sub Main()
    game = BGE_Game(1280, 720, true) ' This initializes the game engine
    game.loadBitmap("ball", "pkg:/sprites/ball.png")
    game.loadBitmap("paddle", "pkg:/sprites/paddle.png")
    game.loadSound("hit", "pkg:/sounds/hit.wav")
    game.loadSound("score", "pkg:/sounds/score.wav")
    main_room = MainRoom(game)
    game.defineRoom(main_room)
    game.changeRoom(main_room.name)
    'game.debugDrawColliders(true)
    'game.debugDrawEntityDetails(true)
    game.getDebugUI().addChild(BGE_Debug_FpsDisplay(game))
    'game.getDebugUI().addChild(new BGE.Debug.InputDisplay(game))
    'game.debugDrawSafeZones(true)
    game.debugShowUi(true)
    use3d = true
    if use3d
        game.setCamera(BGE_Camera3d())
        frameCenter = game.canvas.renderer.getCanvasCenter()
        game.canvas.renderer.camera.position.x = frameCenter.x
        game.canvas.renderer.camera.position.y = frameCenter.y
        game.canvas.renderer.camera.setTarget(frameCenter)
    end if
    game.Play()
    ' vscode_rale_tracker_entry
end sub'//# sourceMappingURL=./main.bs.map