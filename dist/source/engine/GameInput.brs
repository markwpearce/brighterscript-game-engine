' @module BGE
' Class that contains all information about the current input during a given frame from the remote
'   @example
'   ' -------Button Code Reference--------
' 	' Button  Pressed Released  Held
'   ' ------------------------------
' 	' Back         0      100   1000
' 	' Up           2      102   1002
' 	' Down         3      103   1003
' 	' Left         4      104   1004
' 	' Right        5      105   1005
' 	' OK           6      106   1006
' 	' Replay       7      107   1007
' 	' Rewind       8      108   1008
' 	' FastForward  9      109   1009
' 	' Options     10      110   1010
' 	' Play        13      113   1013
function __BGE_GameInput_builder()
    instance = {}
    ' The name of the button associated with the current input
    ' The code for the input
    ' Was the button pressed since the last frame
    ' Was the button held down since last frame
    ' Was the button released this frame
    ' How many milliseconds was the current input held for
    ' Current horizontal directional input: left -> -1, right -> 1
    ' Current vertical directional input: up -> -1, down -> 1
    ' Creates a GameInput object based on the buttonCode
    '
    ' @param {integer} buttonCode - button to use for the data
    ' @param {integer} heldTimeMs - how long was this button held for
    instance.new = sub(buttonCode as integer, heldTimeMs as integer)
        m.button = invalid
        m.buttonCode = invalid
        m.press = false
        m.held = false
        m.release = false
        m.heldTimeMs = 0
        m.x = 0
        m.y = 0
        m.buttonCode = buttonCode
        m.button = BGE_buttonNameFromCode(buttonCode)
        m.press = buttonCode < 100
        m.held = buttonCode >= 1000
        m.release = buttonCode >= 100 and buttonCode < 1000
        m.heldTimeMs = heldTimeMs
        m.x = 0
        m.y = 0
        if not m.release
            if m.isButton("right")
                m.x = 1
            else if m.isButton("left")
                m.x = - 1
            else if m.isButton("down")
                m.y = - 1
            else if m.isButton("up")
                m.y = 1
            end if
        end if
    end sub
    ' Is this input for the given button name?
    '
    ' @param {string} buttonName - the button name to check (case insensitive - e.g. "ok" is same as "OK")
    ' @return {boolean} - true if this input matches the given button name
    instance.isButton = function(buttonName as string) as boolean
        return invalid <> buttonName and invalid <> m.button and lcase(buttonName) = lcase(m.button)
    end function
    ' Is this input from the directional pad
    '
    ' @return {boolean} - true if this input was generated from the direction pad
    instance.isDirectionalArrow = function() as boolean
        return m.x <> 0 or m.y <> 0
    end function
    return instance
end function
function BGE_GameInput(buttonCode as integer, heldTimeMs as integer)
    instance = __BGE_GameInput_builder()
    instance.new(buttonCode, heldTimeMs)
    return instance
end function'//# sourceMappingURL=./GameInput.bs.map