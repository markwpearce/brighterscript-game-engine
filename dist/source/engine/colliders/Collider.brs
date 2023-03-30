' @module BGE
' Colliders are attached to GameEntities and when two colliders intersect, it triggers the onCollision() method in
' the GameEntity
function __BGE_Collider_builder()
    instance = {}
    ' The type of this collider - should be defined in sub classes (eg. "circle", "rectangle")
    ' Name this collider will be identified by
    ' Does this collider trigger onCollision() ?
    ' Offset from the GameEntity it is attached to
    ' Bitflag for collision detection: this collider is in this group - https://developer.roku.com/en-ca/docs/references/brightscript/interfaces/ifsprite.md#setmemberflagsflags-as-integer-as-void
    ' Bitflag for collision detection: this collider will only collider with colliders in this group - https://developer.roku.com/en-ca/docs/references/brightscript/interfaces/ifsprite.md#setcollidableflagsflags-as-integer-as-void
    ' Used internal to Game - should not be modified manually
    ' Colliders can be tagged with any number of tags so they can be easily identified (e.g. "enemy", "wall", etc.)
    ' Creates a new Collider
    '
    ' @param {string} colliderName - the name this collider will be identified by
    ' @param {object} [args={}] - additional properties to be added to this collider
    instance.new = sub(colliderName as string, args = {} as object)
        m.colliderType = invalid
        m.name = ""
        m.enabled = true
        m.offset = BGE_Math_Vector()
        m.memberFlags = 1
        m.collidableFlags = 1
        m.compositorObject = invalid
        m.tagsList = BGE_TagList()
        m.name = colliderName
        m.append(args)
    end sub
    ' Sets up this collider to be associated with a given game and entity
    '
    ' @param {object} game - the game this collider is used by
    ' @param {string} entityName - name of the entity that owns this collider
    ' @param {string} entityId - id of the entity that owns this collider
    ' @param {BGE.Math.Vector} entityPosition - entity's position
    instance.setupCompositor = sub(game as object, entityName as string, entityId as string, entityPosition as object)
        region = CreateObject("roRegion", game.getEmptyBitmap(), 0, 0, 1, 1)
        m.compositorObject = game.compositor.NewSprite(entityPosition.x, entityPosition.y, region)
        m.compositorObject.SetDrawableFlag(false)
        m.compositorObject.SetData({
            colliderName: m.name
            objectName: entityName
            entityId: entityId
        })
        m.refreshColliderRegion()
    end sub
    ' Refreshes the collider.
    ' Called every frame by the GameEngine.
    ' Should be overrided by sub classes if they have specialized collision set ups (e.g. circle, rectangle).
    '
    instance.refreshColliderRegion = sub()
        region = m.compositorObject.GetRegion()
        region.SetCollisionType(0)
    end sub
    ' Moves the compositor to the new x,y position - called from Game when the entity it is attached to moves
    '
    ' @param {BGE.Math.Vector} entityPosition
    instance.adjustCompositorObject = sub(entityPosition as object)
        if m.enabled
            m.compositorObject.SetMemberFlags(m.memberFlags)
            m.compositorObject.SetCollidableFlags(m.collidableFlags)
            m.refreshColliderRegion()
            m.compositorObject.MoveTo(entityPosition.x, entityPosition.y)
        else
            m.compositorObject.SetMemberFlags(0)
            m.compositorObject.SetCollidableFlags(0)
        end if
    end sub
    ' Helper function to draw an outline around the collider
    '
    ' @param {object} draw2d
    ' @param {BGE.Math.Vector} position
    ' @param {integer} [color=&hFF0000FF]
    instance.debugDraw = sub(draw2d as object, position as object, color = &hFF0000FF as integer, addName = false as boolean, font = invalid)
    end sub
    return instance
end function
function BGE_Collider(colliderName as string, args = {} as object)
    instance = __BGE_Collider_builder()
    instance.new(colliderName, args)
    return instance
end function'//# sourceMappingURL=./Collider.bs.map