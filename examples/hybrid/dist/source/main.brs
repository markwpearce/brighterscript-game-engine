sub main()
    m.playPong = true
    'need to launch Draw2d first!
    launchDraw2d(false)
    launchSceneGraph()
    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if "roSGNodeEvent" = msgType
            msgField = msg.getField()
            msgData = msg.getData()
            if "switchMode" = msgField and msgData
                m.screen.close()
                launchDraw2d(true)
                launchSceneGraph()
            end if
        end if
    end while
end sub

sub launchSceneGraph()
    ' Create the Screen object and main message port
    m.screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    m.screen.setMessagePort(m.port)
    m.scene = m.screen.CreateScene("MainScene") ' Load "Main" scene
    m.screen.show()
    m.scene.observeField("switchMode", m.port)
    m.scene.switchMode = false
    m.scene.setFocus(true)
end sub

sub launchDraw2d(waitForInput = true)
    if m.playPong
        launchGame(waitForInput)
    else
        launchSimpleDraw2d(waitForInput)
    end if
end sub

sub launchGame(waitForInput = true)
    ' This initializes the game engine
    game = BGE_Game(1280, 720, true)
    game.loadBitmap("ball", "pkg:/sprites/ball.png")
    game.loadBitmap("paddle", "pkg:/sprites/paddle.png")
    game.loadSound("hit", "pkg:/sounds/hit.wav")
    game.loadSound("score", "pkg:/sounds/score.wav")
    main_room = MainRoom(game)
    game.defineRoom(main_room)
    game.changeRoom(main_room.name)
    game.getDebugUI().addChild(BGE_Debug_FpsDisplay(game))
    game.debugShowUi(true)
    if waitForInput
        game.play()
    else
        game.screen.swapBuffers()
    end if
end sub

sub launchSimpleDraw2d(waitForInput = true)
    if m.draw2dScreen = invalid
        m.draw2dScreen = CreateObject("roScreen", true, 1280, 720)
    end if
    if m.draw2dPort = invalid
        m.draw2dPort = CreateObject("roMessagePort")
        m.draw2dScreen.SetMessagePort(m.draw2dPort)
    end if
    if m.fontRegistry = invalid
        m.fontRegistry = CreateObject("roFontRegistry")
    end if
    keepGoing = true
    drawX = 0
    drawY = 400
    rectSpeed = 20
    while keepGoing
        screen_msg = m.draw2dPort.GetMessage()
        buttonPress = - 1
        while screen_msg <> invalid
            if type(screen_msg) = "roUniversalControlEvent" and screen_msg.GetInt() <> 11
                if screen_msg.GetInt() < 100
                    buttonPress = screen_msg.GetInt()
                end if
            end if
            screen_msg = m.draw2dPort.GetMessage()
        end while
        if waitForInput
            drawSimpleScene(drawX, drawY, 200, 100, &hFF0000FF)
        end if
        drawX += rectSpeed
        if drawX > 1280
            drawX = 0
        end if
        if buttonPress = 0 or not waitForInput
            keepGoing = false
        end if
    end while
end sub

sub drawSimpleScene(rectX, rectY, rectW, rectH, color)
    m.draw2dScreen.drawText("This is Draw2d. Press back to change modes.", 200, 200, - 1, m.fontRegistry.GetDefaultFont())
    m.draw2dScreen.drawRect(rectX, rectW, rectW, rectH, color)
    m.draw2dScreen.SwapBuffers()
end sub'//# sourceMappingURL=./main.bs.map