//
//  ViewController.swift
//  AGLKImageZoom
//
//  Created by Richard Clements on 28/08/2015.
//  Copyright (c) 2015 rclements. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    let imageView = AGLKImageView(frame: CGRectZero, image: UIImage(named: "sampleImage.jpg")!)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(imageView)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        imageView.frame = CGRect(origin: CGPointZero, size: view.bounds.size)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

