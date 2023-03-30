' @module BGE
function __BGE_Room_builder()
    instance = __BGE_GameEntity_builder()
    instance.super0_new = instance.new
    instance.new = function(game as object, args = {} as object)
        m.super0_new(game, args)
    end function
    return instance
end function
function BGE_Room(game as object, args = {} as object)
    instance = __BGE_Room_builder()
    instance.new(game, args)
    return instance
end function'//# sourceMappingURL=./Room.bs.map