' @module BGE
function __BGE_Debug_GarbageCollectorDisplay_builder()
    instance = __BGE_Debug_DebugWindow_builder()
    instance.super3_new = instance.new
    instance.new = sub(game as object)
        m.super3_new(game)
        m.garbageLabel = invalid
        m.width = 140
        m.height = 40
        m.vertAlign = "bottom"
        m.horizAlign = "right"
        m.garbageLabel = BGE_UI_Label(game)
        m.garbageLabel.drawableText.font = m.game.getFont("debugUI")
        m.addChild(m.garbageLabel)
    end sub
    instance.super3_onUpdate = instance.onUpdate
    instance.onUpdate = sub(dt as float)
        stats = m.game.getGarbageCollectionStats()
        if invalid <> stats
            m.garbageLabel.setText("Objects: " + bslib_toString(stats.count) + ", Orphans: " + bslib_toString(stats.orphaned) + ", Root: " + bslib_toString(stats.root))
        else
            m.garbageLabel.setText("No Garbage Collection Data")
        end if
        m.width = m.garbageLabel.width + 20
    end sub
    return instance
end function
function BGE_Debug_GarbageCollectorDisplay(game as object)
    instance = __BGE_Debug_GarbageCollectorDisplay_builder()
    instance.new(game)
    return instance
end function'//# sourceMappingURL=./GarbageCollectorDisplay.bs.map