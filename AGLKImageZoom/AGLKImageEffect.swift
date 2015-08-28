//
//  AGLKImageEffect.swift
//  ImageZoom
//
//  Created by Richard Clements on 28/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import GLKit

class AGLKImageEffect: AGLKBaseEffect {
    
    override func prepareOpenGL() {
        loadShaders("AGLKImageShader")
    }
    
}
