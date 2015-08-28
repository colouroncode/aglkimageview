//
//  AGLKViewListener.swift
//  ImageZoom
//
//  Created by Richard Clements on 28/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import GLKit

class AGLKViewListener: NSObject {
    
    static let getInstance = AGLKViewListener()
    var listeners = Set<GLKView>()
    
    func applicationDidEnterBackground() {
        for view in listeners {
            view.deleteDrawable()
        }
    }
    
}
