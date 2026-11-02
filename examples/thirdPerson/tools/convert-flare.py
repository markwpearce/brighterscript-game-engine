# Re-saves one of the Flare Blender 2.49 sources (see CREDITS.md) so Blender 5 can render it
# with render-character.py (tools/ at the repo root). Run with Blender 2.79 (newer Blender drops 2.49 animation):
#
#   blender -b skeleton_0.blend --python tools/convert-flare.py -- <converted>/skeleton_0.blend
#
# Their materials are Blender Internal ones, coloured by procedural textures (clouds, wood,
# voronoi...) that Blender 5 drops, leaving e.g. the skeleton's dark armour plain white. This
# rebuilds each one as Cycles nodes: the diffuse colour at its intensity, mixed with each
# colour texture's colour through a noise texture (or the image, for image textures).
import sys

import bpy


def link(tree, output, input):
    tree.links.new(output, input)


def colour_from_slots(material, tree, base):
    colour = base
    for slot in material.texture_slots:
        if not slot or not slot.texture or not slot.use_map_color_diffuse:
            continue
        texture = slot.texture
        mix = tree.nodes.new("ShaderNodeMixRGB")
        mix.inputs["Color1"].default_value = (0, 0, 0, 1)
        link(tree, colour, mix.inputs["Color1"])
        if texture.type == "IMAGE" and texture.image:
            image = tree.nodes.new("ShaderNodeTexImage")
            image.image = texture.image
            link(tree, image.outputs["Color"], mix.inputs["Color2"])
            mix.inputs["Fac"].default_value = slot.diffuse_color_factor
        elif texture.type != "NONE":
            coords = tree.nodes.new("ShaderNodeTexCoord")
            scale = tree.nodes.new("ShaderNodeMapping")
            scale.scale = slot.scale
            noise = tree.nodes.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 1 / max(getattr(texture, "noise_scale", 0.25), 0.02)
            noise.inputs["Detail"].default_value = 4
            link(tree, coords.outputs["Object"], scale.inputs["Vector"])
            link(tree, scale.outputs["Vector"], noise.inputs["Vector"])
            factor = tree.nodes.new("ShaderNodeMath")
            factor.operation = "MULTIPLY"
            factor.inputs[1].default_value = slot.diffuse_color_factor
            link(tree, noise.outputs["Fac"], factor.inputs[0])
            link(tree, factor.outputs["Value"], mix.inputs["Fac"])
            mix.inputs["Color2"].default_value = tuple(slot.color) + (1,)
        else:
            continue
        colour = mix.outputs["Color"]
    return colour


def convert(material):
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    rgb = tree.nodes.new("ShaderNodeRGB")
    rgb.outputs["Color"].default_value = tuple(c * material.diffuse_intensity for c in material.diffuse_color) + (1,)
    link(tree, colour_from_slots(material, tree, rgb.outputs["Color"]), shader.inputs["Base Color"])
    shader.inputs["Specular"].default_value = min(material.specular_intensity * 0.5, 1)
    shader.inputs["Roughness"].default_value = 0.6
    surface = shader.outputs["BSDF"]
    if material.emit > 0:
        emission = tree.nodes.new("ShaderNodeEmission")
        emission.inputs["Color"].default_value = tuple(material.diffuse_color) + (1,)
        emission.inputs["Strength"].default_value = material.emit
        add = tree.nodes.new("ShaderNodeAddShader")
        link(tree, surface, add.inputs[0])
        link(tree, emission.outputs["Emission"], add.inputs[1])
        surface = add.outputs["Shader"]
    link(tree, surface, output.inputs["Surface"])


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    for material in bpy.data.materials:
        if material.name != "ShadowCatcher":
            convert(material)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)


main()
