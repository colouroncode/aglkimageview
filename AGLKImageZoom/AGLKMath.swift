//
//  GLKMath.swift
//  ImageZoom
//
//  Created by Richard Clements on 26/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import GLKit

func animationCurve(fromValue: Double, toValue: Double, currentTime: Double, duration: Double) -> Double {
    let progress = currentTime/duration
    let changeInValue = toValue - fromValue
    return -changeInValue*progress*(progress-2)+fromValue
}

func sign<T: FloatingPointType>(value: T) -> T {
    if value < T(0) {
        return T(-1)
    } else {
        return T(1)
    }
}

func ammendedOverflow(float: Float) -> Float {
    return tanh(float/5)
}

func distanceTravelled(initialVelocity: Float, acceleration: Float, time: Float) -> Float {
    return initialVelocity*time + (acceleration*time*time)/2
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: origin.x + width/2, y: origin.y + height/2)
    }
}

extension Float {
    func withinDelta(float: Float) -> Bool {
        return abs(self - float) < 0.00001
    }
}

func sizeOfArray<T>(array: [T]) -> Int {
    return sizeof(T)*array.count
}

func ==(lhs: GLKMatrix4, rhs: GLKMatrix4) -> Bool {
    return lhs.m00.withinDelta(rhs.m00) && lhs.m01.withinDelta(rhs.m01) && lhs.m02.withinDelta(rhs.m02) && lhs.m03.withinDelta(rhs.m03) && lhs.m10.withinDelta(rhs.m10) && lhs.m11.withinDelta(rhs.m11) && lhs.m12.withinDelta(rhs.m12) && lhs.m13.withinDelta(rhs.m13) && lhs.m20.withinDelta(rhs.m20) && lhs.m21.withinDelta(rhs.m21) && lhs.m22.withinDelta(rhs.m22) && lhs.m23.withinDelta(rhs.m23) && lhs.m30.withinDelta(rhs.m30) && lhs.m31.withinDelta(rhs.m31) && lhs.m32.withinDelta(rhs.m32) && lhs.m33.withinDelta(rhs.m33)
}

func != (lhs: GLKMatrix4, rhs: GLKMatrix4) -> Bool {
    return !(lhs == rhs)
}

extension GLKMatrix4: Printable {
    
    var m: [Float] {
        get {
            return [
                m00, m01, m02, m03,
                m10, m11, m12, m13,
                m20, m21, m22, m23,
                m30, m31, m32, m33
            ]
        }
    }
    
    var scale: Float {
        return m00
    }
    
    var translation: GLKVector3 {
        return GLKVector3Make(m30, m31, m32)
    }
    
    public var description: String {
        return "\(m00, m01, m02, m03)\n\(m10, m11, m12, m13)\n\(m20, m21, m22, m23)\n\(m30, m31, m32, m33)"
    }
}

extension GLKMatrix3 {
    var m: [Float] {
        get {
            return [
                m00, m01, m02,
                m10, m11, m12,
                m20, m21, m22
            ]
        }
    }
}

extension GLKVector4: Printable {
    static let ZeroVector = GLKVector4Make(0, 0, 0, 0)
    
    public var description: String {
        return "\(x, y, z, w)"
    }
}

extension GLKVector3: Printable {
    
    static let ZeroVector = GLKVector3Make(0, 0, 0)
    
    public var description: String {
        return "\(x, y, z)"
    }
}

extension GLKVector2 {
    var v: [Float] {
        get {
            return [x, y]
        }
    }
}

extension GLKVector4 {
    var v: [Float] {
        get {
            return [x, y, z, w]
        }
    }
    
    var lengthSquared: Float {
        get {
            return v[0]*v[0] + v[1]*v[1] + v[2]*v[2] + v[3]*v[3]
        }
    }
    
    func distanceSquared(vector: GLKVector4) -> GLfloat {
        let delta = GLKVector4Subtract(vector, self)
        return GLKVector4DotProduct(delta, delta)
    }
    
    static func vectorFromColor(color: UIColor) -> GLKVector4 {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return GLKVector4Make(Float(red), Float(green), Float(blue), Float(alpha))
    }
}

extension GLKVector3 {
    var v: [Float] {
        get {
            return [x, y, z]
        }
    }
    
    var lengthSquared: Float {
        get {
            return v[0]*v[0] + v[1]*v[1] + v[2]*v[2]
        }
    }
    
    func distanceSquared(vector: GLKVector3) -> GLfloat {
        let delta = GLKVector3Subtract(vector, self)
        return GLKVector3DotProduct(delta, delta)
    }
}

struct SceneVertex {
    var positionCoords: GLKVector3
    var textureCoords: GLKVector2
    init(positionCoords: GLKVector3, textureCoords: GLKVector2) {
        self.positionCoords = positionCoords
        self.textureCoords = textureCoords
    }
}
