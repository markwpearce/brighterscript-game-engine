' @module BGE
' Gets the number of lines in a string by counting the newlines
'
' @param {string} text
' @return {integer}
function BGE_getNumberOfLinesInAString(text as string) as integer
    lines = 1
    newLine = Chr(10)
    nextNewLineIndex = text.inStr(0, newLine)
    while nextNewLineIndex > - 1
        if nextNewLineIndex < text.len()
            lines++
            nextNewLineIndex = text.inStr(nextNewLineIndex + 1, newLine)
        else
            exit while
        end if
    end while
    return lines
end function

' Finds the index of the last time a substring appears in a string
'
' @param {string} text
' @param {string} substring
' @return {integer}
function BGE_lastInStr(text as string, substring as string) as integer
    nextLastIndex = text.inStr(0, substring)
    lastIndex = nextLastIndex
    while nextLastIndex > - 1
        lastIndex = nextLastIndex
        nextLastIndex = text.inStr(lastIndex + 1, substring)
    end while
    return lastIndex
end function

' Given a float number, returns the number with a fixed numbers of decimals as a string
'
' @param {float} num
' @param {integer} precision
' @return {string}
function BGE_numberToFixed(num as float, precision as integer) as string
    rounded = BGE_Math_Round(num, precision)
    numStr = rounded.toStr().trim()
    decimalIndex = BGE_lastInStr(numStr, ".")
    if - 1 = decimalIndex
        numStr += "." + string(precision, "0")
        return numStr
    end if
    afterDecimalCount = numStr.len() - 1 - decimalIndex
    if precision > afterDecimalCount
        numStr += string(precision - afterDecimalCount, "0")
    end if
    return numStr
end function

function BGE_arrayToStr(things as object) as string
    result = "["
    addedOne = false
    for each thing in things
        if addedOne
            result += ", "
        end if
        if invalid <> GetInterface(thing, "ifToStr")
            result += thing.toStr()
        else if invalid <> thing.toStr
            result += thing.toStr()
        else if invalid <> thing.toString
            result += thing.toString()
        else
            valueType = lcase(type(thing))
            if valueType = "<uninitialized>"
                result += "<uninitialized>"
            else if thing = invalid
                result += "<invalid>"
            else if valueType = "string" or valueType = "rostring"
                result += thing
            end if
        end if
        addedOne = true
    end for
    result += "]"
    return result
end function'//# sourceMappingURL=./strings.bs.map