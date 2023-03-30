function __BGE_Debug_DebugOptions_builder()
    instance = {}
    instance.new = sub()
        m.draw_colliders = false
        m.draw_collider_names = false
        m.draw_safe_zones = false
        m.colliders_color = BGE_RGBAtoRGBA(&hFF, 0, 0, 0.8)
        m.safe_action_zone_color = BGE_RGBAtoRGBA(0, &hFF, 0, 0.2)
        m.safe_title_zone_color = BGE_RGBAtoRGBA(0, 0, &hFF, 0.2)
        m.limit_frame_rate = 0
        m.show_debug_ui = false
        m.draw_debugUi_to_screen = false
        m.draw_entity_axes = false
        m.draw_entity_names = false
        m.draw_scene_object_normals = false
    end sub
    return instance
end function
function BGE_Debug_DebugOptions()
    instance = __BGE_Debug_DebugOptions_builder()
    instance.new()
    return instance
end function'//# sourceMappingURL=./DebugOptions.bs.map