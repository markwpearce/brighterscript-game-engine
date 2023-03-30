function __BGE_Debug_DebugWindow_builder()
    instance = __BGE_UI_UiContainer_builder()
    instance.super2_new = instance.new
    instance.new = sub(game as object)
        m.super2_new(game)
        m.backgroundRGBA = BGE_RGBAtoRGBA(128, 128, 128, 0.5)
        m.padding.set(10)
    end sub
    return instance
end function
function BGE_Debug_DebugWindow(game as object)
    instance = __BGE_Debug_DebugWindow_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./DebugWindow.bs.map