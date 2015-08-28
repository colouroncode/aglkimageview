//
//  ImageRenderer.swift
//  ImageZoom
//
//  Created by Richard Clements on 26/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import UIKit

class AGLKImageRenderer: NSObject {
    
    private var imageID = 0
    private let cache = NSCache()
    var image: UIImage! {
        didSet {
            if image != oldValue {
                imageID++
                completionHandlers.removeAll(keepCapacity: false)
                deleteCache()
            }
        }
    }
    
    init(image: UIImage) {
        self.image = image
        super.init()
    }
    
    override init() {
        super.init()
    }
    
    func deleteCache() {
        cache.removeAllObjects()
    }
    
    func adjustedSizeForSize(size: CGSize) -> (width: Float, height: Float) {
        let aspectRatio = image.size.width/image.size.height
        let width = size.width
        let height = size.height
        
        let minDimension = min(width, height)
        
        let adjustedWidth: Float
        let adjustedHeight: Float
        
        if image.size.width < width && image.size.height < height {
            adjustedWidth = Float(image.size.width/width)
            adjustedHeight = Float(image.size.height/height)
        } else {
            if width == minDimension {
                adjustedWidth = Float(minDimension/width)
                adjustedHeight = Float(minDimension/height)/Float(aspectRatio)
            } else {
                adjustedWidth = Float(minDimension/width)*Float(aspectRatio)
                adjustedHeight = Float(minDimension/height)
            }
        }
        
        return (width: adjustedWidth, height: adjustedHeight)
    }
    
    typealias ImageRendererCompletionBlock = CGImageRef -> Void
    
    private var completionHandlers = [Float: [(String, ImageRendererCompletionBlock)]]()
    
    private func removeCompletionHandlersForScale(scale: Float) {
        completionHandlers[scale] = nil
    }
    
    func renderImage(scale: Float, boundarySize: CGSize) -> CGImageRef {
        let originalImage = self.image
        let aspectRatio = CGFloat(originalImage.size.width/originalImage.size.height)
        let width = boundarySize.width
        let height = boundarySize.height
        
        let minDimension = min(width, height)
        
        let adjustedWidth: Float
        let adjustedHeight: Float
        
        if width == minDimension {
            adjustedWidth = Float(minDimension)
            adjustedHeight = Float(minDimension)/Float(aspectRatio)
        } else {
            adjustedWidth = Float(minDimension)*Float(aspectRatio)
            adjustedHeight = Float(minDimension)
        }
        
        let trueScale = CGFloat(scale)*UIScreen.mainScreen().scale
        var imageWidth = CGFloat(adjustedWidth)*trueScale
        var imageHeight = CGFloat(adjustedHeight)*trueScale
        
        if imageWidth > originalImage.size.width {
            imageWidth = originalImage.size.width
            imageHeight = originalImage.size.height
        }
        
        let sizeKey = "\(imageWidth)x\(imageHeight)"
        if let image = self.cache.objectForKey(sizeKey) as? UIImage {
            return image.CGImage
        }
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageWidth, height: imageHeight), true, 1.0)
        originalImage.drawInRect(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        self.cache.setObject(image, forKey: "\(imageWidth)x\(imageHeight)")
        return image.CGImage
    }
    
    func renderImage(scale: Float, boundarySize: CGSize, callerID: String, completionHandler: ImageRendererCompletionBlock) {
        
        var completionHandlers = self.completionHandlers
        for (key, value) in self.completionHandlers {
            let filteredValues = value.filter { $0.0 != callerID }
            completionHandlers[key] = filteredValues
        }
        self.completionHandlers = completionHandlers
        
        if var tasks = self.completionHandlers[scale] {
            tasks.append((callerID, completionHandler))
            self.completionHandlers[scale] = tasks
            return
        } else {
            let tasks = [(callerID, completionHandler)]
            self.completionHandlers[scale] = tasks
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            [unowned self] in
            let currentImageID = self.imageID
            let originalImage = self.image
            let aspectRatio = CGFloat(originalImage.size.width/originalImage.size.height)
            let width = boundarySize.width
            let height = boundarySize.height
            
            let minDimension = min(width, height)
            
            let adjustedWidth: Float
            let adjustedHeight: Float
            
            if width == minDimension {
                adjustedWidth = Float(minDimension)
                adjustedHeight = Float(minDimension)/Float(aspectRatio)
            } else {
                adjustedWidth = Float(minDimension)*Float(aspectRatio)
                adjustedHeight = Float(minDimension)
            }
            
            let trueScale = CGFloat(scale)*UIScreen.mainScreen().scale
            var imageWidth = CGFloat(adjustedWidth)*trueScale
            var imageHeight = CGFloat(adjustedHeight)*trueScale
            
            if imageWidth > originalImage.size.width {
                imageWidth = originalImage.size.width
                imageHeight = originalImage.size.height
            }
            
            let sizeKey = "\(imageWidth)x\(imageHeight)"
            if let image = self.cache.objectForKey(sizeKey) as? UIImage {
                dispatch_async(dispatch_get_main_queue()) {
                    if let tasks = self.completionHandlers[scale] {
                        for Ω in tasks {
                            Ω.1(image.CGImage)
                        }
                    }
                    self.removeCompletionHandlersForScale(scale)
                }
            }
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: imageWidth, height: imageHeight), true, 1.0)
            let cgImage = originalImage.CGImage
            let context = UIGraphicsGetCurrentContext()
            CGContextTranslateCTM(context, -imageWidth/2, imageHeight/2)
            CGContextScaleCTM(context, 1, -1)
            CGContextTranslateCTM(context, imageWidth/2, -imageHeight/2)
            CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRect(origin: CGPointZero, size: CGSize(width: imageWidth, height: imageHeight)), cgImage)
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            if currentImageID == self.imageID {
                self.cache.setObject(image, forKey: sizeKey)
                dispatch_async(dispatch_get_main_queue()) {
                    if let tasks = self.completionHandlers[scale] {
                        for Ω in tasks {
                            Ω.1(image.CGImage)
                        }
                    }
                    self.removeCompletionHandlersForScale(scale)
                }
            }
        }
    }
}
