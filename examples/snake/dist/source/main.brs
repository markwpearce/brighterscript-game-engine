sub Main()
    game = BGE_Game(1280, 720, true) ' This initializes the game engine
    game.loadSound("die", "pkg:/sounds/die.wav")
    game.loadSound("score", "pkg:/sounds/score.wav")
    main_room = MainRoom(game)
    game.defineRoom(main_room)
    game.changeRoom(main_room.name)
    game.debugDrawEntityDetails(true)
    game.debugDrawColliders(true)
    ' game.debugDrawSafeZones(true)
    game.Play()
    ' vscode_rale_tracker_entry
end sub'//# sourceMappingURL=./main.bs.map