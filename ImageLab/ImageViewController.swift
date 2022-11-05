//
//  ViewController.swift
//  ImageLab
//
//  Created by Ethan Olree
//  Copyright ©Ethan Olree. All rights reserved.
//

import UIKit
import AVFoundation

class ImageViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    var isFlashOn = false;
    
    //MARK: Outlets in view
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var headPositionLabel: UILabel!
    @IBOutlet weak var flashButton: UIButton!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.videoManager = VideoAnalgesic(mainView: self.view)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.front)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow,CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageSwift)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    }
    
    //MARK: Setup filtering
    func setupFilters(){
        filters = []
        
        // starting values for filter
        let filterPinch = CIFilter(name:"CIBumpDistortion")!
        filterPinch.setValue(-0.5, forKey: "inputScale")
        filterPinch.setValue(75, forKey: "inputRadius")
        filters.append(filterPinch)
        
    }
    
    //MARK: Process image output
    func processImageSwift(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let faces = getFaces(img: inputImage)
        
        // if no faces, just return original image
        if faces.count == 0 { return inputImage }
        
        var retImage = inputImage
        var filterCenter = CGPoint()
        var radius = 75
        var filt: CIFilter
        
        //-------------------Example 3----------------------------------
        //You can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        
        for f in faces {
            filterCenter.x = f.bounds.midX;
            filterCenter.y = f.bounds.midY;
            
            radius = Int(f.bounds.width/4)
            print(filterCenter)
            
            DispatchQueue.main.async {
                self.headPositionLabel.text = "Head Position: \(filterCenter.x), \(filterCenter.y)"
            }
            
            
            if (!f.leftEyeClosed) { // filter if left eye open
                filt = applyFilterToPoint(eyePos: f.leftEyePosition, radius: radius, img: retImage)
                retImage = filt.outputImage!
            }
            
            if (!f.rightEyeClosed) { // filter if right eye open
                filt = applyFilterToPoint(eyePos: f.rightEyePosition, radius: radius, img: retImage)
                retImage = filt.outputImage!
            }
            
            if (!f.hasSmile) { // filter if not smiling
                filt = applyFilterToPoint(eyePos: f.mouthPosition, radius: radius, img: retImage)
                retImage = filt.outputImage!
            }
        }
        
        return retImage
    }
    
    //MARK: Apply point filters
    func applyFilterToPoint(eyePos:CGPoint, radius:Int, img:CIImage) -> CIFilter {
        let filterPinch = CIFilter(name:"CITwirlDistortion")!
        filterPinch.setValue(img, forKey: kCIInputImageKey)
        filterPinch.setValue(10, forKey: "inputAngle")
        filterPinch.setValue(CIVector(cgPoint: eyePos), forKey: "inputCenter")
        filterPinch.setValue(radius, forKey: "inputRadius")
        
        return filterPinch
    }
    
    //MARK: Setup Face Detection
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace:[String : Any] = [CIDetectorSmile : "YES",
                                        CIDetectorEyeBlink : "YES",
                                        CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        self.videoManager.toggleFlash()
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }

   
}

