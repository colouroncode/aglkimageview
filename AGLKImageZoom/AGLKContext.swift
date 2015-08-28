//
//  AGLKContext.swift
//  ImageZoom
//
//  Created by Richard Clements on 26/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import GLKit

class AGLKContext: EAGLContext {
    var clearColor: GLKVector4 = GLKVector4Make(0, 0, 0, 0) {
        didSet {
            glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a)
        }
    }
    
    func clear(mask: GLbitfield) {
        glClear(mask)
    }
}