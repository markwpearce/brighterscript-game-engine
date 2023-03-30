function __BGE_UI_UiContainer_builder()
    instance = __BGE_UI_UiWidget_builder()
    ' RGBA value for the background of the window/container
    ' Should the background be drawn?
    instance.super1_new = instance.new
    instance.new = sub(game as object)
        m.super1_new(game)
        m.backgroundRGBA = BGE_RGBAtoRGBA(128, 128, 128, 0.8)
        m.showBackground = true
        m.children = []
    end sub
    ' Method for handling any actions needed when this is removed from view
    ' Clears all children
    instance.super1_onRemove = instance.onRemove
    instance.onRemove = sub()
        m.clearChildren()
    end sub
    instance.addChild = sub(element as object)
        if element <> invalid
            m.children.push(element)
        end if
    end sub
    instance.removeChild = sub(element as object)
        indexToRemove = - 1
        if invalid = element
            return
        end if
        for i = 0 to m.children.count() - 1
            if m.children[i].id = element.id
                indexToRemove = i
                exit for
            end if
        end for
        if indexToRemove >= 0 and invalid <> m.children[indexToRemove]
            m.children[indexToRemove].onDestroy()
            m.children.delete(indexToRemove)
        end if
    end sub
    instance.clearChildren = sub()
        for each element in m.children
            element.onDestroy()
        end for
        m.children.clear()
    end sub
    ' Method for handling any updates based on time since previous frame
    ' Calls same method in all children
    '
    ' @param {float} deltaTime - milliseconds since last frame
    instance.super1_onUpdate = instance.onUpdate
    instance.onUpdate = sub(deltaTime as float)
        for each child in m.children
            if child <> invalid
                child.onUpdate(deltaTime)
            end if
        end for
    end sub
    ' Set the canvas this UIWidget Draws to
    ' Sets the canvas on all children
    '
    ' @param {object} [canvas=invalid] The canvas this should draw to - if invalid, then will draw to the game canvas
    instance.super1_setCanvas = instance.setCanvas
    instance.setCanvas = sub(canvas = invalid as object)
        m.super1_setCanvas(canvas)
        if invalid <> m.children
            for each child in m.children
                if child <> invalid
                    child.setCanvas(m.canvas)
                end if
            end for
        end if
    end sub
    ' Method called each frame to draw any images of this entity
    '
    instance.super1_draw = instance.draw
    instance.draw = sub()
        if m.showBackground
            m.canvas.DrawRect(m.position.x, m.position.y, m.width, m.height, m.backgroundRGBA)
        end if
        m.children.sortBy("zIndex")
        for each child in m.children
            if invalid <> child and child.enabled
                child.repositionBasedOnParent(m)
                child.draw()
            end if
        end for
    end sub
    ' Function to get the value of the UIContainer, which will be an object of all the values of the children
    '
    ' @return {object} - the value of this element
    instance.super1_getValue = instance.getValue
    instance.getValue = sub() as object
        value = {}
        for each child in m.children
            value.addReplace(child.name, child.getValue())
        end for
        return value
    end sub
    ' Method to process input per frame
    ' Calls same method in all children
    '
    ' @param {BGE.GameInput} input - GameInput object for the last frame
    instance.super1_onInput = instance.onInput
    instance.onInput = sub(input as object)
        for each child in m.children
            child.onInput(input)
        end for
    end sub
    ' Method to process an ECP keyboard event
    ' @see  https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md
    ' Calls same method in all children
    '
    ' @param {integer} char
    instance.super1_onECPKeyboard = instance.onECPKeyboard
    instance.onECPKeyboard = sub(char as integer)
        for each child in m.children
            child.onECPKeyboard(char)
        end for
    end sub
    ' Method to process an External Control Protocol event
    ' @see  https://developer.roku.com/en-ca/docs/references/brightscript/events/roinputevent.md
    ' Calls same method in all children
    '
    ' @param {object} data
    instance.super1_onECPInput = instance.onECPInput
    instance.onECPInput = sub(data as object)
        for each child in m.children
            child.onECPInput(data)
        end for
    end sub
    ' Method to handle audio events
    ' @see  https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md
    ' Calls same method in all children
    '
    ' @param {object} msg - roAudioPlayerEvent
    instance.super1_onAudioEvent = instance.onAudioEvent
    instance.onAudioEvent = sub(msg as object)
        for each child in m.children
            child.onAudioEvent(msg)
        end for
    end sub
    ' Called when the game pauses
    ' Calls same method in all children
    '
    instance.super1_onPause = instance.onPause
    instance.onPause = sub()
        for each child in m.children
            child.onPause()
        end for
    end sub
    ' Called when the game unpauses
    ' Calls same method in all children
    '
    ' @param {integer} pauseTimeMs - The number of milliseconds the game was paused
    instance.super1_onResume = instance.onResume
    instance.onResume = sub(pauseTimeMs as integer)
        for each child in m.children
            child.onResume(pauseTimeMs)
        end for
    end sub
    ' Called on url event
    ' @see  https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md
    ' Calls same method in all children
    '
    ' @param {object} msg - roUrlEvent
    instance.super1_onUrlEvent = instance.onUrlEvent
    instance.onUrlEvent = sub(msg as object)
        for each child in m.children
            child.onUrlEvent(msg)
        end for
    end sub
    ' General purpose event handler for in-game events.
    ' Calls same method in all children
    '
    ' @param {string} eventName - Event name that describes the event type
    ' @param {object} data - Any extra data to go along with the event
    instance.super1_onGameEvent = instance.onGameEvent
    instance.onGameEvent = sub(eventName as string, data as object)
        for each child in m.children
            child.onGameEvent(eventName, data)
        end for
    end sub
    ' Method called when the current room changes.
    ' This method is only called when the entity is marked as `persistant`,
    ' otherwise entities are destroyed on room changes.
    ' Calls same method in all children
    '
    ' @param {Room} newRoom - The next room
    instance.super1_onChangeRoom = instance.onChangeRoom
    instance.onChangeRoom = sub(newRoom as object)
        for each child in m.children
            child.onChangeRoom(newRoom)
        end for
    end sub
    ' Method called when this entity is destroyed
    '
    instance.super1_onDestroy = instance.onDestroy
    instance.onDestroy = sub()
        m.clearChildren()
    end sub
    return instance
end function
function BGE_UI_UiContainer(game as object)
    instance = __BGE_UI_UiContainer_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./UiContainer.bs.map