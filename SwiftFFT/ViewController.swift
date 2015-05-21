//
//  ViewController.swift
//  SwiftFFT
//
//  Created by Linda Cobb on 10/10/14.
//  Copyright (c) 2014 TimesToCome Mobile. All rights reserved.
//


import UIKit
import Accelerate





class ViewController: UIViewController {
    
        
        // output to user
    @IBOutlet var functionLabel: UILabel!
    @IBOutlet var frequencyLabel: UILabel!
    @IBOutlet var calculationLabel:UILabel!
    @IBOutlet var graphView: GraphView!
    @IBOutlet var barGraphView: BarGraphView!
        
    
    // trip wire so we can call stop session on main thread
    var stopUpdates = false
    
    
    // signal
    let pi:Float = 3.1415926
    let maxData = 640
    var inputSignal = [Float](count: 640, repeatedValue: 0.0)

        // fft
    let windowSize = 128
    let windowSizeOverTwo = 64
    let hz = 10   // sample rate 44,100 hz
    
        // get frequencies from data
    var frequency:Float = 0.0
    var max:Float = 0.0
    var imagp = [Float](count: 128, repeatedValue: 0.0)
    var zerosR = [Float](count: 128, repeatedValue: 0.0)
    var zerosI = [Float](count: 128, repeatedValue: 0.0)
        
    var log2n:vDSP_Length!
    var setup : COpaquePointer!
        
        
        // update fft arrays and call after after x loop counts
    let maxArrayPosition = 128 - 1
    let loopCount = 32       // number of data points between fft calls
    var graphLoopCount = 0
    var dataCount = 0
        
        
        
    required init( coder aDecoder: NSCoder ){ super.init(coder: aDecoder) }
    
    convenience override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!){ self.init(nibName: nil, bundle: nil) }
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }
        
        
        
        override func viewDidLoad() {
            
            graphView.setupGraphView()
            barGraphView.setupGraphView()
            
            // set up memory for FFT
            log2n = vDSP_Length(log2(Double(windowSize)))
            setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
            
            createSignal()
        }
        
        
        
    func createSignal (){
        
        var events = 1.0 as Float
        
        // cosine signal
        var signalPeriod = (2.0 * pi)/events;
        var f = 1.0/signalPeriod;
        
        // create a signal 4x the data length
        var step:Float = 1.0/Float(hz);       // how often to sample
        
        
        functionLabel.text = NSString(format:"S: cos(x*\(events) f: \(f) period: \(signalPeriod) hz: \(hz)") as String
        
        for i in 0..<maxData {
            inputSignal[i] = cos(step * Float(i) * events)
            graphView.addX(inputSignal[i])
            processSignal(inputSignal[i])
        }
        
    }
    
        
        
    
    
    
    func processSignal(x: Float) {
        
        // first fill up array
        if  dataCount < windowSize {
            inputSignal[dataCount] = x
            dataCount++
            
            // then pop oldest off top push newest onto end
        }else{
            
            inputSignal.removeAtIndex(0)
            inputSignal.insert(x, atIndex: maxArrayPosition)
        }
        
        
        // call fft?
        if  graphLoopCount > loopCount {
            graphLoopCount = 0;
            FFT()
            
        }else{ graphLoopCount++; }

    }
    

    

        
        
    func FFT() {
            
            // parse data input into complex vector
            var cplxData = DSPSplitComplex( realp: &zerosR, imagp: &zerosI )
            var xAsComplex = UnsafePointer<DSPComplex>( inputSignal.withUnsafeBufferPointer { $0.baseAddress } )
            vDSP_ctoz( xAsComplex, 2, &cplxData, 1, vDSP_Length(windowSizeOverTwo) )
            
        
            
            //perform fft
            vDSP_fft_zrip( setup, &cplxData, 1, log2n, FFTDirection(kFFTDirection_Forward) )
            
            
            //calculate power
            var powerVector = [Float](count: 128, repeatedValue: 0.0)
            vDSP_zvmags(&cplxData, 1, &powerVector, 1, vDSP_Length(windowSizeOverTwo))
            
                   
            // find peak power and bin
            var power = 0.0 as Float
            var bin = 0 as vDSP_Length
            
            vDSP_maxvi(&powerVector, 1, &power, &bin, vDSP_Length(windowSizeOverTwo))
        
        
            // convert power to frequency
            frequency = Float(hz) * Float(bin) / Float(windowSize);
            
            // push the data to the user
            barGraphView.addX(powerVector)
            frequencyLabel.text = NSString(format:"Frequency: %.2lf", frequency) as String
        
            let binSize = Float(hz)/Float(windowSize)
            let errorSize = binSize/2.0
            calculationLabel.text = NSString(format: "slot \(bin) of \(windowSize) @\(binSize), +/-\(errorSize)") as String
            
        }
        
        
        
        
        
        
        
        
        
        
        @IBAction func stop(){
            
            stopUpdates = true
            
        }
        
        
        
        @IBAction func start(){
            stopUpdates = false
        }
        
        
        
        
        
        
        override func viewDidDisappear(animated: Bool){
            super.viewDidDisappear(animated)
            stop()
            vDSP_destroy_fftsetupD(setup)
        }
        
}