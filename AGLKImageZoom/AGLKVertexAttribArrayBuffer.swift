//
//  AGLKVertexAttribArrayBuffer.swift
//  ImageZoom
//
//  Created by Richard Clements on 26/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import UIKit

class AGLKVertexAttribArrayBuffer: NSObject {
    
    var stride = GLsizei(0)
    var bufferSizeBytes = GLsizeiptr(0)
    var glName = GLuint(0)
    
    init(attribStride aStride: GLsizei, numberOfVertices count: GLsizei, data dataPtr: UnsafePointer<Void>, usage: GLenum) {
        stride = aStride
        bufferSizeBytes = GLsizeiptr(stride * count)
        super.init()
        
        
        glGenBuffers(1, &glName)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), glName)
        glBufferData(GLenum(GL_ARRAY_BUFFER), bufferSizeBytes, dataPtr, usage)
    }
    
    func prepareToDrawWithAttrib(index: GLuint, numberOfCoordinates count: GLint, attribOffset offset: GLsizeiptr, shouldEnable: Bool) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), glName)
        if shouldEnable {
            glEnableVertexAttribArray(index)
        }
        
        glVertexAttribPointer(index, count, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(stride), nil + offset)
    }
    
    func reinit(stride aStride: GLsizei, numberOfVertices count: GLsizei, data dataPtr: UnsafePointer<Void>) {
        stride = aStride
        bufferSizeBytes = GLsizeiptr(count*stride)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), glName)
        glBufferData(GLenum(GL_ARRAY_BUFFER), bufferSizeBytes, dataPtr, GLenum(GL_DYNAMIC_DRAW))
    }
    
    func drawArrayWithMode(mode: GLenum, startVertexIndex first: GLint, numberOfVertices count: GLsizei) {
        glDrawArrays(mode, first, count)
    }
    
    class func drawPreparedArraysWithMode(mode: GLenum, startVertexIndex firstIndex: GLint, numberOfVertices count: GLsizei) {
        glDrawArrays(mode, firstIndex, count)
    }
    
    deinit {
        if (glName != 0) {
            glDeleteBuffers(1, &glName)
            glName = 0
        }
    }

}
