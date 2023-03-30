
function init()
  m.top.setFocus(true)
end function

function onKeyEvent(key as string, press as boolean) as boolean
  handled = false
  if press
    if "back" = key
      m.top.switchMode = true
      handled = true
    end if
  end if
  return handled
end function