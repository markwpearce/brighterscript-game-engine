' @module BGE
sub BGE_registryWrite(registry_section as string, key as string, value as dynamic)
    section = CreateObject("roRegistrySection", registry_section)
    section.Write(key, FormatJson(value))
    section.Flush()
end sub

function BGE_registryRead(registry_section as string, key as string, default_value = invalid as dynamic) as dynamic
    section = CreateObject("roRegistrySection", registry_section)
    if section.Exists(key)
        return ParseJson(section.Read(key))
    else
        if default_value <> invalid
            section.Write(key, FormatJson(default_value))
            section.Flush()
        end if
        return default_value
    end if
end function'//# sourceMappingURL=./registry.bs.map