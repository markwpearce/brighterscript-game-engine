
' Each component has an "init" function that is called at the beginning of the lifecycle
function init()
  print "main Scene init"
  m.top.setFocus(true)
end function




function onKeyEvent(key as string, press as boolean) as boolean
  ?"onKeyEvent: ";key;press
  handled = false
  if press
    if "back" = key
      ? "setting switchMode: ";m.top.switchMode
      m.top.switchMode = true
      handled = true
    end if
  end if
  return handled
end function