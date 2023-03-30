' @module BGE
function __BGE_Debug_MemoryDisplay_builder()
    instance = __BGE_Debug_DebugWindow_builder()
    instance.super3_new = instance.new
    instance.new = sub(game as object)
        m.super3_new(game)
        m.memoryLabel = invalid
        m.device = CreateObject("roDeviceInfo")
        m.width = 140
        m.height = 40
        m.vertAlign = "top"
        m.horizAlign = "right"
        m.memoryLabel = BGE_UI_Label(game)
        m.memoryLabel.drawableText.font = m.game.getFont("debugUI")
        m.addChild(m.memoryLabel)
    end sub
    instance.super3_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt as float)
        level = m.device.GetGeneralMemoryLevel()
        m.memoryLabel.setText("Memory: " + bslib_toString(level))
        m.width = m.memoryLabel.width + 20
    end sub
    return instance
end function
function BGE_Debug_MemoryDisplay(game as object)
    instance = __BGE_Debug_MemoryDisplay_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./MemoryDisplay.bs.map