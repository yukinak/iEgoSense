//
//  ViewController.swift
//  iEgoSense
//
//  Created by @yukinak on 7/5/15.
//  Copyright (c) 2015 @yukinak. All rights reserved.
//

import UIKit
import CoreMotion
import AVFoundation
import AssetsLibrary
import HealthKit
import CoreLocation
import Photos.PHPhotoLibrary

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, CLLocationManagerDelegate {
	
	// UI handle
	@IBOutlet weak var h_Video: UIView!
	@IBOutlet weak var h_RecButton: UIButton!
	@IBOutlet weak var h_FetchButton: UIButton!
	@IBOutlet weak var h_RecTime: UILabel!
	@IBOutlet weak var h_AccX: UILabel!
	@IBOutlet weak var h_AccY: UILabel!
	@IBOutlet weak var h_AccZ: UILabel!
	@IBOutlet weak var h_Attitude: UILabel!
	@IBOutlet weak var h_GPSLat: UILabel!
	@IBOutlet weak var h_GPSLon: UILabel!
	@IBOutlet weak var h_HeartRate: UILabel!
	@IBOutlet weak var h_Activity: UILabel!
	
	// parameter
	private var SAMPLNG_ACC_HZ: Double = 30.0   // Hz
	private var SAMPLNG_GYRO_HZ: Double = 30.0	// Hz
	private var SAMPLNG_HR_HZ: Double = 1.0		// Hz
	private var FETCH_HR_DURATION_MIN = -240	// query range for fetching HR data [min]
	
	// Rec-Stop flg
	private var recFlg: Bool = false
	private var existCSV: Bool = false
	private var existHRCSV: Bool = false
	private var recTimer: NSTimer = NSTimer()
	private var dumpTimer: NSTimer = NSTimer()
	private var HRTimer: NSTimer = NSTimer()
	private var countNum = 0
	
	// Outut variables
	private var fileName: String = String()
	private var outHR: String = "NaN"
	private var outAccX: Double = 0.0
	private var outAccY: Double = 0.0
	private var outAccZ: Double = 0.0
	private var outGyroX: Double = 0.0
	private var outGyroY: Double = 0.0
	private var outGyroZ: Double = 0.0
	private var outRoll: Double = 0.0
	private var outPitch: Double = 0.0
	private var outYaw: Double = 0.0
	private var outAlt: Double = 0.0
	private var outLat: Double = 0.0
	private var outLon: Double = 0.0
	private var outActivity: String = "NaN"
	
	// Video
	private var videoOutput: AVCaptureMovieFileOutput!
	private var myVideoLayer : AVCaptureVideoPreviewLayer!
	private var mngAVSession: AVCaptureSession = AVCaptureSession()		// I/O Session
	private var tapGesture: UITapGestureRecognizer = UITapGestureRecognizer()
	
	// Motion Sensor
	private var mngMotion: CMMotionManager!
	private var mngGyro: CMMotionManager!
	private var mngAtd: CMMotionManager!
	private var mngActivity: CMMotionActivityManager?
	private let mngAltimeter = CMAltimeter()
	
	// Location
	var myLocationManager:CLLocationManager!
	
	// HR Monitor
	private var healthStore: HKHealthStore = HKHealthStore()
	
	// HR Query
	let HRQuantitiType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)! // Reading type
	lazy var types: Set<HKObjectType> = {
		return [self.HRQuantitiType]
	}()
	
	/**
	 Start function, calls the first once
	*/
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Heart rate monitor
		initHRMonitor()
		
		// location
		initGPS()
		
		// video
		initVideo()
		
		// accelerometer
		initMotion()
		
		// Gyroscope
		//initGyro()
		
		// Attitude
		//initAttitude()
		
		// activity
		//initActivityMonitor()
		
		// Altimeter
		initAltimeter()
	}
	
	/**
	 viewDidDisappear
	*/
	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)
		//stopObservingHRChanges()
	}
	
	/**
	 Memory handling 
	*/
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}
	
	/**
	 Request authorization to access user's HealthStore
	*/
	private func initHRMonitor(){
		
		healthStore = HKHealthStore()
		
		healthStore.requestAuthorizationToShareTypes(nil, readTypes: types, completion: {
		(success, error) -> Void in
			if success && error==nil {
				//dispatch_async(dispatch_get_main_queue(),self.startObservingHRChanges)
				NSLog("[initHRMonitor] Success!\n")
			} else {
				NSLog("[initHRMonitor] Error!\n")
			}
		})
	}
	
	/**
	 Starting Observation for HR data
	*/
	/*
	func startObservingHRChanges(){
		healthStore.executeQuery(query)
		healthStore.enableBackgroundDeliveryForType(self.HRQuantitiType, frequency: .Immediate, withCompletion: {
			(success: Bool, error: NSError!) in
			if success{
				NSLog("[startObservingHRChanges] Success!\n")
			} else {
				NSLog("[startObservingHRChanges] Error!\n")
			}
		})
	}
	*/
	
	/**
	 Stopping Observation for HR data
	*/
	/*
	func stopObservingHRChanges(){
		healthStore.stopQuery(query)
		healthStore.disableAllBackgroundDeliveryWithCompletion{
			(success: Bool, error: NSError!) in
			if success{
				NSLog("[stopObservingHRChanges] Success!\n")
			} else {
				NSLog("[stopObservingHRChanges] Error!\n")
			}
		}
	}
	*/
	
	/**
	 updateHandler for fetching HR data
	*/
	/*
	lazy var query: HKObserverQuery = {
		return HKObserverQuery(sampleType: self.HRQuantitiType,
		predicate: self.predicate,
		updateHandler: self.heartRateValueHandler)
	}()
	*/
	
	/**
	 updateHandler for fetching HR data
	*/
	/*
	func heartRateValueHandler(_: HKObserverQuery!, completionHandler: HKObserverQueryCompletionHandler!, error: NSError!) {
		readHRData()
		completionHandler()
	}
	*/
	
	/**
	 Reading HealthStore Data
	*/
	private func readHRData() {
		let typeOfHeartRate: HKSampleType = HKSampleType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!
		let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierEndDate, ascending: true)
		
		// query condition
		let predicate: NSPredicate = {
			let calendar: NSCalendar! = NSCalendar.currentCalendar()
			let endTime: NSDate = NSDate()
			let startTime: NSDate = calendar.dateByAddingUnit(NSCalendarUnit.Minute, value: FETCH_HR_DURATION_MIN, toDate: endTime, options: NSCalendarOptions(rawValue: 0))!
			//let startTime = NSCalendar.currentCalendar().dateByAddingUnit(NSCalendarUnit.Day,value: -2, toDate: endTime, options: NSCalendarOptions(rawValue: 0))!
			return HKQuery.predicateForSamplesWithStartDate(startTime, endDate: endTime, options: HKQueryOptions.None)
			
		}()
		
		let mySampleQuery = HKSampleQuery(sampleType: typeOfHeartRate, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: [sortDescriptor])
			{ (sampleQuery, results, error ) -> Void in
			
				let myRecentSample = results!.first as? HKQuantitySample
				
				if myRecentSample != nil {
					
					// Setting unit as BPM
					let count: HKUnit = HKUnit.countUnit()
					let minute: HKUnit = HKUnit.minuteUnit()
					let countParMinute: HKUnit = count.unitMultipliedByUnit(minute.reciprocalUnit())
					let myResentHR = myRecentSample!.quantity.doubleValueForUnit(countParMinute)
					
					dispatch_async(dispatch_get_main_queue(),{
						self.h_HeartRate.text = "heart rate: \(myResentHR)"
						//self.outHR = myResentHR
					})
					
					for var index = 0; index < results!.endIndex; ++index {
							let kSample = results![index] as? HKQuantitySample
							
							// HR
							let count:HKUnit = HKUnit.countUnit()
							let minute:HKUnit = HKUnit.minuteUnit()
							let countParMinute:HKUnit = count.unitMultipliedByUnit(minute.reciprocalUnit())
							let cHR:CDouble = kSample!.quantity.doubleValueForUnit(countParMinute)
							
							// Measured Time
							let dateFormatter = NSDateFormatter()
							dateFormatter.timeZone = NSTimeZone(name: "PST")
							dateFormatter.dateFormat = "yyyy/MM/dd hh:mm:ss:SSS"
							let cTime:String = dateFormatter.stringFromDate(kSample!.startDate)
							
							// stdout
							// print("\(cTime),\(cHR)")
							self.writeHRDataToCSV( cTime, HR: cHR )
					}
					
					// Finish notice by dialog
					self.showCompletionDialog()
					self.existHRCSV = false
					
				} else {
					NSLog("[readHRData] Error!\n")
					self.h_HeartRate.text = "Not found"
				}
		}
		self.healthStore.executeQuery(mySampleQuery)
	}
	
	/** 
	 Writing HR CSV Data into iPhone internal storage
	 Please check the following directory using software such as iExplorer <https://www.macroplant.com/iexplorer/>
	  iPhone/iEgoSense/Documents/yyyyMMdd_HHmmss_HR.csv
	*/
	func writeHRDataToCSV( Time:String, HR:CDouble ) -> Void {
		let docDir = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
		let filePath : String? = "\(docDir)/\(fileName)_HR.csv"
		
		if let outStream = NSOutputStream(toFileAtPath: filePath!, append: true) {
			outStream.open()
			
			// writing header
			if self.existHRCSV == false {
				let headerCSV = "Time,HR\n"
				if let rowData = headerCSV.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
	   				let bytes = UnsafePointer<UInt8>(rowData.bytes)
					outStream.write(bytes, maxLength: rowData.length)
				}
				self.existHRCSV = true
			}
			
			// writing sensor data
			let fileObject = "\(Time),\(HR)\n"
			if let rowData = fileObject.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
	   			let bytes = UnsafePointer<UInt8>(rowData.bytes)
				outStream.write(bytes, maxLength: rowData.length)
			}
			outStream.close()
		}
	}
	
	/** 
	 Showing Completion Dialog
	*/
    internal func showCompletionDialog(){
        let alertController = UIAlertController(title: "Notice!", message: "HR fetched!", preferredStyle: .Alert)
 
    	let defaultAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
	    alertController.addAction(defaultAction)
    	presentViewController(alertController, animated: true, completion: nil)
    }
	
	/** 
	 Caputuring Video 
	*/
	private func initVideo()-> Bool{
		
		var captureDevice: AVCaptureDevice?
		let devices: NSArray = AVCaptureDevice.devices()
		
		// find back camera
		for device: AnyObject in devices {
			if device.position == AVCaptureDevicePosition.Back {
				captureDevice = device as? AVCaptureDevice
			}
		}
		
		if captureDevice == nil {
			NSLog("Missing Camera")
			return false
		}
		
		// init device input
		var deviceInput : AVCaptureInput! = nil
		do {
			deviceInput = try AVCaptureDeviceInput(device: captureDevice) as AVCaptureInput
			captureDevice!.activeVideoMinFrameDuration = CMTimeMake(1, 30)
			
			// Center zoom for fisheye lens
			//var initialZoom = captureDevice!.videoZoomFactor
			//captureDevice!.videoZoomFactor = CGFloat(2)

		} catch let error as NSError {
			print(error)
		}
		
		
		// audio
		/*
		do {
			let audioDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
			let audioInput = try AVCaptureDeviceInput(device: audioDevice)
			self.mngAVSession.addInput(audioInput)
			} catch {
				fatalError("Could not load capture device")
			}
		*/

		// init session
		self.videoOutput = AVCaptureMovieFileOutput()
		self.mngAVSession = AVCaptureSession()
		self.mngAVSession.addInput(deviceInput as AVCaptureInput)
		self.mngAVSession.addOutput(self.videoOutput)
		//self.mngAVSession.sessionPreset = AVCaptureSessionPreset640x480		// VGA
		//self.mngAVSession.sessionPreset = AVCaptureSessionPresetiFrame960x540	// qHD
		self.mngAVSession.sessionPreset = AVCaptureSessionPreset1280x720		// 720p
		
		// orientation change
		startOrientationChangeObserver()
		
		return true
	}
	
	/** 
	 reinit Video
	*/
	private func reinitVideo(){
	
		// Stopping AV session
		self.mngAVSession.stopRunning()

		// preview layer
		self.myVideoLayer = AVCaptureVideoPreviewLayer(session: self.mngAVSession) as AVCaptureVideoPreviewLayer
		
		// Handling device orientation
		let deviceOrientation = UIDevice.currentDevice().orientation
		if deviceOrientation == UIDeviceOrientation.LandscapeLeft {
			self.myVideoLayer.connection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
			self.videoOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = AVCaptureVideoOrientation.LandscapeRight
		}else if  deviceOrientation == UIDeviceOrientation.LandscapeRight{
			self.myVideoLayer.connection.videoOrientation = AVCaptureVideoOrientation.LandscapeLeft
			self.videoOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = AVCaptureVideoOrientation.LandscapeLeft
		}else if  deviceOrientation == UIDeviceOrientation.PortraitUpsideDown{
			self.myVideoLayer.connection.videoOrientation = AVCaptureVideoOrientation.Portrait
			self.videoOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = AVCaptureVideoOrientation.Portrait
		}else if  deviceOrientation == UIDeviceOrientation.Portrait{
			self.myVideoLayer.connection.videoOrientation = AVCaptureVideoOrientation.Portrait
			self.videoOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = AVCaptureVideoOrientation.Portrait
		}else{
			self.myVideoLayer.connection.videoOrientation = AVCaptureVideoOrientation.Portrait
			self.videoOutput.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = AVCaptureVideoOrientation.Portrait
		}
		
		// Video stabilization ON
		/*
		let stab = videoOutput.connectionWithMediaType(AVMediaTypeVideo)?.supportsVideoStabilization
		if ( stab != nil) {
			self.myVideoLayer.connection.preferredVideoStabilizationMode = .Auto
			self.videoOutput.connectionWithMediaType(AVMediaTypeVideo).preferredVideoStabilizationMode = .Auto
		}
		*/
		
		// Tap Gesture ON
		/*
		tapGesture = UITapGestureRecognizer(target: self, action: "tap:")
		self.h_Video.addGestureRecognizer(tapGesture)
		*/
		
		// Adding preview layer to UIView
		self.myVideoLayer.frame = self.view.frame
		self.myVideoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
		self.h_Video.layer.addSublayer(self.myVideoLayer)
		
		// Starting AV session
		self.mngAVSession.startRunning()
	}
	
	/** 
	 Procedure after video capture
	*/
	func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
		
		// Writing a captured video to the photo library
		PHPhotoLibrary.sharedPhotoLibrary().performChanges({
			PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(outputFileURL)
			}, completionHandler: { (success, error) -> Void in
		})
	}
	
	/**
	 Starting Orientation change observar
	*/
	func startOrientationChangeObserver() {
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "onOrientationChange:", name: UIDeviceOrientationDidChangeNotification, object: nil)
	}
	
	/**
	 Stopping Orientation change observar
	*/
	func stopOrientationChangeObserver() {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	/**
	 Device orientation
	*/
	func onOrientationChange(notification: NSNotification){
		reinitVideo()
	}

	/**
	 Activity type
	*/
	/*
	private func initActivityMonitor(){
		
		let manager = CMMotionActivityManager()
		manager.startActivityUpdatesToQueue(NSOperationQueue()) {
		 (activity: CMMotionActivity!) -> Void in
			if activity.stationary{
				self.h_Activity.text = "activity: stationary"
				self.outActivity = "stationary"
			}else if activity.walking {
				self.h_Activity.text = "activity: walikng"
				self.outActivity = "walikng"
			}else if activity.running {
				self.h_Activity.text = "activity: running"
				self.outActivity = "running"
			}else if activity.cycling {
				self.h_Activity.text = "activity: cycling"
				self.outActivity = "cycling"
			}else if activity.automotive{
				self.h_Activity.text = "activity: automotive"
				self.outActivity = "automotive"
			}else if activity.unknown{
				self.h_Activity.text = "activity: unknown"
				self.outActivity = "unknown"
			}else{
				self.h_Activity.text = "activity: NaN"
				self.outActivity = "NaN"
			}
		}
		self.mngActivity = manager
	}
	*/
	
	
	/** 
	 Accelerometer 
	*/
	private func initMotion(){
	
		// Generating MotionManager
		mngMotion = CMMotionManager()
		
		// Setting Sensing Interval
		mngMotion.accelerometerUpdateInterval = 1.0/SAMPLNG_ACC_HZ
		
		// Sensing Acceleration
		mngMotion.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: {
		(accelerometerData:CMAccelerometerData?, error:NSError?) -> Void in
			self.h_AccX.text = String(format: "acc.x: %.3f", accelerometerData!.acceleration.x)
			self.h_AccY.text = String(format: "acc.y: %.3f", accelerometerData!.acceleration.y)
			self.h_AccZ.text = String(format: "acc.z: %.3f", accelerometerData!.acceleration.z)
			
			self.outAccX = accelerometerData!.acceleration.x
			self.outAccY = accelerometerData!.acceleration.y
			self.outAccZ = accelerometerData!.acceleration.z
		})
	}
	
	/**
	 Gyroscope 
	*/
	/*
	private func initGyro(){
	
		// Generating MotionManager
		mngGyro = CMMotionManager()
		
		// Setting Sensing Interval
		mngGyro.gyroUpdateInterval = 1.0/SAMPLNG_GYRO_HZ
		
		// Sensing Gyroscope
		mngGyro.startGyroUpdatesToQueue(NSOperationQueue.currentQueue(), withHandler: {
		(gyroData: CMGyroData!, error: NSError!) in
			self.outGyroX = gyroData.rotationRate.x
			self.outGyroY = gyroData.rotationRate.y
			self.outGyroZ = gyroData.rotationRate.z
		})
	}
	*/
	
	/**
	 Attitude
	*/
	/*
	private func initAttitude(){
	
		// Generating MotionManager
		mngAtd = CMMotionManager()
		
		// Setting Sensing Interval
		mngAtd.deviceMotionUpdateInterval = 1.0/SAMPLNG_GYRO_HZ
		
		// Sensing Altitude
		mngAtd.startDeviceMotionUpdatesToQueue(<#T##queue: NSOperationQueue##NSOperationQueue#>, withHandler: <#T##CMDeviceMotionHandler##CMDeviceMotionHandler##(CMDeviceMotion?, NSError?) -> Void#>)
		
		mngAtd.startDeviceMotionUpdatesToQueue(NSOperationQueue.currentQueue(), withHandler: {
		(deviceManager, error: NSError!) in
			var attitude = deviceManager.attitude
			self.outRoll = attitude.roll
			self.outPitch = attitude.pitch
			self.outYaw = attitude.yaw
		})
	}
	*/
	
	/** 
	 Altimeter 
	*/
	private func initAltimeter(){
		if (CMAltimeter.isRelativeAltitudeAvailable()) {
			mngAltimeter.startRelativeAltitudeUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler:
				{data, error in
					if error == nil {
						self.h_Attitude.text = String(format: "altitude: %.3f", Double(data!.relativeAltitude))
						self.outAlt = Double(data!.relativeAltitude)
					}
				})
		}
	}

	/**
	 GPS
	*/
	private func initGPS(){
		
		myLocationManager = CLLocationManager()
		myLocationManager.delegate = self
		
		// Authorization
		let status = CLLocationManager.authorizationStatus()
		if(status == CLAuthorizationStatus.NotDetermined) {
			self.myLocationManager.requestAlwaysAuthorization()
		}
		
		// Sensing condition
		myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
		myLocationManager.distanceFilter = 2	// 2m step
		myLocationManager.startUpdatingLocation()
	}
	
  	/**
	 calls when obtaining GPS success
	*/
	func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
		self.h_GPSLat.text = String(format: "latitude: %.3f", manager.location!.coordinate.latitude)
		self.h_GPSLon.text = String(format: "longitude: %.3f", manager.location!.coordinate.longitude)
		self.outLat = manager.location!.coordinate.latitude
		self.outLon = manager.location!.coordinate.longitude
	}
	
  	/**
	 calls when obtaining GPS fails
	*/
	func locationManager(manager: CLLocationManager,didFailWithError error: NSError){
		NSLog("[locationManager] Error!\n")
	}

	/** 
	 Writing Sensor CSV Data into iPhone internal storage
	 Please check the following directory using software such as iExplorer <https://www.macroplant.com/iexplorer/>
	  iPhone/iEgoSense/Documents/yyyyMMdd_HHmmss.csv
	*/
	func writeSensorDataToCSV() {
		let docDir = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
		let filePath : String? = "\(docDir)/\(fileName).csv"
		
		if let outStream = NSOutputStream(toFileAtPath: filePath!, append: true) {
			outStream.open()
			
			// writing header
			if existCSV == false {
				let headerCSV = "countNum,Time,Acc_X,Acc_Y,Acc_Z,Gyro_X,Gyro_Y,Gyro_Z,Roll,Pitch,Yaw,Altitude,Lat,Lon,Activity,HR\n"
				if let rowData = headerCSV.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
	   				let bytes = UnsafePointer<UInt8>(rowData.bytes)
					outStream.write(bytes, maxLength: rowData.length)
				}
				existCSV = true
			}
			
			// writing sensor data
			let time = makeExactTimeString()
			let fileObject = "\(countNum),\(time),\(self.outAccX),\(self.outAccY),\(self.outAccZ),\(self.outGyroX),\(self.outGyroY),\(self.outGyroZ),\(self.outRoll),\(self.outPitch),\(self.outYaw),\(self.outAlt),\(self.outLat),\(self.outLon),\(self.outActivity),\(self.outHR)\n"
			if let rowData = fileObject.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
	   			let bytes = UnsafePointer<UInt8>(rowData.bytes)
				outStream.write(bytes, maxLength: rowData.length)
			}
			outStream.close()
		}
	}
	
	/** 
	 Creating File Name
	*/
	func makeExactTimeString() -> String {
		let now = NSDate()
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss:SSS"
		
		return dateFormatter.stringFromDate(now)
	}
	
	/** 
	 Creating File Name
	*/
	func makeFileString() -> String {
		let now = NSDate()
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
		
		return dateFormatter.stringFromDate(now)
	}
	
	/** 
	 Creating Time String
	*/
	func makeTimeString(countNum:Int) -> String {
		let ms = countNum % 100
		let s = (countNum - ms) / 100 % 60
		let m = (countNum - s - ms) / 6000 % 3600
		
		return String(format: "%02d:%02d.%02d", m, s, ms)
	}

	/**
	 UPDATE time counter 
	*/
	func updateRecTime() {
		countNum++
		h_RecTime.text = makeTimeString(countNum)
	}
	
	/** 
	 RESET time counter 
	*/
	func resetRecTime() {
		countNum = 0
		h_RecTime.text = makeTimeString(countNum)
	}
	
	/**
	 Rec Button 
	*/
	@IBAction func onClickRecButton(sender: AnyObject) {
	
		if recFlg == false {
		
			// stopping orientation change observer
			stopOrientationChangeObserver()
			
			// UI update
			recTimer = NSTimer.scheduledTimerWithTimeInterval(
				0.01,
				target: self,
				selector: Selector("updateRecTime"),
				userInfo: nil,
				repeats: true
			)
			recFlg = true
			h_RecButton.setTitle("Stop", forState: .Normal)
			
			// video output
			fileName = makeFileString()
			let docDir = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
			let filePath : String? = "\(docDir)/\(fileName).mp4"
			//let fileURL : NSURL = NSURL(fileURLWithPath: filePath!)!
			let fileURL = NSURL(fileURLWithPath: filePath!)
			videoOutput.startRecordingToOutputFileURL(fileURL, recordingDelegate: self)
			
			// sensor output
			dumpTimer = NSTimer.scheduledTimerWithTimeInterval(
				1.0/SAMPLNG_ACC_HZ,
				target: self,
				selector: Selector("writeSensorDataToCSV"),
				userInfo: nil,
				repeats: true
			)
			
		}else if recFlg == true {
		
			// UI update
			recTimer.invalidate()
			dumpTimer.invalidate()
			resetRecTime()
			recFlg = false
			existCSV = false
			h_RecButton.setTitle("Rec", forState: .Normal)

			// video output
			videoOutput.stopRecording()
			
			// starting orientation change observer
			startOrientationChangeObserver()
		
		}else{
			NSLog("[onClickRecButton] Causion!\n")
		}
	}
	
	/**
	 Fetch Button
	*/
	@IBAction func onClickFetchButton(sender: AnyObject) {
		readHRData()
	}
}
