' @module BGE
function BGE_HSVtoRGBA(hPercent as float, sPercent as float, vPercent as float, a = invalid as dynamic) as integer
    ' Romans_I_XVI port (w/ a few tweaks) of: https://schinckel.net/2012/01/10/hsv-to-rgb-in-javascript/
    ' @see http://schinckel.net/2012/01/10/hsv-to-rgb-in-javascript/
    hPercent = hPercent mod 360
    rgb = [
        0
        0
        0
    ]
    if sPercent = 0
        rgb = [
            vPercent / 100
            vPercent / 100
            vPercent / 100
        ]
    else
        s = sPercent / 100
        v = vPercent / 100
        h = hPercent / 60
        i = int(h)
        data = [
            v * (1 - s)
            v * (1 - s * (h - i))
            v * (1 - s * (1 - (h - i)))
        ]
        if i = 0
            rgb = [
                v
                data[2]
                data[0]
            ]
        else if i = 1
            rgb = [
                data[1]
                v
                data[0]
            ]
        else if i = 2
            rgb = [
                data[0]
                v
                data[2]
            ]
        else if i = 3
            rgb = [
                data[0]
                data[1]
                v
            ]
        else if i = 4
            rgb = [
                data[2]
                data[0]
                v
            ]
        else
            rgb = [
                v
                data[0]
                data[1]
            ]
        end if
    end if
    for c = 0 to rgb.count() - 1
        rgb[c] = int(rgb[c] * 255)
    end for
    if a <> invalid
        color% = (rgb[0] << 24) + (rgb[1] << 16) + (rgb[2] << 8) + a
    else
        color% = (rgb[0] << 16) + (rgb[1] << 8) + rgb[2]
    end if
    return color%
end function

function BGE_RGBAtoRGBA(red as integer, green as integer, blue as integer, alpha = 1 as float) as integer
    red% = cint((BGE_Math_Clamp(red, 0, 255))) and &hFF
    green% = cint((BGE_Math_Clamp(green, 0, 255))) and &hFF
    blue% = cint((BGE_Math_Clamp(blue, 0, 255))) and &hFF
    if 0 > alpha
        alpha = 0
    else if 1 < alpha
        alpha = 1
    end if
    alphaInt% = cint(BGE_Math_Clamp(cint(alpha * &hFF), 0, 255)) and &hFF
    color% = (red% << 24) + (green% << 16) + (blue% << 8) + alphaInt%
    return color%
end function

function BGE_Colors() as object
    if invalid <> m and invalid <> m.BGEColorsConstant
        return m.BGEColorsConstant
    end if
    colorsObj = {
        Black: BGE_RGBAtoRGBA(0, 0, 0)
        White: BGE_RGBAtoRGBA(255, 255, 255)
        Red: BGE_RGBAtoRGBA(255, 0, 0)
        Lime: BGE_RGBAtoRGBA(0, 255, 0)
        Blue: BGE_RGBAtoRGBA(0, 0, 255)
        Yellow: BGE_RGBAtoRGBA(255, 255, 0)
        Cyan: BGE_RGBAtoRGBA(0, 255, 255)
        Aqua: BGE_RGBAtoRGBA(0, 255, 255)
        Magenta: BGE_RGBAtoRGBA(255, 0, 255)
        Pink: BGE_RGBAtoRGBA(255, 0, 255)
        Fuchsia: BGE_RGBAtoRGBA(255, 0, 255)
        Silver: BGE_RGBAtoRGBA(192, 192, 192)
        Gray: BGE_RGBAtoRGBA(128, 128, 128)
        Grey: BGE_RGBAtoRGBA(128, 128, 128)
        Maroon: BGE_RGBAtoRGBA(128, 0, 0)
        Olive: BGE_RGBAtoRGBA(128, 128, 0)
        Green: BGE_RGBAtoRGBA(0, 128, 0)
        Purple: BGE_RGBAtoRGBA(128, 0, 128)
        Teal: BGE_RGBAtoRGBA(0, 128, 128)
        Navy: BGE_RGBAtoRGBA(0, 0, 128)
    }
    if invalid <> m
        m.BGEColorsConstant = colorsObj
    end if
    return colorsObj
end function

function BGE_ColorsRGB() as object
    if invalid <> m and invalid <> m.BGEColorsRGBConstant
        return m.BGEColorsRGBConstant
    end if
    colorsRGBObj = {}
    colorsObj = BGE_Colors()
    for each color in colorsObj.Items()
        colorsRGBObj[color.key] = color.value >> 8
    end for
    if invalid <> m
        m.BGEColorsRGBConstant = colorsRGBObj
    end if
    return colorsRGBObj
end function

function BGE_GetColor(name as string) as integer
    colorsObj = BGE_Colors()
    defaultColor = colorsObj.White
    if invalid <> colorsObj[name]
        return colorsObj[name]
    end if
    return defaultColor
end function

function BGE_GetColorRGB(name as string) as integer
    colorsObj = BGE_ColorsRGB()
    defaultColor = colorsObj.White
    if invalid <> colorsObj[name]
        return colorsObj[name]
    end if
    return defaultColor
end function

function BGE_getRandomColorRGB() as integer
    color% = rnd(256 * 256 * 256)
    return color%
end function'//# sourceMappingURL=./colors.bs.map