sub Main()
    game = BGE_Game(880, 420, true) ' This initializes the game engine
    game.loadBitmap("ball", "pkg:/sprites/ball.png")
    firstRoom = MainRoom(game)
    game.defineRoom(firstRoom)
    game.changeRoom(firstRoom.name)
    game.centerCanvasToScreen()
    game.debugDrawColliders(true)
    game.debugDrawSafeZones(true)
    game.debugShowUi(true, true)
    game.getDebugUI().addChild(BGE_Debug_FpsDisplay(game))
    game.getDebugUI().addChild(BGE_Debug_InputDisplay(game))
    game.play()
end sub'//# sourceMappingURL=./main.bs.map