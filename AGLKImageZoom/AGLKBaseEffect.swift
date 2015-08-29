//
//  AGLKBaseEffect.swift
//  ImageZoom
//
//  Created by Richard Clements on 28/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import GLKit

enum AGLKVertexAttribute: GLint {
    case Position
    case Normal
    case Color
    case TexCoords0
    
    static var numberOfAttributes: Int {
        get {
            return Int(AGLKVertexAttribute.TexCoords0.rawValue) + 1
        }
    }
    
    var attributeDescription: String {
        get {
            switch self {
            case .Position:
                return "a_position"
                
            case .Normal:
                return "a_normal"
                
            case .Color:
                return "a_color"
                
            case .TexCoords0:
                return "a_texCoords0"
                
            default:
                return ""
            }
        }
    }
}

private let MAX_TEXTURES = 1
private let MAX_TEX_COORDS = 1

private enum AGLKModel: Int {
    case MVPMatrix
    case NormalMatrix
    case Samplers2D
    case GlobalAmbient
    case DiffuseLightDirection
    case DiffuseLightColor
    case UsesConstantColor
    case ConstantColor
    case ColorFilters
    
    static var numberOfUniforms: Int {
        get {
            return AGLKModel.ColorFilters.rawValue + 1
        }
    }
    
    var uniformDescription: String {
        get {
            switch self {
            case .MVPMatrix:
                return "u_mvpMatrix"
                
            case .NormalMatrix:
                return "u_normalMatrix"
                
            case .Samplers2D:
                return "u_units"
                
            case .GlobalAmbient:
                return "u_globalAmbient"
                
            case .DiffuseLightDirection:
                return "u_diffuseLightDirection"
                
            case .DiffuseLightColor:
                return "u_diffuseLightColor"
                
            case .UsesConstantColor:
                return "u_useConstantColor"
                
            case .ConstantColor:
                return "u_constantColor"
                
            case .ColorFilters:
                return "u_colorFilter"
                
            default:
                return ""
            }
        }
    }
}

struct AGLKBaseEffectTransform {
    var projectionMatrix: GLKMatrix4 = GLKMatrix4Identity
    var modelviewMatrix: GLKMatrix4 = GLKMatrix4Identity
}

class AGLKBaseEffect: NSObject, GLKNamedEffect {
    var program: GLuint {
        get {
            return _program
        }
    }
    private var _program: GLuint = 0
    var transform = AGLKBaseEffectTransform()
    private var projectionMatrix: GLKMatrix4 {
        get {
            return transform.projectionMatrix
        }
        set {
            transform.projectionMatrix = newValue
        }
    }
    private var modelviewMatrix: GLKMatrix4 {
        get {
            return transform.modelviewMatrix
        }
        set {
            transform.modelviewMatrix = newValue
        }
    }
    var globalAmbientLightColor: GLKVector4 = GLKVector4.ZeroVector
    var diffuseLightDirection: GLKVector3 = GLKVector3.ZeroVector
    var diffuseLightColor: GLKVector4 = GLKVector4.ZeroVector
    var texture2d0 = GLKEffectPropertyTexture()
    var useConstantColor: GLboolean = GLboolean(GL_TRUE)
    var constantColor: GLKVector4 = GLKVector4Make(1, 1, 1, 1)
    var colorFilters: GLKVector3 = GLKVector3Make(1, 1, 1)
    private var uniforms: [GLint]
    
    override init() {
        uniforms = [GLint]()
        for var i = 0; i < AGLKModel.numberOfUniforms; i++ {
            uniforms.append(GLint(0))
        }
        super.init()
        
    }
    
    deinit {
        if _program == 0 {
            glUseProgram(0)
            glDeleteProgram(_program)
        }
    }
    
    func prepareOpenGL() {
        
    }
    
    func updateUniformValues() {
        prepareModelview()
        
        let samplerIDs = [GLint(0)]
        glUniform1iv(uniforms[AGLKModel.Samplers2D.rawValue], GLsizei(MAX_TEXTURES), samplerIDs)
        
        glUniform3fv(uniforms[AGLKModel.DiffuseLightColor.rawValue], 1, diffuseLightColor.v)
        glUniform1i(uniforms[AGLKModel.UsesConstantColor.rawValue], GLint(useConstantColor))
        glUniform4fv(uniforms[AGLKModel.ConstantColor.rawValue], 1, constantColor.v)
        glUniform3fv(uniforms[AGLKModel.ColorFilters.rawValue], 1, colorFilters.v)
        
        prepareLightColors()
    }
    
    func prepareToDraw() {
        if program == 0 {
            prepareOpenGL()
        }
        
        glUseProgram(program)
        updateUniformValues()
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), texture2d0.name)
    }
    
    func bindAttribLocations() {
        var location = AGLKVertexAttribute.Position
        glBindAttribLocation(program, GLuint(location.rawValue), location.attributeDescription)
        
        location = .Normal
        glBindAttribLocation(program, GLuint(location.rawValue), location.attributeDescription)
        
        location = .TexCoords0
        glBindAttribLocation(program, GLuint(location.rawValue), location.attributeDescription)
    }
    
    func configureUniformLocations() {
        for var i = 0; i < AGLKModel.numberOfUniforms; i++ {
            if let location = AGLKModel(rawValue: i) {
                uniforms[i] = glGetUniformLocation(program, location.uniformDescription)
            }
        }
    }
    
    func prepareLightColors() {
        glUniform4fv(uniforms[AGLKModel.GlobalAmbient.rawValue], 1, globalAmbientLightColor.v)
        glUniform4fv(uniforms[AGLKModel.DiffuseLightColor.rawValue], 1, diffuseLightColor.v)
    }
    
    func prepareModelviewWithoutNormal() {
        let modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelviewMatrix)
        glUniformMatrix4fv(uniforms[AGLKModel.MVPMatrix.rawValue], 1, 0, modelViewProjectionMatrix.m)
    }
    
    func prepareModelview() {
        let modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelviewMatrix)
        glUniformMatrix4fv(uniforms[AGLKModel.MVPMatrix.rawValue], 1, 0, modelViewProjectionMatrix.m)
        
        let normalMatrix = GLKMatrix4GetMatrix3(GLKMatrix4InvertAndTranspose(modelviewMatrix, nil))
        glUniformMatrix3fv(uniforms[AGLKModel.NormalMatrix.rawValue], 1, GLboolean(GL_FALSE), normalMatrix.m)
    }
    
    //MARK:- OpenGL ES 2
    
    final func loadShaders(name: String) -> Bool {
        var vertexShader = GLuint(0)
        var fragmentShader = GLuint(0)
        
        if let vertexShaderPathName = NSBundle.mainBundle().pathForResource(name, ofType: "vsh"), let fragmentShaderPathName = NSBundle.mainBundle().pathForResource(name, ofType: "fsh") {
            if !compileShader(&vertexShader, type: GLenum(GL_VERTEX_SHADER), file: vertexShaderPathName) || !compileShader(&fragmentShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragmentShaderPathName) {
                return false
            }
            
            _program = glCreateProgram()
            
            glAttachShader(program, vertexShader)
            glAttachShader(program, fragmentShader)
            
            bindAttribLocations()
            
            if !linkProgram(program) {
                if vertexShader != 0 {
                    glDeleteShader(vertexShader)
                    vertexShader = 0
                }
                if fragmentShader != 0 {
                    glDeleteShader(fragmentShader)
                    fragmentShader = 0
                }
                
                if program != 0 {
                    glDeleteProgram(program)
                    _program = 0
                }
                
                return false
            }
            
            configureUniformLocations()
            
            if vertexShader != 0 {
                glDetachShader(program, vertexShader)
                glDeleteShader(vertexShader)
            }
            
            if fragmentShader != 0 {
                glDetachShader(program, fragmentShader)
                glDeleteShader(fragmentShader)
            }
            
            return true
        } else {
            return false
        }
        
    }
    
    func compileShader(inout shader: GLuint, type: GLenum, file: String) -> Bool {
        if let character = NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding, error: nil)?.UTF8String {
            var status = GLint(0)
            shader = glCreateShader(type)
            var source = character
            glShaderSource(shader, 1, &source, nil)
            glCompileShader(shader)
            glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
            if status == 0 {
                glDeleteShader(shader)
                return false
            }
            return true
        }
        return false
    }
    
    func linkProgram(program: GLuint) -> Bool {
        var status = GLint(0)
        glLinkProgram(program)
        
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
        if status == 0 {
            return false
        }
        return true
    }
    
    func validateProgram(program: GLuint) -> Bool {
        var logLength = GLsizei(0)
        var status = GLint(0)
        
        glValidateProgram(program)
        glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        if logLength > 0 {
            var log = Array(count: Int(logLength), repeatedValue: GLchar(0))
            glGetProgramInfoLog(program, GLsizei(logLength), &logLength, &log)
            free(&log)
        }
        
        glGetProgramiv(program, GLenum(GL_VALIDATE_STATUS), &status)
        if status == 0 {
            return false
        }
        return true
    }
}
