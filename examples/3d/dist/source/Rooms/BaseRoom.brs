function __BaseRoom_builder()
    instance = __BGE_Room_builder()
    instance.super1_new = instance.new
    instance.new = sub(game)
        m.super1_new(game)
        m.cameraSpeed = 300
        m.cameraVelocity = 0
        m.cameraRotation = 0
        m.debugEnabled = false
        m.instructions = ""
        m.name = "BaseRoom"
    end sub
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt)
        if m.cameraRotation <> 0
            m.game.canvas.renderer.camera.rotate(BGE_Math_Vector(0, m.cameraRotation * dt, 0))
        end if
        if m.cameraVelocity <> 0
            m.game.canvas.renderer.camera.position.plusEquals(m.game.canvas.renderer.camera.orientation.scale(m.cameraSpeed * dt * m.cameraVelocity))
        end if
    end sub
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input)
        m.handleCameraMovement(input)
        m.handleSceneChange(input)
        if input.press and input.isButton("replay")
            m.debugEnabled = not m.debugEnabled
            'm.game.debugDrawEntityDetails(m.debugEnabled)
            m.game.debugShowUi(m.debugEnabled)
        end if
    end sub
    instance.handleCameraMovement = sub(input)
        m.cameraVelocity = 0
        m.cameraRotation = 0
        if input.x <> 0 or input.y <> 0
            m.cameraVelocity = input.y
            m.cameraRotation = input.x
        end if
    end sub
    instance.super1_onDrawEnd = instance.onDrawEnd
    instance.onDrawEnd = sub(renderObj as object)
        font = m.game.getFont("default")
        frameCenter = renderObj.getCanvasCenter()
        renderObj.DrawText(m.instructions, frameCenter.x, 100, BGE_Colors().white, font, "center")
        text = "Move Camera: Arrows | Change Scene: <</>> | Debug Information: Replay"
        renderObj.DrawText(text, frameCenter.x, 140, BGE_Colors().white, font, "center")
    end sub
    instance.handleSceneChange = sub(input)
        if input.press
            if input.isButton("fastforward")
                goToNextRoom(m, 1)
            else if input.isButton("rewind")
                goToNextRoom(m, - 1)
            else if input.isButton("back")
                m.game.end()
            end if
        end if
    end sub
    return instance
end function
function BaseRoom(game)
    instance = __BaseRoom_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./BaseRoom.bs.map