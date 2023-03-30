' Much of this code is modified/translated from https://github.com/pgliaskovitis/scratch-a-pixel
function BGE_Math_isFloatArray44(x as dynamic) as boolean
    if rodash_isArray(x)
        if x.count() = 4
            for each row in x
                if not (rodash_isArray(row) and row.count() = 4 and rodash_isNumber(row[0]))
                    return false
                end if
            end for
            return true
        end if
    end if
    return false
end function

function BGE_Math_getFloat44Identity() as object
    return [
        [
            1
            0
            0
            0
        ]
        [
            0
            1
            0
            0
        ]
        [
            0
            0
            1
            0
        ]
        [
            0
            0
            0
            1
        ]
    ]
end function

sub BGE_Math_fillFloat44(dest as object, src as object)
    for i = 0 to 3
        for j = 0 to 3
            dest[i][j] = src[i][j] * 1.0
        end for
    end for
end sub
function __BGE_Math_Matrix44_builder()
    instance = {}
    instance.new = sub(x00 = invalid as dynamic, x01 = invalid, x02 = invalid, x03 = invalid, x10 = invalid, x11 = invalid, x12 = invalid, x13 = invalid, x20 = invalid = invalid, x21 = invalid, x22 = invalid, x23 = invalid, x30 = invalid, x31 = invalid, x32 = invalid, x33 = invalid)
        m.mat = BGE_Math_getFloat44Identity()
        if invalid = x00
            ' do nothing -- m.mat is the identity matrix
            return
        end if
        if invalid = x01 and BGE_Math_isFloatArray44(x00)
            ' first argument is a float[][]
            BGE_Math_fillFloat44(m.mat, x00)
            return
        end if
        ' individual float values passed in
        m.mat[0][0] = x00
        m.mat[0][1] = x01
        m.mat[0][2] = x02
        m.mat[0][3] = x03
        m.mat[1][0] = x10
        m.mat[1][1] = x11
        m.mat[1][2] = x12
        m.mat[1][3] = x13
        m.mat[2][0] = x20
        m.mat[2][1] = x21
        m.mat[2][2] = x22
        m.mat[2][3] = x23
        m.mat[3][0] = x30
        m.mat[3][1] = x31
        m.mat[3][2] = x32
        m.mat[3][3] = x33
    end sub
    instance.copy = function() as object
        return BGE_Math_Matrix44(m.mat)
    end function
    instance.setFrom = function(b as object) as object
        BGE_Math_fillFloat44(m.mat, b.mat)
        return m
    end function
    instance.equals = function(b as object) as boolean
        for i = 0 to 3
            for j = 0 to 3
                if m.mat[i][j] <> b.mat[i][j]
                    return false
                end if
            end for
        end for
        return true
    end function
    instance.multiply = function(operand as object) as object
        result = BGE_Math_Matrix44()
        a = m.mat
        b = operand.mat
        for j = 0 to 3
            result.mat[0][j] = a[0][0] * b[0][j] + a[0][1] * b[1][j] + a[0][2] * b[2][j] + a[0][3] * b[3][j]
            result.mat[1][j] = a[1][0] * b[0][j] + a[1][1] * b[1][j] + a[1][2] * b[2][j] + a[1][3] * b[3][j]
            result.mat[2][j] = a[2][0] * b[0][j] + a[2][1] * b[1][j] + a[2][2] * b[2][j] + a[2][3] * b[3][j]
            result.mat[3][j] = a[3][0] * b[0][j] + a[3][1] * b[1][j] + a[3][2] * b[2][j] + a[3][3] * b[3][j]
        end for
        return result
    end function
    ' Returns the transposed version of this Matrix
    '
    ' @return {Matrix44}
    instance.transposed = function() as object
        result = BGE_Math_Matrix44()
        for i = 0 to 3
            for j = 0 to 3
                result.mat[i][j] = m.mat[j][i]
            end for
        end for
        return result
    end function
    '  This method needs to be used for point-matrix multiplication. Keep in mind
    '  we don't make the distinction between points and vectors at least from
    '  a programming point of view, as both (as well as normals) are declared as Vec3.
    '  However, mathematically they need to be treated differently. Points can be translated
    '  when translation for vectors is meaningless. Furthermore, points are implicitly
    '  be considered as having homogeneous coordinates. Thus the w coordinates needs
    '  to be computed and to convert the coordinates from homogeneous back to Cartesian
    '  coordinates, we need to divided x, y z by w.
    '  The coordinate w more often than not equals 1, but it can be different than
    '  1 especially when the matrix is projective matrix (perspective projection matrix).
    instance.multVecMatrix = function(srcVect as object) as object
        src = [
            srcVect.x
            srcVect.y
            srcVect.z
        ]
        a = src[0] * m.mat[0][0] + src[1] * m.mat[1][0] + src[2] * m.mat[2][0] + m.mat[3][0]
        b = src[0] * m.mat[0][1] + src[1] * m.mat[1][1] + src[2] * m.mat[2][1] + m.mat[3][1]
        c = src[0] * m.mat[0][2] + src[1] * m.mat[1][2] + src[2] * m.mat[2][2] + m.mat[3][2]
        w = src[0] * m.mat[0][3] + src[1] * m.mat[1][3] + src[2] * m.mat[2][3] + m.mat[3][3]
        result = BGE_Math_Vector(a / w, b / w, c / w)
        return result
    end function
    '  This method needs to be used for vector-matrix multiplication. Look at the differences
    '  with the previous method (to compute a point-matrix multiplication). We don't use
    '  the coefficients in the matrix that account for translation (x[3][0], x[3][1], x[3][2])
    '  and we don't compute w.
    instance.multDirMatrix = function(srcVect as object) as object
        src = [
            srcVect.x
            srcVect.y
            srcVect.z
        ]
        a = src[0] * m.mat[0][0] + src[1] * m.mat[1][0] + src[2] * m.mat[2][0]
        b = src[0] * m.mat[0][1] + src[1] * m.mat[1][1] + src[2] * m.mat[2][1]
        c = src[0] * m.mat[0][2] + src[1] * m.mat[1][2] + src[2] * m.mat[2][2]
        return BGE_Math_Vector(a, b, c)
    end function
    ' Compute the inverse of the matrix using the Gauss-Jordan (or reduced row) elimination method.
    ' We didn't explain in the lesson on Geometry how the inverse of matrix can be found. Don't
    ' worry at this point if you don't understand how this works. But we will need to be able to
    ' compute the inverse of matrices in the first lessons of the "Foundation of 3D Rendering" section,
    ' which is why we've added this code. For now, you can just use it and rely on it
    ' for doing what it's supposed to do. If you want to learn how this works though, check the lesson
    ' on called Matrix Inverse in the "Mathematics and Physics of Computer Graphics" section.
    instance.inverse = function() as object
        s = BGE_Math_getFloat44Identity()
        t = m.copy().mat
        ' Forward elimination
        for i = 0 to 3
            pivot = i
            pivotsize = t[i][i]
            if pivotsize < 0
                pivotsize = - pivotsize
            end if
            for j = i + 1 to 3
                tmp = t[j][i]
                if tmp < 0
                    tmp = - tmp
                end if
                if tmp > pivotsize
                    pivot = j
                    pivotsize = tmp
                end if
            end for
            if pivotsize = 0
                ' Cannot invert singular matrix
                return BGE_Math_Matrix44()
            end if
            if pivot <> i
                for j = 0 to 3
                    tmp = t[i][j]
                    t[i][j] = t[pivot][j]
                    t[pivot][j] = tmp
                    tmp = s[i][j]
                    s[i][j] = s[pivot][j]
                    s[pivot][j] = tmp
                end for
            end if
            for j = i + 1 to 3
                f = t[j][i] / t[i][i]
                for k = 0 to 3
                    t[j][k] -= f * t[i][k]
                    s[j][k] -= f * s[i][k]
                end for
            end for
        end for
        ' Backward substitution
        for i = 3 to 0 step - 1
            f = t[i][i]
            if f = 0
                ' Cannot invert singular matrix
                return BGE_Math_Matrix44()
            end if
            for j = 0 to 3
                t[i][j] /= f
                s[i][j] /= f
            end for
            for j = 0 to i - 1
                f = t[j][i]
                for k = 0 to 3
                    t[j][k] -= f * t[i][k]
                    s[j][k] -= f * s[i][k]
                end for
            end for
        end for
        return BGE_Math_Matrix44(s)
    end function
    ' Set current matrix to its inverse
    instance.invert = sub()
        m.mat = m.inverse().mat
    end sub
    instance.toStr = function() as string
        return "[" + bslib_toString(rodash_toString(m.mat[0])) + "," + chr(10) + " " + bslib_toString(rodash_toString(m.mat[1])) + "," + chr(10) + " " + bslib_toString(rodash_toString(m.mat[2])) + "," + chr(10) + " " + bslib_toString(rodash_toString(m.mat[3])) + "]"
    end function
    return instance
end function
function BGE_Math_Matrix44(x00 = invalid as dynamic, x01 = invalid, x02 = invalid, x03 = invalid, x10 = invalid, x11 = invalid, x12 = invalid, x13 = invalid, x20 = invalid = invalid, x21 = invalid, x22 = invalid, x23 = invalid, x30 = invalid, x31 = invalid, x32 = invalid, x33 = invalid)
    instance = __BGE_Math_Matrix44_builder()
    instance.new(x00, x01, x02, x03, x10, x11, x12, x13, x20, x21, x22, x23, x30, x31, x32, x33)
    return instance
end function

function BGE_Math_Matrix44Identity() as object
    return BGE_Math_Matrix44()
end function

function BGE_Math_lookAt(from as object, lookTo as object) as object
    tmp = BGE_Math_Vector(0, 1, 0)
    ' because the forward axis in a right hand coordinate system points backward we compute -(to - from)
    c = from.subtract(lookTo)
    c.normalize()
    a = tmp.normalize().crossProduct(c)
    a.normalize() ' this is just in case Up is not normalized
    b = c.crossProduct(a)
    camToWorld = BGE_Math_getFloat44Identity()
    ' set x - axis
    camToWorld[0][0] = a.x
    camToWorld[0][1] = a.y
    camToWorld[0][2] = a.z
    ' set y - axis
    camToWorld[1][0] = b.x
    camToWorld[1][1] = b.y
    camToWorld[1][2] = b.z
    ' set z - axis
    camToWorld[2][0] = c.x
    camToWorld[2][1] = c.y
    camToWorld[2][2] = c.z
    ' set position
    camToWorld[3][0] = from.x
    camToWorld[3][1] = from.y
    camToWorld[3][2] = from.z
    return BGE_Math_Matrix44(camToWorld)
end function

function BGE_Math_orthographicMatrix(top as float, bottom as float, left as float, right as float, far as float, near as float) as object
    t = top
    l = left
    b = bottom
    r = right
    f = far
    n = near
    ' set OpenGL perspective projection matrix
    return BGE_Math_Matrix44(2 / (r - l), 0, 0, 0, 0, 2 / (t - b), 0, 0, 0, 0, - 2 / (f - n), 0, 0 - (r + l) / (r - l), - (t + b) / (t - b), - (f + n) / (f - n), 1)
    ' set OpenGL perspective projection matrix
    return BGE_Math_Matrix44(2 / (r - l), 0, 0, - (r + l) / (r - l), 0, 2 / (t - b), 0, - (t + b) / (t - b), 0, 0, - 2 / (f - n), - (f + n) / (f - n), 0, 0, 0, 1)
end function

function BGE_Math_getScaleMatrix(scale as object) as object
    return BGE_Math_Matrix44(scale.x, 0, 0, 0, 0, scale.y, 0, 0, 0, 0, scale.z, 0, 0, 0, 0, 1)
end function

function BGE_Math_getRotationMatrix(rotation as object) as object
    thetaX = rotation.x
    thetaY = rotation.y
    thetaZ = rotation.z
    result = BGE_Math_Matrix44()
    'Rotate about the X-Axis
    if thetaX <> 0
        sinX = sin(thetaX)
        cosX = cos(thetaX)
        rotXMatrix = BGE_Math_Matrix44()
        rotXMatrix.mat[1][1] = cosX
        rotXMatrix.mat[1][2] = - sinX
        rotXMatrix.mat[2][1] = sinX
        rotXMatrix.mat[2][2] = cosX
        result = result.multiply(rotXMatrix)
    end if
    'Rotate about the Y - Axis
    if thetaY <> 0
        sinY = sin(thetaY)
        cosY = cos(thetaY)
        rotYMatrix = BGE_Math_Matrix44()
        rotYMatrix.mat[0][0] = cosY
        rotYMatrix.mat[0][2] = sinY
        rotYMatrix.mat[2][0] = - sinY
        rotYMatrix.mat[2][2] = cosY
        result = result.multiply(rotYMatrix)
    end if
    'Rotate about the Z - Axis
    if thetaZ <> 0
        sinZ = sin(thetaZ)
        cosZ = cos(thetaZ)
        rotZMatrix = BGE_Math_Matrix44()
        rotZMatrix.mat[0][0] = cosZ
        rotZMatrix.mat[0][1] = sinZ
        rotZMatrix.mat[1][0] = - sinZ
        rotZMatrix.mat[1][1] = cosZ
        result = result.multiply(rotZMatrix)
    end if
    return result
end function

function BGE_Math_getTranslationMatrix(position as object) as object
    return BGE_Math_Matrix44(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, position.x, position.y, position.z, 1)
end function

function BGE_Math_getTransformationMatrix(position as object, rotation as object, scale as object) as object
    scaleMatrix = BGE_Math_getScaleMatrix(scale)
    rotationMatrix = BGE_Math_getRotationMatrix(rotation)
    translationMatrix = BGE_Math_getTranslationMatrix(position)
    return scaleMatrix.multiply(rotationMatrix.multiply(translationMatrix))
end function'//# sourceMappingURL=./Matrix44.bs.map