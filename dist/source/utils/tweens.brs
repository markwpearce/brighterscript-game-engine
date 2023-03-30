' @module BGE
' ******************************************************
' Copyright Steven Kean 2010-2015
' All Rights Reserved.
' ******************************************************
function BGE_Tweens_CreateTweenObject(start_data as object, dest_data as object, duration as integer, tween as string) as object
    tween_data = {
        start: {}
        current: {}
        dest: {}
        duration: duration
        timer: invalid
        tween: tween
    }
    for each key in start_data
        tween_data.start[key] = start_data[key]
        tween_data.current[key] = start_data[key]
    end for
    for each key in dest_data
        tween_data.dest[key] = dest_data[key]
    end for
    tween_data.timer = BGE_GameTimer()
    return tween_data
end function

function BGE_Tweens_GetTweenObjectPercentState(tween_object as object) as float
    key = invalid
    largest_start_dest_difference = 0
    for each k in tween_object.start
        start_dest_difference = (tween_object.start[k] - tween_object.dest[k])
        if start_dest_difference > largest_start_dest_difference
            largest_start_dest_difference = start_dest_difference
            key = k
        end if
    end for
    if (tween_object.start[key] - tween_object.dest[key]) = 0
        return 1.0
    end if
    if key = invalid
        return 0
    end if
    return (tween_object.start[key] - tween_object.current[key]) / (tween_object.start[key] - tween_object.dest[key])
end function

function BGE_Tweens_HandleTween(tween_data as object) as boolean
    ' Example
    ' m.movement_data = {
    '     start: {x: x, y: y}
    '     current: {x: x, y: y}
    '     dest: {x: x, y: y}
    '     duration: 90
    '     timer: CreateObject("roTimespan")
    '     tween: "LinearTween"
    ' }
    tween = "LinearTween"
    if invalid <> tween_data["tween"]
        tween = tween_data.tween
    end if
    current_time = tween_data.timer.TotalMilliseconds()
    for each key in tween_data.start
        tween_data.current[key] = m.tweens[tween](tween_data.start[key], tween_data.dest[key], current_time, tween_data.duration)
    end for
    return current_time >= tween_data.duration
end function

function BGE_Tweens_ChangeTweenDest(tween_data as object, dest_data as object)
    tween_data.timer.Mark()
    for each key in dest_data
        tween_data.start[key] = tween_data.current[key]
        tween_data.dest[key] = dest_data[key]
    end for
end function

function BGE_Tweens_GetTweens() as object
    if m.tweens = invalid
        m.tweens = {
            LinearTween: BGE_Tweens_LinearTween
            QuadraticTween: BGE_Tweens_QuadraticTween
            QuadraticEaseIn: BGE_Tweens_QuadraticEaseIn
            QuadraticEaseOut: BGE_Tweens_QuadraticEaseOut
            QuadraticEaseInOut: BGE_Tweens_QuadraticEaseInOut
            QuadraticEaseOutIn: BGE_Tweens_QuadraticEaseOutIn
            SquareTween: BGE_Tweens_SquareTween
            SquareEaseIn: BGE_Tweens_SquareEaseIn
            SquareEaseOut: BGE_Tweens_SquareEaseOut
            SquareEaseInOut: BGE_Tweens_SquareEaseInOut
            SquareEaseOutIn: BGE_Tweens_SquareEaseOutIn
            CubicTween: BGE_Tweens_CubicTween
            CubicEaseIn: BGE_Tweens_CubicEaseIn
            CubicEaseOut: BGE_Tweens_CubicEaseOut
            CubicEaseInOut: BGE_Tweens_CubicEaseInOut
            CubicEaseOutIn: BGE_Tweens_CubicEaseOutIn
            QuarticTween: BGE_Tweens_QuarticTween
            QuarticEaseIn: BGE_Tweens_QuarticEaseIn
            QuarticEaseOut: BGE_Tweens_QuarticEaseOut
            QuarticEaseInOut: BGE_Tweens_QuarticEaseInOut
            QuarticEaseOutIn: BGE_Tweens_QuarticEaseOutIn
            QuinticTween: BGE_Tweens_QuinticTween
            QuinticEaseIn: BGE_Tweens_QuinticEaseIn
            QuinticEaseOut: BGE_Tweens_QuinticEaseOut
            QuinticEaseInOut: BGE_Tweens_QuinticEaseInOut
            QuinticEaseOutIn: BGE_Tweens_QuinticEaseOutIn
            SinusoidalTween: BGE_Tweens_SinusoidalTween
            SinusoidalEaseIn: BGE_Tweens_SinusoidalEaseIn
            SinusoidalEaseOut: BGE_Tweens_SinusoidalEaseOut
            SinusoidalEaseInOut: BGE_Tweens_SinusoidalEaseInOut
            SinusoidalEaseOutIn: BGE_Tweens_SinusoidalEaseOutIn
            ExponentialTween: BGE_Tweens_ExponentialTween
            ExponentialEaseIn: BGE_Tweens_ExponentialEaseIn
            ExponentialEaseOut: BGE_Tweens_ExponentialEaseOut
            ExponentialEaseInOut: BGE_Tweens_ExponentialEaseInOut
            ExponentialEaseOutIn: BGE_Tweens_ExponentialEaseOutIn
            CircularTween: BGE_Tweens_CircularTween
            CircularEaseIn: BGE_Tweens_CircularEaseIn
            CircularEaseOut: BGE_Tweens_CircularEaseOut
            CircularEaseInOut: BGE_Tweens_CircularEaseInOut
            CircularEaseOutIn: BGE_Tweens_CircularEaseOutIn
            ElasticTween: BGE_Tweens_ElasticTween
            ElasticEaseIn: BGE_Tweens_ElasticEaseIn
            ElasticEaseOut: BGE_Tweens_ElasticEaseOut
            ElasticEaseInOut: BGE_Tweens_ElasticEaseInOut
            ElasticEaseOutIn: BGE_Tweens_ElasticEaseOutIn
            OvershootTween: BGE_Tweens_OvershootTween
            OvershootEaseIn: BGE_Tweens_OvershootEaseIn
            OvershootEaseOut: BGE_Tweens_OvershootEaseOut
            OvershootEaseInOut: BGE_Tweens_OvershootEaseInOut
            OvershootEaseOutIn: BGE_Tweens_OvershootEaseOutIn
            BounceTween: BGE_Tweens_BounceTween
            BounceEaseIn: BGE_Tweens_BounceEaseIn
            BounceEaseOut: BGE_Tweens_BounceEaseOut
            BounceEaseInOut: BGE_Tweens_BounceEaseInOut
            BounceEaseOutIn: BGE_Tweens_BounceEaseOutIn
        }
    end if
    return m.tweens
end function

function BGE_Tweens_LinearTween(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*t/d + b
    time = currentTime / duration
    return change * time + start
end function

' ****************
' Quadratic
' ****************
function BGE_Tweens_QuadraticTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_QuadraticEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_QuadraticEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*(t/=d)*t + b
    time = currentTime / duration
    return change * time * time + start
end function

function BGE_Tweens_QuadraticEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' -c *(t/=d)*(t-2) + b
    time = currentTime / duration
    return - change * time * (time - 2) + start
end function

function BGE_Tweens_QuadraticEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if ((t/=d/2) < 1) return c/2*t*t + b;
    ' return -c/2 * ((--t)*(t-2) - 1) + b;
    time = currentTime / (duration / 2)
    if time < 1
        return change / 2 * time * time + start
    else
        time = time - 1
        return - change / 2 * (time * (time - 2) - 1) + start
    end if
end function

function BGE_Tweens_QuadraticEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_QuadraticEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_QuadraticEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

' ****************
' Square
' ****************
function BGE_Tweens_SquareTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_SquareEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_SquareEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*(t/=d)*t*t*t + b
    time = currentTime / duration
    return change * time * time + start
end function

function BGE_Tweens_SquareEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' -c * ((t=t/d-1)*t*t*t - 1) + b
    time = (currentTime / duration) - 1
    return - change * (time * time - 1) + start
end function

function BGE_Tweens_SquareEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if ((t/=d/2) < 1) return c/2*t*t*t*t + b;
    ' return -c/2 * ((t-=2)*t*t*t - 2) + b;
    time = currentTime / (duration / 2)
    if time < 1
        return change / 2 * time * time + start
    else
        time = time - 2
        return - change / 2 * (time * time - 2) + start
    end if
end function

function BGE_Tweens_SquareEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_SquareEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_SquareEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

' ****************
' Cubic
' ****************
function BGE_Tweens_CubicTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_CubicEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_CubicEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*(t/=d)*t*t + b
    time = currentTime / duration
    return change * time * time * time + start
end function

function BGE_Tweens_CubicEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*((t=t/d-1)*t*t + 1) + b
    time = (currentTime / duration) - 1
    return change * (time * time * time + 1) + start
end function

function BGE_Tweens_CubicEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if ((t/=d/2) < 1) return c/2*t*t*t + b;
    ' return c/2*((t-=2)*t*t + 2) + b
    time = currentTime / (duration / 2)
    if time < 1
        return change / 2 * time * time * time + start
    else
        time = time - 2
        return change / 2 * (time * time * time + 2) + start
    end if
end function

function BGE_Tweens_CubicEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_CubicEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_CubicEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

' ****************
' Quartic
' ****************
function BGE_Tweens_QuarticTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_QuarticEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_QuarticEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*(t/=d)*t*t*t + b
    time = currentTime / duration
    return change * time * time * time * time + start
end function

function BGE_Tweens_QuarticEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' -c * ((t=t/d-1)*t*t*t - 1) + b
    time = (currentTime / duration) - 1
    return - change * (time * time * time * time - 1) + start
end function

function BGE_Tweens_QuarticEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if ((t/=d/2) < 1) return c/2*t*t*t*t + b;
    ' return -c/2 * ((t-=2)*t*t*t - 2) + b;
    time = currentTime / (duration / 2)
    if time < 1
        return change / 2 * time * time * time * time + start
    else
        time = time - 2
        return - change / 2 * (time * time * time * time - 2) + start
    end if
end function

function BGE_Tweens_QuarticEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_QuarticEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_QuarticEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

' ****************
' Quintic
' ****************
function BGE_Tweens_QuinticTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_QuinticEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_QuinticEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*(t/=d)*t*t*t*t + b
    time = currentTime / duration
    return change * time * time * time * time * time + start
end function

function BGE_Tweens_QuinticEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c*((t=t/d-1)*t*t*t*t + 1) + b
    time = (currentTime / duration) - 1
    return change * (time * time * time * time * time + 1) + start
end function

function BGE_Tweens_QuinticEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if ((t/=d/2) < 1) return c/2*t*t*t*t*t + b;
    ' return c/2*((t-=2)*t*t*t*t + 2) + b;
    time = currentTime / (duration / 2)
    if time < 1
        return change / 2 * time * time * time * time * time + start
    else
        time = time - 2
        return change / 2 * (time * time * time * time * time + 2) + start
    end if
end function

function BGE_Tweens_QuinticEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_QuinticEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_QuinticEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

' ****************
' Sinusoidal
' ****************
function BGE_Tweens_SinusoidalTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_SinusoidalEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_SinusoidalEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    pi = 3.1415926535897932384626433832795
    change = finish - start
    ' -c * Math.cos(t/d * (Math.PI/2)) + c + b
    time = currentTime / duration
    return - change * Cos(time * (pi / 2)) + change + start
end function

function BGE_Tweens_SinusoidalEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    pi = 3.1415926535897932384626433832795
    change = finish - start
    ' c * Math.sin(t/d * (Math.PI/2)) + b
    time = currentTime / duration
    return change * Sin(time * (pi / 2)) + start
end function

function BGE_Tweens_SinusoidalEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    pi = 3.1415926535897932384626433832795
    change = finish - start
    ' -c/2 * (Math.cos(Math.PI*t/d) - 1) + b
    time = currentTime / duration
    return - change / 2 * (Cos(pi * time) - 1) + start
end function

function BGE_Tweens_SinusoidalEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_SinusoidalEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_SinusoidalEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

' ****************
' Exponential
' ****************
function BGE_Tweens_ExponentialTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_ExponentialEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_ExponentialEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' (t==0) ? b : c * Math.pow(2, 10 * (t/d - 1)) + b
    if currentTime = 0
        return start
    else
        return change * (2 ^ (10 * (currentTime / duration - 1))) + start
    end if
end function

function BGE_Tweens_ExponentialEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' (t==d) ? b+c : c * (-Math.pow(2, -10 * t/d) + 1) + b
    if currentTime = duration
        return start + change
    else
        return change * (- (2 ^ (- 10 * currentTime / duration)) + 1) + start
    end if
end function

function BGE_Tweens_ExponentialEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if (t==0) return b;
    ' if (t==d) return b+c;
    ' if ((t/=d/2) < 1) return c/2 * Math.pow(2, 10 * (t - 1)) + b;
    ' return c/2 * (-Math.pow(2, -10 * --t) + 2) + b;
    time = currentTime / (duration / 2)
    if currentTime = 0
        return start
    else if currentTime = duration
        return start + change
    else if time < 1
        return change / 2 * (2 ^ (10 * (time - 1))) + start
    else
        time = time - 1
        return change / 2 * (- (2 ^ (- 10 * time)) + 2) + start
    end if
end function

function BGE_Tweens_ExponentialEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if (t==0) return b;
    ' if (t==d) return b+c;
    ' if ((t/=d/2) < 1) return c/2 * (-Math.pow(2, -10 * t/1) + 1) + b;
    ' return c/2 * (Math.pow(2, 10 * (t-2)/1) + 1) + b;
    time = currentTime / (duration / 2)
    if currentTime = 0
        return start
    else if currentTime = duration
        return start + change
    else if time < 1
        return change / 2 * (- (2 ^ (- 10 * time / 1)) + 1) + start
    else
        return change / 2 * (2 ^ (10 * (time - 2) / 1) + 1) + start
    end if
end function

' ****************
' Circular
' ****************
function BGE_Tweens_CircularTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_CircularEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_CircularEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' -c * (Math.sqrt(1 - (t/=d)*t) - 1) + b
    time = currentTime / duration
    return - change * (Sqr(1 - time * time) - 1) + start
end function

function BGE_Tweens_CircularEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' c * Math.sqrt(1 - (t=t/d-1)*t) + b
    time = (currentTime / duration) - 1
    return change * Sqr(1 - time * time) + start
end function

function BGE_Tweens_CircularEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if ((t/=d/2) < 1) return -c/2 * (Math.sqrt(1 - t*t) - 1) + b;
    ' return c/2 * (Math.sqrt(1 - (t-=2)*t) + 1) + b;
    time = currentTime / (duration / 2)
    if time < 1
        return - change / 2 * (Sqr(1 - time * time) - 1) + start
    else
        time = time - 2
        return change / 2 * (Sqr(1 - time * time) + 1) + start
    end if
end function

function BGE_Tweens_CircularEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_CircularEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_CircularEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

' ****************
' Elastic
' ****************
function BGE_Tweens_ElasticTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_ElasticEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_ElasticEaseIn(start as float, finish as float, currentTime as float, duration as float, amplitude = invalid as dynamic, period = invalid as dynamic) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    pi = 3.1415926535897932384626433832795
    change = finish - start
    ' if (t==0) return b;
    ' if ((t/=d)==1) return b+c;
    ' if (!p) p=d*.3;
    ' if (!a || a < Math.abs(c)) { a=c; var s=p/4; }
    ' else var s = p/(2*Math.PI) * Math.asin (c/a);
    ' return -(a*Math.pow(2,10*(t-=1)) * Math.sin( (t*d-s)*(2*Math.PI)/p )) + b;
    time = currentTime / duration
    if currentTime = 0
        return start
    else if time = 1
        return start + change
    end if
    if period = invalid
        period = duration * .3
    end if
    speed = period / 4
    if amplitude = invalid or amplitude < Abs(change)
        amplitude = change
    else
        speed = period / (2 * pi) * tan(change / amplitude) ' Roku does not support Asin! Tan approximates close enough - Asin(change / amplitude)
    end if
    time = time - 1
    return - (amplitude * (2 ^ (10 * time)) * Sin((time * duration - speed) * (2 * pi) / period)) + start
end function

function BGE_Tweens_ElasticEaseOut(start as float, finish as float, currentTime as float, duration as float, amplitude = invalid as dynamic, period = invalid as dynamic) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    pi = 3.1415926535897932384626433832795
    change = finish - start
    ' if (t==0) return b;
    ' if ((t/=d)==1) return b+c;
    ' if (!p) p=d*.3;
    ' if (!a || a < Math.abs(c)) { a=c; var s=p/4; }
    ' else var s = p/(2*Math.PI) * Math.asin (c/a);
    ' return (a*Math.pow(2,-10*t) * Math.sin( (t*d-s)*(2*Math.PI)/p ) + c + b);
    time = currentTime / duration
    if currentTime = 0
        return start
    else if time = 1
        return start + change
    end if
    if period = invalid
        period = duration * .3
    end if
    speed = period / 4
    if amplitude = invalid or amplitude < Abs(change)
        amplitude = change
    else
        speed = period / (2 * pi) * tan(change / amplitude) ' Roku does not support Asin! Tan approximates close enough - (change / amplitude)
    end if
    return (amplitude * (2 ^ (- 10 * time)) * Sin((time * duration - speed) * (2 * pi) / period) + change + start)
end function

function BGE_Tweens_ElasticEaseInOut(start as float, finish as float, currentTime as float, duration as float, amplitude = invalid as dynamic, period = invalid as dynamic) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    pi = 3.1415926535897932384626433832795
    change = finish - start
    ' if (t==0) return b;
    ' if ((t/=d/2)==2) return b+c;
    ' if (!p) p=d*(.3*1.5);
    ' if (!a || a < Math.abs(c)) { a=c; var s=p/4; }
    ' else var s = p/(2*Math.PI) * Math.asin (c/a);
    ' if (t < 1) return -.5*(a*Math.pow(2,10*(t-=1)) * Math.sin( (t*d-s)*(2*Math.PI)/p )) + b;
    ' return (a*Math.pow(2,-10*(t-=1)) * Math.sin( (t*d-s)*(2*Math.PI)/p )*.5 + c + b);
    time = currentTime / (duration / 2)
    if currentTime = 0
        return start
    else if time = 2
        return start + change
    end if
    if period = invalid
        period = duration * (.3 * 1.5)
    end if
    speed = period / 4
    if amplitude = invalid or amplitude < Abs(change)
        amplitude = change
    else
        speed = period / (2 * pi) * tan(change / amplitude) ' Roku does not support Asin! Tan approximates close enough - Asin(change / amplitude)
    end if
    time = time - 1
    if time < 0
        return - .5 * (amplitude * (2 ^ (10 * time)) * Sin((time * duration - speed) * (2 * pi) / period)) + start
    else
        return (amplitude * (2 ^ (- 10 * time)) * Sin((time * duration - speed) * (2 * pi) / period) * .5 + change + start)
    end if
end function

function BGE_Tweens_ElasticEaseOutIn(start as float, finish as float, currentTime as float, duration as float, amplitude = invalid as dynamic, period = invalid as dynamic) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_ElasticEaseOut(0, change, currentTime * 2, duration, amplitude, period) * .5 + start
    else
        return BGE_Tweens_ElasticEaseIn(0, change, currentTime * 2 - duration, duration, amplitude, period) * .5 + (change * .5) + start
    end if
end function

' ****************
' Overshoot
' ****************
function BGE_Tweens_OvershootTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_OvershootEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_OvershootEaseIn(start as float, finish as float, currentTime as float, duration as float, overshoot = 1.70158 as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if (s == undefined) s = 1.70158;
    ' return c*(t/=d)*t*((s+1)*t - s) + b;
    time = currentTime / duration
    return change * time * time * ((overshoot + 1) * time - overshoot) + start
end function

function BGE_Tweens_OvershootEaseOut(start as float, finish as float, currentTime as float, duration as float, overshoot = 1.70158 as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if (s == undefined) s = 1.70158;
    ' return c*((t=t/d-1)*t*((s+1)*t + s) + 1) + b;
    time = (currentTime / duration) - 1
    return change * (time * time * ((overshoot + 1) * time + overshoot) + 1) + start
end function

function BGE_Tweens_OvershootEaseInOut(start as float, finish as float, currentTime as float, duration as float, overshoot = 1.70158 as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    ' if (s == undefined) s = 1.70158;
    ' if ((t/=d/2) < 1) return c/2*(t*t*(((s*=(1.525))+1)*t - s)) + b;
    ' return c/2*((t-=2)*t*(((s*=(1.525))+1)*t + s) + 2) + b
    time = currentTime / (duration / 2)
    overshoot = overshoot * 1.525
    if time < 1
        return change / 2 * (time * time * ((overshoot + 1) * time - overshoot)) + start
    else
        time = time - 2
        return change / 2 * (time * time * ((overshoot + 1) * time + overshoot) + overshoot) + start
    end if
end function

function BGE_Tweens_OvershootEaseOutIn(start as float, finish as float, currentTime as float, duration as float, overshoot = 1.70158 as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_OvershootEaseOut(0, change, currentTime * 2, duration, overshoot) * .5 + start
    else
        return BGE_Tweens_OvershootEaseIn(0, change, currentTime * 2 - duration, duration, overshoot) * .5 + (change * .5) + start
    end if
end function

' ****************
' Bounce
' ****************
function BGE_Tweens_BounceTween(start as float, finish as float, currentTime as float, duration as float) as float
    return BGE_Tweens_BounceEaseInOut(start, finish, currentTime, duration)
end function

function BGE_Tweens_BounceEaseIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    return change - BGE_Tweens_BounceEaseOut(0, change, duration - currentTime, duration) + start
end function

function BGE_Tweens_BounceEaseOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    time = currentTime / duration
    if time < (1 / 2.75)
        return change * (7.5625 * time * time) + start
    else if time < (2 / 2.75)
        time = time - (1.5 / 2.75)
        return change * (7.5625 * time * time + .75) + start
    else if time < (2.5 / 2.75)
        time = time - (2.25 / 2.75)
        return change * (7.5625 * time * time + .9375) + start
    else
        time = time - (2.625 / 2.75)
        return change * (7.5625 * time * time + .984375) + start
    end if
end function

function BGE_Tweens_BounceEaseInOut(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_BounceEaseIn(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_BounceEaseOut(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function

function BGE_Tweens_BounceEaseOutIn(start as float, finish as float, currentTime as float, duration as float) as float
    if currentTime > duration or duration = 0
        return finish
    end if
    change = finish - start
    if currentTime < duration / 2
        return BGE_Tweens_BounceEaseOut(0, change, currentTime * 2, duration) * .5 + start
    else
        return BGE_Tweens_BounceEaseIn(0, change, currentTime * 2 - duration, duration) * .5 + (change * .5) + start
    end if
end function'//# sourceMappingURL=./tweens.bs.map