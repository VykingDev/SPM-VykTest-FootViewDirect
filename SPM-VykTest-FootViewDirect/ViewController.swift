//
//  ViewController.swift
//  SPM-VykTest-FootViewDirect
//
//  Created by Chris on 09/04/2021.
//

import UIKit
import VykViewKit
import Photos

typealias VykingTrackerConfig = [String : Any]

enum ConstantsForVykingTracker {
  static let vykingTrackerInitConfig: VykingTrackerConfig = [
      "baseDir"   : Bundle.main.bundlePath + "/Data/Raw/Vyking",   // path to the location of the vykingfile
      "vykingFile": "VykingData99.lzma",                           // the actual name of the vyking lzma file
    ]
  
  static let vykingTrackerAccessConfig: VykingTrackerConfig = [
    "facing"                      : false,                     // rear facing camera logic
    "arKit"                       : false,              // debugarkit 2021-01-13 CK
    "arKitExternalCamera"         : false,   // use external camera frames
    "arKitInternalPlaneDetection" : false, // horizontal, vertical, horizontal_and_vertical or none
    "tracker"                     : "foot",                    // enable the foot tracker
    "config" : [                                               // the upscale texture for the occluder masks
      "textureScale": [
             "width": 540,
            "height": 960,
           "widthAv": 7,
          "heightAv": 7,
          "fusionFactor": 0.6565
      ]
    ]
  ]
  
}


class ViewController: UIViewController, vkFootViewDelegate {
  
  func vkFrameUpdate(frameID: UInt32, leftTransform: simd_float4x4?, rightTransform: simd_float4x4?) {
    // we have a frame update
    // NSLog("vkFrameUpdate frameID \(frameID)")
  }
  

  var RecordingActive    : Bool = false
  
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  @IBOutlet weak var myVykFootView: VykFootView!
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  @IBAction func Activate(_ sender: UIButton) {
    
    NSLog("Activate Button ...")
    
    sender.backgroundColor = .red
    
    // remove the reference to the footview
    if mVykFootViewActive {
      // we are going to stop the foot tracking and destroy the view
      
      // we have a problem if we destroy the foot tracking on the direct view because the sceneview within the vykfootview is
      // deallocated as soon as destroyFootTracking is called
      // so if we are using the vkyfootview creted by the layout system we should not destroy it
      #if false
      myVykFootView?.destroyFootTracking()  // this will not return until the sdk has been shutdown
      #else
      // test the pause/start foot tracking
      myVykFootView?.pauseFootTracking()
      NSLog("ViewController.swift: VKactivated ---> pauseFootTracking")
      #endif
    } else {
      #if false
      // myVykFootView = VykFootView(frame: myVykFootView.frame)
      
      if let mv = myVykFootView {
        
        // initialise the asset loader
        mv.setupAssetLoader(viewController: self,
                            destinationPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path)
        
        // initialise the Foot Tracking
        let rVal = mv.setupFootTracker(initConfig: ConstantsForVykingTracker.vykingTrackerInitConfig,
                            accessConfig: ConstantsForVykingTracker.vykingTrackerAccessConfig,
                            delegate: self )
        
        // autoload load the first shoe (optional)
        if rVal {
          NextShoe(UIButton())
          
          sender.backgroundColor = .green
        } else {
          NSLog("Activate failed setupFootTracker ...")
        }
      
      }
      #else
      // test the pause/start foot tracking
      myVykFootView?.startFootTracking()
      NSLog("ViewController.swift: VKactivated ---> startFootTracking")
      #endif
    }
    
    // toggle the flag
    mVykFootViewActive = !mVykFootViewActive
  }
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  var mHoldViewSize : CGSize? = nil
  var mVykFootViewActive : Bool = true
  var mShoeSelector      : Int = 0
  let mShoeList = [
      // "http://beagle.dc.ccl.cityc:8000/single_model_test/offsets.json",
      "https://vykingsneakerkitnative.s3.amazonaws.com/SneakerStudio/may_android_ios/air_jordan_1_turbo_green/offsets.json",
      "https://vykingsneakerkitnative.s3.amazonaws.com/SneakerStudio/may_android_ios/yeezy_boost_700_carbon_blue/offsets.json",
      "https://vykingsneakerkitnative.s3.amazonaws.com/SneakerStudio/may_android_ios/adidas_yeezy_350_yecheil/offsets.json",
      "https://vykingsneakerkitnative.s3.amazonaws.com/SneakerStudio/may_android_ios/air_jordan_1_fearless_facetasm/offsets.json",
      "https://vykingsneakerkitnative.s3.amazonaws.com/SneakerStudio/may_android_ios/air_jordan_4_travis_scott/offsets.json",
      "https://vykingsneakerkitnative.s3.amazonaws.com/SneakerStudio/may_android_ios/nike_FoG_180_lightbone/offsets.json",
      "https://vykingsneakerkitnative.s3.amazonaws.com/SneakerStudio/may_android_ios/nike_af1_what_the_nyc/offsets.json",
      ]
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  @IBAction func NextShoe(_ sender: UIButton) {
    
    NSLog("NextShoe Button ...")
    
    //    for shoe in mShoeList {
    //      myVykFootView?.loadShoeAsset(urlString: shoe)
    //    }
    
    myVykFootView?.loadShoeAsset(urlString: mShoeList[ mShoeSelector ])
    mShoeSelector = mShoeSelector + 1
    if mShoeSelector == mShoeList.count {
      mShoeSelector = 0;
    }
    
    // test the change view size button
    
    NSLog("NewShoe new view START width \(myVykFootView?.frame.size.width), height \(myVykFootView?.frame.size.height)")

//    sender.frame.size = CGSize(width: 200, height: 200)
    
//    if true || mHoldViewSize == nil {
//      mHoldViewSize = myVykFootView?.frame.size
//      let newSize = CGSize(width: mHoldViewSize!.width / 2, height: mHoldViewSize!.height / 2)
//      myVykFootView?.frame.size = newSize
//    }
//    } else {
//      myVykFootView?.frame.size = mHoldViewSize!
//      mHoldViewSize = nil
//    }
//    
    NSLog("NewShoe new view width \(myVykFootView?.frame.size.width), height \(myVykFootView?.frame.size.height)")
  }
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  @IBAction func Record(_ sender: UIButton) {
    
    NSLog("Record Button ...")
    
    RecordingActive = !RecordingActive
    
    if RecordingActive {
      sender.backgroundColor = .red
      
      let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
      let videoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("MyVideo.mp4"))
      
      // we will just use the default video settings
      myVykFootView?.MTLStreamStartRecording(videoOutputURLWithPath: videoOutputURL, videoSettings: nil )
  
    } else {
      sender.backgroundColor = .lightGray
      
      myVykFootView?.MTLStreamStopRecording(saveVideo: { (videoURL: URL) -> Void in
        // statements
        NSLog("viewController: Time to save the video file \(videoURL)")

        // Now save the video
        #if true
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }) { saved, error in
          
            DispatchQueue.main.async {
              if saved {
                let alertController = UIAlertController(title: "Video was successfully saved", message: nil, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
              }
              if error != nil {
                os_log("Video did not save for reason", error.debugDescription);
                debugPrint(error?.localizedDescription ?? "error is nil");
              }
            }
        }
        #endif
      } )
      
    }
    
  }
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  @IBAction func Snap(_ sender: UIButton) {
    
    NSLog("Snap Button ...")
    
    // take a snapshot of the screen sceneView
    let mySnap = myVykFootView?.snapshot()
    
    NSLog("takeSnapTapped mySnap \(mySnap)")

    if let mySnap = mySnap {
      UIImageWriteToSavedPhotosAlbum(
              mySnap,
              self,
              #selector(ProcessSnapImageSaveResult),
              nil)
    }
    
  }
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  @objc func ProcessSnapImageSaveResult( image                    : UIImage!,
                                   didFinishSavingWithError error :NSError!,
                                  contextInfo                     :UnsafeRawPointer)
  {
    if error == nil {
      NSLog("ProcessSnapImageSaveResult result successful")
      
      let alertController = UIAlertController(title: "Snap shot was successfully saved", message: nil, preferredStyle: .alert)
      let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
      alertController.addAction(defaultAction)
      self.present(alertController, animated: true, completion: nil)
      
    } else {
      NSLog("ProcessSnapImageSaveResult result of Camera Save \(String(describing: error))")
    }
  }
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  
  
  func vkReady(good: Bool) {
    NSLog("vkReady good \(good)");
  }
  
  func vkShutdown(good: Bool) {
    NSLog("vkShutdown good \(good)");
  }
  
  func vkLoadShoeAssetResponse(urlString: String, assetsPath: String?, good: Bool, message: String?) {
    NSLog("vkLoadShoeAssetResponse good \(good)");
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    NSLog("ViewController.swift: myVykFootView \(myVykFootView)")
    NSLog("ViewController.swift: myVykFootView?.accessibilityIdentifier \(myVykFootView?.accessibilityIdentifier)")
    
    // myVykFootView.backgroundColor = UIColor.red
     
    // initialise the asset loader
    myVykFootView.setupAssetLoader(viewController: self,
                                   destinationPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path)
    
    _ = myVykFootView.setupFootTracker(initConfig: ConstantsForVykingTracker.vykingTrackerInitConfig,
                        accessConfig: ConstantsForVykingTracker.vykingTrackerAccessConfig,
                        delegate: self )
    
    // ok lets get the xpiry date
    NSLog("Vyking SDK Expiry is \(myVykFootView.getSDKexpiry())")

    // sample call to show the usage of the foot availability counters
    var nofeet : Int = 0
    var oneFoot : Int = 0
    var twoFeet : Int = 0
    myVykFootView.getFeetAvailabilityCounts(noFeet: &nofeet, oneFoot: &oneFoot, twoFeet: &twoFeet)
    
    // autoload load the first shoe (optional)
    NextShoe(UIButton())
  }
  
  override func viewDidLayoutSubviews() {

    NSLog("ViewController.swift: viewDidLayoutSubviews")
 
    if let mv = myVykFootView {
      
      // the following line is essential otyherwise the vykfootview does not realise that
      // the view has been resized so we set the frame to the original  size once again
      // as we are tracking the frame size in VykFootView
      mv.frame = myVykFootView.frame
      // mv.frame.origin = CGPoint(x: 10, y: 10)
      // mv.backgroundColor = .brown
      mv.viewLayoutChanged()
    }

  }


}


