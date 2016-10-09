//
//  RangeSlider.swift
//  VideoPlayer
//
//  Created by Amr Mohamed on 4/5/16.
//  Copyright © 2016 Amr Mohamed. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.


import UIKit
import QuartzCore
import AVFoundation

internal class AMVideoRangeSliderThumbLayer: CAShapeLayer {
  var highlighted = false
  weak var rangeSlider : AMVideoRangeSlider?


  override func layoutSublayers() {
    super.layoutSublayers()
    self.cornerRadius = self.bounds.width / 2
    self.setNeedsDisplay()
  }

  override func draw(in ctx: CGContext) {
    ctx.move(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height/5))
    ctx.addLine(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height - self.bounds.height/5))

    ctx.setStrokeColor(strokeColor != nil ? strokeColor! : UIColor.white.cgColor)
    ctx.strokePath()
  }
}

internal class AMVideoRangeSliderTrackLayer: CAShapeLayer {

  weak var rangeSlider : AMVideoRangeSlider?

  override func draw(in ctx: CGContext) {
    if let slider = rangeSlider {
      let lowerValuePosition = CGFloat(slider.positionForValue(slider.lowerValue))
      let upperValuePosition = CGFloat(slider.positionForValue(slider.upperValue))
      let rect = CGRect(x: lowerValuePosition, y: 0.0, width: upperValuePosition - lowerValuePosition, height: bounds.height)
      ctx.setFillColor(slider.sliderTintColor.cgColor)
      ctx.fill(rect)
    }
  }
}

public protocol AMVideoRangeSliderDelegate {
  func rangeSliderLowerThumbValueChanged()
  func rangeSliderMiddleThumbValueChanged()
  func rangeSliderUpperThumbValueChanged()
}

@IBDesignable open class AMVideoRangeSlider: UIControl {

  /// Only valid when show middle thumb
  open var middleValue = 0.0 {
    didSet {
      guard showMiddleThumb else {
        return
      }
      self.updateLayerFrames()
    }
  }

  open var minimumValue: Double = 0.0 {
    didSet {
      self.updateLayerFrames()
    }
  }

  open var maximumValue: Double = 1.0 {
    didSet {
      self.updateLayerFrames()
    }
  }

  /// Only valid when show lower thumb
  open var lowerValue: Double = 0.0 {
    didSet {
      guard showLowerThumb else {
        return
      }
      self.updateLayerFrames()
    }
  }

  /// Only valid when show upper thumb
  open var upperValue: Double = 1.0 {
    didSet {
      guard showUpperThumb else {
        return
      }
      self.updateLayerFrames()
    }
  }

  open var videoAsset : AVAsset? {
    didSet {
      self.generateVideoImages()
    }
  }

  /// Only valid when show middle thumb
  open var currentTime : CMTime {
    return CMTimeMakeWithSeconds(self.videoAsset!.duration.seconds * self.middleValue, self.videoAsset!.duration.timescale)
  }

  /// Only valid when show lower thumb
  open var startTime : CMTime! {
    return CMTimeMakeWithSeconds(self.videoAsset!.duration.seconds * self.lowerValue, self.videoAsset!.duration.timescale)
  }

  /// Only valid when show upper thumb
  open var stopTime : CMTime! {
    return CMTimeMakeWithSeconds(self.videoAsset!.duration.seconds * self.upperValue, self.videoAsset!.duration.timescale)
  }

  /// Only use when show lower and upper thumb
  open var rangeTime : CMTimeRange! {
    let lower = self.videoAsset!.duration.seconds * self.lowerValue
    let upper = self.videoAsset!.duration.seconds * self.upperValue
    let duration = CMTimeMakeWithSeconds(upper - lower, self.videoAsset!.duration.timescale)
    return CMTimeRangeMake(self.startTime, duration)
  }

  @IBInspectable open var sliderTintColor: UIColor = UIColor(red:0.97, green:0.71, blue:0.19, alpha:1.00) {
    didSet {
      self.lowerThumbLayer.backgroundColor = self.sliderTintColor.cgColor
      self.upperThumbLayer.backgroundColor = self.sliderTintColor.cgColor
    }
  }

  @IBInspectable open var middleThumbTintColor : UIColor! {
    didSet {
      self.middleThumbLayer.backgroundColor = self.middleThumbTintColor.cgColor
      self.middleThumbLayer.strokeColor = self.middleThumbTintColor.cgColor
    }
  }

  @IBInspectable open  var showLowerThumb: Bool = true {
    didSet {
      if showLowerThumb {
        return
      }
      lowerThumbLayer.removeFromSuperlayer()
    }
  }
  @IBInspectable open var showMiddleThumb: Bool = true {
    didSet {
      if showMiddleThumb {
        return
      }
      middleThumbLayer.removeFromSuperlayer()
    }
  }

  @IBInspectable open var showUpperThumb: Bool = true {
    didSet {
      if showUpperThumb {
        return
      }
      upperThumbLayer.removeFromSuperlayer()
    }
  }

  open var delegate : AMVideoRangeSliderDelegate?

  var middleThumbLayer = AMVideoRangeSliderThumbLayer()
  var lowerThumbLayer = AMVideoRangeSliderThumbLayer()
  var upperThumbLayer = AMVideoRangeSliderThumbLayer()

  var trackLayer = AMVideoRangeSliderTrackLayer()

  var previousLocation = CGPoint()

  var thumbWidth : CGFloat {
    return 15
  }

  var thumpHeight : CGFloat {
    return self.bounds.height + 10
  }

  open override var frame: CGRect {
    didSet {
      self.updateLayerFrames()
    }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    self.commonInit()
  }

  public required init(coder : NSCoder) {
    super.init(coder: coder)!
    self.commonInit()
  }

  open override func layoutSubviews() {
    self.updateLayerFrames()
  }

  func commonInit() {
    self.trackLayer.rangeSlider = self

    self.layer.addSublayer(self.trackLayer)
    if showMiddleThumb {
      self.middleThumbLayer.rangeSlider = self
      self.layer.addSublayer(self.middleThumbLayer)
      self.middleThumbLayer.backgroundColor = UIColor.green.cgColor
    }

    if showLowerThumb {
      self.lowerThumbLayer.rangeSlider = self
      self.layer.addSublayer(self.lowerThumbLayer)
      self.lowerThumbLayer.backgroundColor = self.sliderTintColor.cgColor
      self.lowerThumbLayer.contentsScale = UIScreen.main.scale
    }

    if showUpperThumb {
      self.upperThumbLayer.rangeSlider = self
      self.layer.addSublayer(self.upperThumbLayer)
      self.upperThumbLayer.backgroundColor = self.sliderTintColor.cgColor
      self.upperThumbLayer.contentsScale = UIScreen.main.scale
    }

    self.trackLayer.contentsScale = UIScreen.main.scale

    self.updateLayerFrames()
  }

  func updateLayerFrames() {

    CATransaction.begin()
    CATransaction.setDisableActions(true)

    self.trackLayer.frame = self.bounds
    self.trackLayer.setNeedsDisplay()

    if showMiddleThumb {
      let middleThumbCenter = CGFloat(self.positionForValue(self.middleValue))
      self.middleThumbLayer.frame = CGRect(x: middleThumbCenter - self.thumbWidth / 2, y: -5.0, width: 2, height: self.thumpHeight)
    }


    if showLowerThumb {
      let lowerThumbCenter = CGFloat(self.positionForValue(self.lowerValue))
      self.lowerThumbLayer.frame = CGRect(x: lowerThumbCenter - self.thumbWidth / 2, y: -5.0, width: self.thumbWidth, height: self.thumpHeight)
    }


    if showUpperThumb {
      let upperThumbCenter = CGFloat(self.positionForValue(self.upperValue))
      self.upperThumbLayer.frame = CGRect(x: upperThumbCenter - self.thumbWidth / 2, y: -5.0, width: self.thumbWidth, height: self.thumpHeight)
    }
    CATransaction.commit()
  }

  func positionForValue(_ value: Double) -> Double {
    return Double(self.bounds.width - self.thumbWidth * (showUpperThumb ? 1 : 0)) * (value - self.minimumValue) / (self.maximumValue - self.minimumValue) + Double(self.thumbWidth/2.0) * (showLowerThumb ? 1 : 0)
  }

  open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    self.previousLocation = touch.location(in: self)

    if self.lowerThumbLayer.frame.contains(self.previousLocation) && showLowerThumb {
      self.lowerThumbLayer.highlighted = true
    } else if self.upperThumbLayer.frame.contains(self.previousLocation) && showUpperThumb {
      self.upperThumbLayer.highlighted = true
    } else if showMiddleThumb {
      self.middleThumbLayer.highlighted = true
    }

    return self.lowerThumbLayer.highlighted || self.upperThumbLayer.highlighted || self.middleThumbLayer.highlighted
  }

  func boundValue(_ value: Double, toLowerValue lowerValue: Double, upperValue: Double) -> Double {
    return min(max(value, lowerValue), upperValue)
  }

  open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    let location = touch.location(in: self)

    let deltaLocation = Double(location.x - self.previousLocation.x)
    let deltaValue = (self.maximumValue - self.minimumValue) * deltaLocation / Double(self.bounds.width - self.thumbWidth)
    let newMiddle = Double(self.previousLocation.x) / Double(self.bounds.width - self.thumbWidth)

    self.previousLocation = location

    if self.lowerThumbLayer.highlighted && showLowerThumb {
      if deltaValue > 0 && self.rangeTime.duration.seconds <= 1{

      } else {
        self.lowerValue += deltaValue
        self.lowerValue = self.boundValue(self.lowerValue, toLowerValue: self.minimumValue, upperValue: self.maximumValue)
        self.delegate?.rangeSliderLowerThumbValueChanged()
      }

    } else if self.middleThumbLayer.highlighted && showMiddleThumb {
      self.middleValue = newMiddle

    }  else if self.upperThumbLayer.highlighted {
      if deltaValue < 0 && self.rangeTime.duration.seconds <= 1 {

      } else {
        self.upperValue += deltaValue
        self.upperValue = self.boundValue(self.upperValue, toLowerValue: self.minimumValue, upperValue: self.maximumValue)
        self.delegate?.rangeSliderUpperThumbValueChanged()
      }
    }
    if showMiddleThumb {
      self.middleValue = self.boundValue(self.middleValue, toLowerValue: self.lowerValue, upperValue: self.upperValue)
      self.delegate?.rangeSliderMiddleThumbValueChanged()
    }

    self.sendActions(for: .valueChanged)
    return true
  }

  open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    if showLowerThumb {
      self.lowerThumbLayer.highlighted = false
    }

    if showMiddleThumb {
      self.middleThumbLayer.highlighted = false
    }

    if showUpperThumb {
      self.upperThumbLayer.highlighted = false
    }
  }

  func generateVideoImages() {
    DispatchQueue.main.async(execute: {

      self.lowerValue = 0.0
      self.upperValue = 1.0

      for subview in self.subviews {
        if subview is UIImageView {
          subview.removeFromSuperview()
        }
      }

      let imageGenerator = AVAssetImageGenerator(asset: self.videoAsset!)

      let assetDuration = CMTimeGetSeconds(self.videoAsset!.duration)
      var Times = [NSValue]()

      let numberOfImages = Int((self.frame.width / self.frame.height))

      for index in 1...numberOfImages {
        let point = CMTimeMakeWithSeconds(assetDuration/Double(index), 600)
        Times += [NSValue(time: point)]
      }

      Times = Times.reversed()

      let imageWidth = self.frame.width/CGFloat(numberOfImages)
      var imageFrame = CGRect(x: 0, y: 2, width: imageWidth, height: self.frame.height-4)

      imageGenerator.generateCGImagesAsynchronously(forTimes: Times) { (requestedTime, image, actualTime, result, error) in
        if error == nil {

          if result == AVAssetImageGeneratorResult.succeeded {

            DispatchQueue.main.async(execute: {
              let imageView = UIImageView(image: UIImage(cgImage: image!))
              imageView.contentMode = .scaleAspectFill
              imageView.clipsToBounds = true
              imageView.frame = imageFrame
              imageFrame.origin.x += imageWidth
              self.insertSubview(imageView, at:1)
            })
          }

          if result == AVAssetImageGeneratorResult.failed {
            print("Generating Fail")
          }
          
        } else {
          print("Error at generating images : \(error!.localizedDescription)")
        }
      }
      
    })
    
  }
  
}
