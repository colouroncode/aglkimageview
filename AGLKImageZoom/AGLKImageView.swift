//
//  AGLKImageView.swift
//  ImageZoom
//
//  Created by Richard Clements on 26/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import GLKit

enum AGLKPanningDirection: Int {
    case Up, Down, Left, Right
}

protocol AGLKImageViewPanningDelegate: NSObjectProtocol {
    
    func aglkImageView(imageView: AGLKImageView, shouldPanInDirection direction: AGLKPanningDirection) -> Bool
    
}

class AGLKImageView: GLKView, UIGestureRecognizerDelegate {
    
    private let callerID = NSUUID().UUIDString
    weak var panningDelegate: AGLKImageViewPanningDelegate?
    
    //MARK: OpenGL Data
    
    private var vertices = [
        SceneVertex(positionCoords: GLKVector3Make(-1, -1, 0), textureCoords: GLKVector2Make(0, 0)),
        SceneVertex(positionCoords: GLKVector3Make(1, -1, 0), textureCoords: GLKVector2Make(1, 0)),
        SceneVertex(positionCoords: GLKVector3Make(-1, 1, 0), textureCoords: GLKVector2Make(0, 1)),
        SceneVertex(positionCoords: GLKVector3Make(1, -1, 0), textureCoords: GLKVector2Make(1, 0)),
        SceneVertex(positionCoords: GLKVector3Make(-1, 1, 0), textureCoords: GLKVector2Make(0, 1)),
        SceneVertex(positionCoords: GLKVector3Make(1, 1, 0), textureCoords: GLKVector2Make(1, 1))
    ]

    private let baseEffect = GLKBaseEffect()
    private var attribArrayBuffer: AGLKVertexAttribArrayBuffer!
    
    private var textureInfo0: GLKTextureInfo! {
        didSet {
            if let oldValue = oldValue {
                var name = oldValue.name
                glDeleteTextures(1, &name)
            }
        }
    }
    
    private var asyncTextureLoader: GLKTextureLoader!
    
    //MARK: Image Rendering
    
    private let imageRenderer: AGLKImageRenderer
    
    var image: UIImage {
        get {
            return imageRenderer.image
        }
        set {
            imageRef0 = nil
            imageRenderer.image = newValue
            setNeedsLayout()
        }
    }
    
    private var imageRef0: CGImageRef! {
        didSet {
            if oldValue != nil {
                if CGImageGetWidth(oldValue) == CGImageGetWidth(imageRef0) && CGImageGetHeight(oldValue) == CGImageGetHeight(imageRef0) {
                    return
                }
            }
            
            asyncTextureLoader.textureWithCGImage(imageRef0, options: [GLKTextureLoaderOriginBottomLeft: true], queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
                [unowned self] textureInfo, error in
                dispatch_async(dispatch_get_main_queue()) {
                    if textureInfo != nil {
                        self.textureInfo0 = textureInfo
                        self.setNeedsDisplay()
                    }
                }
            }
        }
    }
    
    //MARK: Gestures
    
    let pinchGesture: UIPinchGestureRecognizer
    let panGesture: UIPanGestureRecognizer
    let doubleTapGesture: UITapGestureRecognizer
    
    //MARK: Transformations
    
    private var translatemt = GLKMatrix4Identity
    private var scalemt = GLKMatrix4Identity
    private var shouldOnlyApplyScaleMT = false
    private var shouldUpdateMVC = true
    
    //MARK: Animation
    
    private var imageBounds = CGRectZero
    var maxScale = Float(5)
    var minScale = Float(1)
    private var previousScale = Float(1)
    
    private var startingTransform = GLKMatrix4Identity
    private var toTransform = GLKMatrix4Identity
    private var displayLink: CADisplayLink? {
        didSet {
            oldValue?.invalidate()
            displayLink?.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
            displayLink?.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: UITrackingRunLoopMode)
        }
    }
    private var startTime: CFTimeInterval? {
        didSet {
            if startTime != nil {
                displayLink = CADisplayLink(target: self, selector: "update:")
            }
            if startTime == nil {
                animationDuration = 0.3
                displayLink = nil
            }
        }
    }
    private var animationDuration: CFTimeInterval = 0.3
    
    //MARK:- Initialisers
    
    init(frame: CGRect, image: UIImage) {
        let context = AGLKContext(API: EAGLRenderingAPI.OpenGLES2)
        imageRenderer = AGLKImageRenderer(image: image)
        
        pinchGesture = UIPinchGestureRecognizer()
        panGesture = UIPanGestureRecognizer()
        doubleTapGesture = UITapGestureRecognizer()
        doubleTapGesture.numberOfTapsRequired = 2
        
        super.init(frame: frame, context: context)
        
        setUpView()
    }
    
    override init(frame: CGRect) {
        let context = AGLKContext(API: EAGLRenderingAPI.OpenGLES2)
        imageRenderer = AGLKImageRenderer()
        
        pinchGesture = UIPinchGestureRecognizer()
        panGesture = UIPanGestureRecognizer()
        doubleTapGesture = UITapGestureRecognizer()
        doubleTapGesture.numberOfTapsRequired = 2
        
        super.init(frame: frame, context: context)
        
        setUpView()
    }
    
    required init(coder aDecoder: NSCoder) {
        imageRenderer = AGLKImageRenderer(image: aDecoder.decodeObjectForKey("image") as! UIImage)
        pinchGesture = UIPinchGestureRecognizer()
        panGesture = UIPanGestureRecognizer()
        doubleTapGesture = UITapGestureRecognizer()
        doubleTapGesture.numberOfTapsRequired = 2
        super.init(frame: CGRectZero)
        setUpView()
    }
    
    private func setUpView() {
        AGLKContext.setCurrentContext(context)
        
        baseEffect.useConstantColor = GLboolean(GL_TRUE)
        baseEffect.constantColor = GLKVector4Make(1, 1, 1, 1)
        
        if let context = context as? AGLKContext {
            context.clearColor = GLKVector4Make(0, 0, 0, 1)
        }
        
        asyncTextureLoader = GLKTextureLoader(sharegroup: context.sharegroup)
        
        let size = sizeof(SceneVertex)*vertices.count
        
        attribArrayBuffer = AGLKVertexAttribArrayBuffer(attribStride: GLsizei(sizeof(SceneVertex)), numberOfVertices: GLsizei(sizeOfArray(vertices) / sizeof(SceneVertex)), data: vertices, usage: GLenum(GL_STATIC_DRAW))
        
        textureInfo0 = GLKTextureLoader.textureWithCGImage(imageRef0, options: [GLKTextureLoaderOriginBottomLeft: true], error: nil)
        
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        
        pinchGesture.addTarget(self, action: "handlePinchGesture:")
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)
        
        panGesture.addTarget(self, action: "handlePanGesture:")
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        doubleTapGesture.addTarget(self, action: "handleDoubleTapGesture:")
        doubleTapGesture.delegate = self
        addGestureRecognizer(doubleTapGesture)
    }
    
    override func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(imageRenderer.image, forKey: "image")
    }
    
    //MARK:- Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if imageRenderer.image == nil {
            return
        }
        
        imageRenderer.renderImage(previousScale, boundarySize: bounds.size, callerID: callerID) {
            [unowned self] in
            self.imageRef0 = $0
        }
        let (adjustedWidth, adjustedHeight) = imageRenderer.adjustedSizeForSize(bounds.size)
        
        vertices = [
            SceneVertex(positionCoords: GLKVector3Make(-adjustedWidth, -adjustedHeight, 0), textureCoords: GLKVector2Make(0, 0)),
            SceneVertex(positionCoords: GLKVector3Make(adjustedWidth, -adjustedHeight, 0), textureCoords: GLKVector2Make(1, 0)),
            SceneVertex(positionCoords: GLKVector3Make(-adjustedWidth, adjustedHeight, 0), textureCoords: GLKVector2Make(0, 1)),
            SceneVertex(positionCoords: GLKVector3Make(adjustedWidth, -adjustedHeight, 0), textureCoords: GLKVector2Make(1, 0)),
            SceneVertex(positionCoords: GLKVector3Make(-adjustedWidth, adjustedHeight, 0), textureCoords: GLKVector2Make(0, 1)),
            SceneVertex(positionCoords: GLKVector3Make(adjustedWidth, adjustedHeight, 0), textureCoords: GLKVector2Make(1, 1))
        ]
        
        imageBounds = CGRect(x: -CGFloat(adjustedWidth), y: CGFloat(-adjustedHeight), width: CGFloat(adjustedWidth*2), height: CGFloat(adjustedHeight*2))
        
        attribArrayBuffer.reinit(stride: GLsizei(sizeof(SceneVertex)), numberOfVertices: GLsizei(sizeOfArray(vertices) / sizeof(SceneVertex)), data: vertices)
        
        checkBoundsAreCorrect()
        setNeedsDisplay()
    }
    
    override func willMoveToSuperview(newSuperview: UIView?) {
        AGLKViewListener.getInstance.listeners.insert(self)
        if newSuperview == nil {
            deleteDrawable()
        }
    }
    
    //MARK: Gestures
    
    @objc private func handlePinchGesture(gesture: UIPinchGestureRecognizer) {
        startTime = nil
        translatemt = GLKMatrix4Identity
        var locationInView = gesture.locationInView(self)
        locationInView = CGPointMake((locationInView.x/bounds.size.width)*2-1, (locationInView.y/bounds.size.height)*2-1)
        
        switch gesture.state {
            
        case .Began, .Changed:
            scale(locationInView, amount: gesture.scale)
            if baseEffect.transform.modelviewMatrix.scale <= maxScale {
                toTransform = baseEffect.transform.modelviewMatrix
            }
            gesture.scale = 1
            
        case .Ended, .Cancelled, .Failed:
            if baseEffect.transform.modelviewMatrix.scale > maxScale {
                startingTransform = baseEffect.transform.modelviewMatrix
                startTime = CACurrentMediaTime()
            } else if baseEffect.transform.modelviewMatrix.scale < minScale {
                startingTransform = baseEffect.transform.modelviewMatrix
                toTransform = GLKMatrix4Identity
                startTime = CACurrentMediaTime()
            } else {
                checkBoundsAreCorrect()
            }
            
        default:
            "Do nothing"
        }
    }
    
    @objc private func handleDoubleTapGesture(gesture: UITapGestureRecognizer) {
        scalemt = GLKMatrix4Identity
        translatemt = GLKMatrix4Identity
        startTime = nil
        if baseEffect.transform.modelviewMatrix.scale > 1 {
            startingTransform = baseEffect.transform.modelviewMatrix
            toTransform = GLKMatrix4Identity
            startTime = CACurrentMediaTime()
        } else {
            var locationInView = gesture.locationInView(self)
            locationInView = CGPointMake((locationInView.x/bounds.size.width)*2-1, (locationInView.y/bounds.size.height)*2-1)
            startingTransform = baseEffect.transform.modelviewMatrix
            toTransform = GLKMatrix4Translate(GLKMatrix4Identity, Float(locationInView.x), -Float(locationInView.y), 0.0)
            toTransform = GLKMatrix4Scale(toTransform, 2, 2, 1.0)
            toTransform = GLKMatrix4Translate(toTransform, -Float(locationInView.x), Float(locationInView.y), 0.0)
            checkFinalPositionForAnimation()
            startTime = CACurrentMediaTime()
        }
    }
    
    @objc private func handlePanGesture(gesture: UIPanGestureRecognizer) {
        startTime = nil
        scalemt = GLKMatrix4Identity
        switch gesture.state {
            
        case .Began:
            toTransform = baseEffect.transform.modelviewMatrix
            fallthrough
            
        case .Changed, .Began:
            var translation = gesture.translationInView(self)
            translation.x /= bounds.width/2
            translation.y /= bounds.height/2
            
            translate(translation)
            gesture.setTranslation(CGPointZero, inView: self)
            
        case .Ended:
            var velocity = gesture.velocityInView(self)
            velocity.x /= bounds.width*5
            velocity.y /= bounds.height*5
            
            let zoomRect = zoomRectTransformation(baseEffect.transform.modelviewMatrix)
            
            let time = Float(0.2)
            
            let xMovement = Float(zoomRect.minX) - distanceTravelled(Float(velocity.x), -Float(abs(velocity.x))/time, time)
            let yMovement = Float(zoomRect.minY) - distanceTravelled(Float(velocity.y), -Float(abs(velocity.x))/time, time)
            
            let scale = baseEffect.transform.modelviewMatrix.scale
            
            let translationX = -(2*xMovement/Float(zoomRect.width)+1)
            let translationY = 2*yMovement/Float(zoomRect.width)+1
            
            startingTransform = baseEffect.transform.modelviewMatrix
            toTransform = GLKMatrix4Make(scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, translationX, translationY, 0, 1)
            checkFinalPositionForPanAnimation()
            animationDuration = Double(time)
            startTime = CACurrentMediaTime()
            
        default:
            break
        }
    }
    
    //MARK: Zoom Ammendments
    
    private struct AGLKAdjustedOrigin {
        var minX = Float(0)
        var minY = Float(0)
    }
    
    private struct AGLKOverflow {
        var horizontal = Float(0)
        var vertical = Float(0)
    }
    
    private func calculateOverflow(transformation: GLKMatrix4) -> (adjustedOrigin: AGLKAdjustedOrigin, overflow: AGLKOverflow) {
        let zoomRect = zoomRectTransformation(transformation)
        var minX = Float(zoomRect.minX)
        var minY = Float(zoomRect.minY)
        let zoomRectWidth = Float(zoomRect.width)
        let zoomRectHeight = Float(zoomRect.height)
        
        let imageBoundsMinX = Float(imageBounds.minX)
        let imageBoundsMaxX = Float(imageBounds.maxX)
        let imageBoundsMinY = Float(imageBounds.minY)
        let imageBoundsMaxY = Float(imageBounds.maxY)
        let imageBoundsWidth = Float(imageBounds.width)
        let imageBoundsHeight = Float(imageBounds.height)
        
        let scale = transformation.scale
        
        let widthOffset = (zoomRectWidth - imageBoundsWidth)/2
        let heightOffset = (zoomRectHeight - imageBoundsHeight)/2
        
        var overflow = AGLKOverflow(horizontal: 0, vertical: 0)
        var adjustedOrigin = AGLKAdjustedOrigin(minX: minX, minY: minY)
        
        if widthOffset < 0 {
            if minX < imageBoundsMinX {
                overflow.horizontal = minX - imageBoundsMinX
                minX = imageBoundsMinX
            } else if minX + zoomRectWidth > imageBoundsMaxX {
                overflow.horizontal = -(imageBoundsMaxX - (minX + zoomRectWidth))
                minX = imageBoundsMaxX - zoomRectWidth
            }
        } else {
            if minX < imageBoundsMinX-widthOffset {
                overflow.horizontal = minX - imageBoundsMinX + widthOffset
                minX = imageBoundsMinX-widthOffset
            } else if minX + zoomRectWidth > imageBoundsMaxX + widthOffset {
                overflow.horizontal = -(imageBoundsMaxX + widthOffset - (minX + zoomRectWidth))
                minX = imageBoundsMinX-widthOffset
            }
        }
        
        
        if heightOffset < 0 {
            if minY < imageBoundsMinY {
                overflow.vertical = minY - imageBoundsMinY
                minY = imageBoundsMinY
            } else if minY + zoomRectHeight > imageBoundsMaxY {
                overflow.vertical = minY + zoomRectHeight - imageBoundsMaxY
                minY = imageBoundsMaxY-zoomRectHeight
            }
        } else {
            if minY < imageBoundsMinY-heightOffset {
                overflow.vertical = minY - imageBoundsMinY+heightOffset
                minY = imageBoundsMinY - heightOffset
            } else if minY + zoomRectHeight > imageBoundsMaxY + heightOffset {
                overflow.vertical = minY + zoomRectHeight - imageBoundsMaxY - heightOffset
                minY = imageBoundsMinY - heightOffset
            }
        }
        
        adjustedOrigin.minX = minX
        adjustedOrigin.minY = minY
        return (adjustedOrigin: adjustedOrigin, overflow: overflow)
    }
    
    private func adjustedTransformForTransform(transformation: GLKMatrix4, allowOverflow: Bool) -> GLKMatrix4 {
        
        let zoomRect = zoomRectTransformation(transformation)
        let scale = transformation.scale
        
        let (adjustedOrigin, overflow) = calculateOverflow(transformation)
        
        let minX: Float
        if allowOverflow {
            minX = adjustedOrigin.minX + ammendedOverflow(overflow.horizontal)
        } else {
            minX = adjustedOrigin.minX
        }
        
        let minY: Float
        if allowOverflow {
            minY = adjustedOrigin.minY + ammendedOverflow(overflow.vertical)
        } else {
            minY = adjustedOrigin.minY
        }
        
        let translationX = -(2*minX/Float(zoomRect.width)+1)
        let translationY = 2*minY/Float(zoomRect.width)+1
        
        return GLKMatrix4Make(scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, translationX, translationY, 0, 1)
    }
    
    private func checkFinalPositionForAnimation() {
        startingTransform = baseEffect.transform.modelviewMatrix
        toTransform = adjustedTransformForTransform(toTransform, allowOverflow: false)
    }
    
    private func checkFinalPositionForPinch() {
        baseEffect.transform.modelviewMatrix = adjustedTransformForTransform(baseEffect.transform.modelviewMatrix, allowOverflow: false)
        shouldUpdateMVC = false
    }
    
    private func checkFinalPositionForPan() {
        baseEffect.transform.modelviewMatrix = adjustedTransformForTransform(baseEffect.transform.modelviewMatrix, allowOverflow: true)
        shouldUpdateMVC = false
    }
    
    private func checkFinalPositionForPanAnimation() {
        startingTransform = baseEffect.transform.modelviewMatrix
        toTransform = adjustedTransformForTransform(toTransform, allowOverflow: false)
    }
    
    private func checkBoundsAreCorrect() {
        startingTransform = baseEffect.transform.modelviewMatrix
        toTransform = adjustedTransformForTransform(startingTransform, allowOverflow: false)
        if toTransform != startingTransform {
            startTime = CACurrentMediaTime()
        }
    }
    
    //MARK: Gesture Delegates
    
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panningDelegate = panningDelegate {
            if gestureRecognizer == panGesture {
                let velocity = panGesture.velocityInView(self)
                let zoomRect = zoomRectTransformation(baseEffect.transform.modelviewMatrix)
                
                if abs(velocity.x) > abs(velocity.y) {
                    if velocity.x < 0 {
                        if zoomRect.maxX >= imageBounds.maxX {
                            return panningDelegate.aglkImageView(self, shouldPanInDirection: .Left)
                        }
                    } else {
                        if zoomRect.minX <= imageBounds.minX {
                            return panningDelegate.aglkImageView(self, shouldPanInDirection: .Right)
                        }
                    }
                } else if abs(velocity.y) > abs(velocity.x) {
                    if velocity.y < 0 {
                        if zoomRect.maxY >= imageBounds.maxY {
                            return panningDelegate.aglkImageView(self, shouldPanInDirection: .Up)
                        }
                    } else {
                        if zoomRect.minY <= imageBounds.minY {
                            return panningDelegate.aglkImageView(self, shouldPanInDirection: .Down)
                        }
                    }
                } else if velocity.x == 0 {
                    return true
                } else {
                    
                }
            }
        }
        
        return true
    }
    
    //MARK: Current Position Calculation
    
    func zoomRectTransformation(transformation: GLKMatrix4) -> CGRect {
        let translation = transformation.translation
        let translationX = CGFloat(translation.x)
        let translationY = CGFloat(translation.y)
        let width: CGFloat = 2/CGFloat(transformation.scale)
        
        return CGRect(origin: CGPoint(x: -(width/2)*(translationX+1), y: (width/2)*(translationY-1)), size: CGSize(width: width, height: width))
    }
    
    //MARK:- Transformations
    
    private func scale(location: CGPoint, amount: CGFloat) {
        scalemt = GLKMatrix4Translate(GLKMatrix4Identity, Float(location.x), -Float(location.y), 0.0)
        scalemt = GLKMatrix4Scale(scalemt, Float(amount), Float(amount), 1.0)
        scalemt = GLKMatrix4Translate(scalemt, -Float(location.x), Float(location.y), 0.0)
        let modelviewMatrix = baseEffect.transform.modelviewMatrix
        var newModelviewMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(translatemt, scalemt), modelviewMatrix)
        baseEffect.transform.modelviewMatrix = newModelviewMatrix
        checkFinalPositionForPinch()
        setNeedsDisplay()
    }
    
    private func translate(location: CGPoint) {
        translatemt = GLKMatrix4Translate(GLKMatrix4Identity, Float(location.x), -Float(location.y), 0)
        let modelviewMatrix = toTransform
        var newModelviewMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(translatemt, scalemt), modelviewMatrix)
        toTransform = newModelviewMatrix
        baseEffect.transform.modelviewMatrix = newModelviewMatrix
        checkFinalPositionForPan()
        setNeedsDisplay()
    }
    
    func reset() {
        baseEffect.transform.modelviewMatrix = GLKMatrix4Identity
        shouldUpdateMVC = false
        setNeedsLayout()
        setNeedsDisplay()
    }
    
    //MARK: Animation
    
    private func transitionValue(fromValue: Float, toValue: Float, duration: NSTimeInterval, currentTime: CFTimeInterval) -> Float {
        return Float(animationCurve(Double(fromValue), Double(toValue), currentTime, duration))
    }
    
    @objc private func update(displayLink: CADisplayLink) {
        setNeedsDisplay()
    }
    
    //MARK: Image Rendering
    
    private func updateImageScale() {
        let currentScale = max(min(floor(baseEffect.transform.modelviewMatrix.scale), maxScale-1), minScale)
        if currentScale != previousScale {
            previousScale = currentScale
            imageRenderer.renderImage(floor(currentScale), boundarySize: bounds.size, callerID: callerID) {
                [unowned self] in
                self.imageRef0 = $0
            }
        }
    }
    
    //MARK:- Drawing
    
    override func drawRect(rect: CGRect) {
        if imageRef0 == nil {
            return
        }
        if let startTime = startTime {
            let currentTime = CACurrentMediaTime()-startTime
            scalemt = GLKMatrix4Make(transitionValue(startingTransform.m00, toValue: toTransform.m00, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m01, toValue: toTransform.m01, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m02, toValue: toTransform.m02, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m03, toValue: toTransform.m03, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m10, toValue: toTransform.m10, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m11, toValue: toTransform.m11, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m12, toValue: toTransform.m12, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m13, toValue: toTransform.m13, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m20, toValue: toTransform.m20, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m21, toValue: toTransform.m21, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m22, toValue: toTransform.m22, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m23, toValue: toTransform.m23, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m30, toValue: toTransform.m30, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m31, toValue: toTransform.m31, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m32, toValue: toTransform.m32, duration: animationDuration, currentTime: currentTime), transitionValue(startingTransform.m33, toValue: toTransform.m33, duration: animationDuration, currentTime: currentTime))
            if currentTime >= animationDuration {
                scalemt = toTransform
                self.startTime = nil
                baseEffect.transform.modelviewMatrix = scalemt
                checkBoundsAreCorrect()
            }
            shouldOnlyApplyScaleMT = true
        }
        
        updateImageScale()
        
        clearContext()
        attribArrayBuffer.prepareToDrawWithAttrib(GLuint(GLKVertexAttrib.Position.rawValue), numberOfCoordinates: 3, attribOffset: 0, shouldEnable: true)
        attribArrayBuffer.prepareToDrawWithAttrib(GLuint(GLKVertexAttrib.TexCoord0.rawValue), numberOfCoordinates: 2, attribOffset: sizeof(SceneVertex)-sizeof(GLKVector2), shouldEnable: true)
        
        if textureInfo0 != nil {
            baseEffect.texture2d0.name = textureInfo0.name
            baseEffect.texture2d0.target = GLKTextureTarget(rawValue: textureInfo0.target)!
        }
        
        if shouldOnlyApplyScaleMT {
            baseEffect.transform.modelviewMatrix = scalemt
            scalemt = GLKMatrix4Identity
            shouldOnlyApplyScaleMT = false
        } else if shouldUpdateMVC {
            let modelviewMatrix = baseEffect.transform.modelviewMatrix
            var newModelviewMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(translatemt, scalemt), modelviewMatrix)
            baseEffect.transform.modelviewMatrix = newModelviewMatrix
        } else {
            shouldUpdateMVC = true
        }
        
        baseEffect.prepareToDraw()
        attribArrayBuffer.drawArrayWithMode(GLenum(GL_TRIANGLES), startVertexIndex: 0, numberOfVertices: GLsizei(vertices.count))
    }
    
    func clearContext() {
        if let context = context as? AGLKContext {
            context.clear(GLbitfield(GL_COLOR_BUFFER_BIT))
        }
    }
    
    override func deleteDrawable() {
        super.deleteDrawable()
        imageRenderer.deleteCache()
    }
}
