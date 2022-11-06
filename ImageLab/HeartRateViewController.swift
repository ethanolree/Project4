//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation
import Metal

class HeartRateViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    var isFlashOn = false;
    var redValues: [Float] = []
    
    //MARK: Outlets in view
    @IBOutlet weak var flashSlider: UISlider!
    @IBOutlet weak var stageLabel: UILabel!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var graphView: UIView!
    @IBOutlet weak var flashButton: UIButton!
    
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.graphView)
    }()
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.bridge.redArray = NSMutableArray(array: [Float](repeating: 0, count: 450))
        //Put graph on top of camera
        //self.graphView.superview?.bringSubviewToFront(graphView)
        // Set up graph
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            // add in graphs for display
            graph.addGraph(withName: "heartGraph",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: 450)
                
            graph.makeGrids() // add grids to graph
        }
        
        // setup the OpenCV bridge nose detector, from file
        self.bridge.loadHaarCascade(withFilename: "nose")
        
        self.videoManager = VideoAnalgesic(mainView: self.view)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        
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
    
    // periodically, update the graph with refreshed FFT Data
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: redValues,
            forKey: "heartGraph"
        )
    }
    
    //MARK: Process image output
    func processImageSwift(inputImage:CIImage) -> CIImage{
        
        var retImage = inputImage
        
        //-------------------Example 1----------------------------------
        // if you just want to process on separate queue use this code
        // this is a NON BLOCKING CALL, but any changes to the image in OpenCV cannot be displayed real time
        /*
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
            self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
            self.bridge.processImage()
        }
         */
        
        //-------------------Example 2----------------------------------
        // use this code if you are using OpenCV and want to overwrite the displayed image via OpenCV
        // this is a BLOCKING CALL
        
        // FOR FLIPPED ASSIGNMENT, YOU MAY BE INTERESTED IN THIS EXAMPLE
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage, withBounds: CGRect(origin: CGPointMake(50, 0), size: retImage.extent.size), andContext: self.videoManager.getCIContext())
        
        if (self.bridge.processFinger(isFlashOn)) {
            DispatchQueue.main.async {
                self.redValues = (self.bridge.redArray as NSArray).map({ ($0 as! NSNumber).floatValue });
                self.updateGraph();
                self.cameraButton.isEnabled = false;
                self.flashButton.isEnabled = false;
                self.videoManager.turnOnFlashwithLevel(0.5);
                self.isFlashOn = true;
            }
        } else {
            DispatchQueue.main.async {
                self.cameraButton.isEnabled = true;
                self.flashButton.isEnabled = true;
                self.videoManager.turnOffFlash();
                self.isFlashOn = false;
            }
        }
        retImage = self.bridge.getImage()
        
        
        //-------------------Example 3----------------------------------
        //You can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        
        return retImage
    }
    
    //MARK: Setup Face Detection
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
    }
    
    
    // change the type of processing done in OpenCV
    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            self.bridge.processType += 1
        case .right:
            self.bridge.processType -= 1
        default:
            break
            
        }
        
        stageLabel.text = "Stage: \(self.bridge.processType)"

    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        if(self.videoManager.toggleFlash()){
            self.flashSlider.value = 1.0
        }
        else{
            self.flashSlider.value = 0.0
        }
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }
    
    @IBAction func setFlashLevel(_ sender: UISlider) {
        if(sender.value>0.0){
            let val = self.videoManager.turnOnFlashwithLevel(sender.value)
            if val {
                print("Flash return, no errors.")
            }
        }
        else if(sender.value==0.0){
            self.videoManager.turnOffFlash()
        }
    }

   
}

