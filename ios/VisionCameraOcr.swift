import Vision
import AVFoundation
import MLKitVision
import MLKitTextRecognition

@objc(OCRFrameProcessorPlugin)
public class OCRFrameProcessorPlugin: NSObject, FrameProcessorPluginBase {
    
    private static func getBlockArray(_ blocks: [TextBlock]) -> [[String: Any]] {
        
        var blockArray: [[String: Any]] = []
        
        for block in blocks {
            blockArray.append([
                "text": block.text,
                "recognizedLanguages": getRecognizedLanguages(block.recognizedLanguages),
                "cornerPoints": getCornerPoints(block.cornerPoints),
                "frame": getFrame(block.frame),
                "lines": getLineArray(block.lines),
            ])
        }
        
        return blockArray
    }
    
    private static func getLineArray(_ lines: [TextLine]) -> [[String: Any]] {
        
        var lineArray: [[String: Any]] = []
        
        for line in lines {
            lineArray.append([
                "text": line.text,
                "recognizedLanguages": getRecognizedLanguages(line.recognizedLanguages),
                "cornerPoints": getCornerPoints(line.cornerPoints),
                "frame": getFrame(line.frame),
                "elements": getElementArray(line.elements),
            ])
        }
        
        return lineArray
    }
    
    private static func getElementArray(_ elements: [TextElement]) -> [[String: Any]] {
        
        var elementArray: [[String: Any]] = []
        
        for element in elements {
            elementArray.append([
                "text": element.text,
                "cornerPoints": getCornerPoints(element.cornerPoints),
                "frame": getFrame(element.frame),
            ])
        }
        
        return elementArray
    }
    
    private static func getRecognizedLanguages(_ languages: [TextRecognizedLanguage]) -> [String] {
        
        var languageArray: [String] = []
        
        for language in languages {
            guard let code = language.languageCode else {
                print("No language code exists")
                break;
            }
            languageArray.append(code)
        }
        
        return languageArray
    }
    
    private static func getCornerPoints(_ cornerPoints: [NSValue]) -> [[String: CGFloat]] {
        
        var cornerPointArray: [[String: CGFloat]] = []
        
        for cornerPoint in cornerPoints {
            guard let point = cornerPoint as? CGPoint else {
                print("Failed to convert corner point to CGPoint")
                break;
            }
            cornerPointArray.append([ "x": point.x, "y": point.y])
        }
        
        return cornerPointArray
    }
    
    private static func getFrame(_ frameRect: CGRect) -> [String: CGFloat] {
        
        let offsetX = (frameRect.midX - ceil(frameRect.width)) / 2.0
        let offsetY = (frameRect.midY - ceil(frameRect.height)) / 2.0
        
        let x = frameRect.maxX + offsetX
        let y = frameRect.minY + offsetY
        
        return [
            "x": frameRect.midX + (frameRect.midX - x),
            "y": frameRect.midY + (y - frameRect.midY),
            "width": frameRect.width,
            "height": frameRect.height,
            "boundingCenterX": frameRect.midX,
            "boundingCenterY": frameRect.midY
        ]
    }
    
    @objc
    public static func callback(_ frame: Frame!, withArgs args: [Any]!) -> Any! {
        guard (CMSampleBufferGetImageBuffer(frame.buffer) != nil) else {
            print("Failed to get image buffer from sample buffer.")
            return nil
        }
        guard let captureSize = args[1] as? [String: Any] else {
            return nil
        }
        
        if let imageBuffer = CMSampleBufferGetImageBuffer(frame.buffer) {
            let ciimage = CIImage(cvPixelBuffer: imageBuffer)
            var image = self.convert(cmage: ciimage, orientation: .up)
            var previewImageRect = CGRect.zero
            print("image.size = \(image.size)")
            if let previewSize = args[0] as? [String: Any] {
                let previewWidth = previewSize["width"] as! NSNumber
                let previewHeight = previewSize["height"] as! NSNumber
                print("previewSize = \(previewSize)")
                let captureWidth = captureSize["width"] as! NSNumber
                let captureHeight = captureSize["height"] as! NSNumber
                print("captureSize = \(captureSize)")
                let scaleWidth = captureWidth.doubleValue / previewWidth.doubleValue
                let widthImage = image.size.width * scaleWidth
                let aspecRatioCaptureView = captureHeight.doubleValue / captureWidth.doubleValue
                let heightImage = widthImage * aspecRatioCaptureView
                previewImageRect: CGRect = caculateCropImageRect(originImageSize: image.size, cropImageSize: CGSize(width: widthImage, height: heightImage))
                print("previewImageRect = \(previewImageRect)")
                image = cropImage(image: image, rect: previewImageRect)
//                let cropRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
//                let croppedSize = AVMakeRect(aspectRatio: CGSize(width: previewWidth.doubleValue, height: previewHeight.doubleValue), insideRect: cropRect)
//                let takenCGImage = image.cgImage
//                let cropCGImage = takenCGImage?.cropping(to: croppedSize)
//                guard let cropCGImage = cropCGImage else {
//                  return nil
//                }
//                image = UIImage(cgImage: cropCGImage, scale: image.scale, orientation: image.imageOrientation)
//                var width = CGFloat(truncating: previewWidth)
//                width /= UIScreen.main.scale
//                let scaleRatio = width / CGFloat(image.size.width)
//                let size = CGSize(width: width, height: CGFloat(roundf(Float(image.size.height * scaleRatio))))
//                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
//                image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
//                let newImage = UIGraphicsGetImageFromCurrentImageContext()
//                UIGraphicsEndImageContext()
//                guard let newImage = newImage else {
//                  return nil
//                }
//                image = UIImage(cgImage: newImage.cgImage!, scale: 1.0, orientation: newImage.imageOrientation)
////                print("previewSize \(previewSize)")
////                let scale = previewWidth.doubleValue / previewHeight.doubleValue
////                let widthImage = image.size.width
////                let heightImage = widthImage / scale
////                let size = CGSize(width: widthImage, height: heightImage)
////                let rect = caculateCropImageRect(originImageSize: image.size, cropImageSize: size)
////                image = cropImage(image: image, rect: rect)
                print("size when crop \(image.size)")
            }
            let visionImage = VisionImage(image: image)
            do {
                let result = try TextRecognizer.textRecognizer(options: TextRecognizerOptions())
                    .results(in: visionImage)
                print("result = \(result.text)")
                return [
                    "result": [
                        "text": result.text,
                        "blocks": getBlockArray(result.blocks),
                        "xAxis": previewImageRect.origin.x,
                        "yAxis": previewImageRect.origin.y,
                    ]
                ]
            } catch let error {
                print("Failed to recognize text with error: \(error.localizedDescription).")
                return nil
            }
        } else {
            print("Failed to get image buffer from sample buffer.")
            return nil
        }
    }
    
    private static func convert(cmage: CIImage, orientation: UIImage.Orientation) -> UIImage {
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(cmage, from: cmage.extent)!
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        return image
    }
    
    private static func caculateCropImageRect(originImageSize: CGSize, cropImageSize: CGSize) -> CGRect {
        let originXImage = (originImageSize.width - cropImageSize.width) / 2
        let originYImage = originImageSize.height / 2 - cropImageSize.height / 2
        let rect: CGRect = CGRect(x: originXImage, y: originYImage, width: cropImageSize.width, height: cropImageSize.height).integral
        
        return rect
    }
    
    private static func cropImage(image: UIImage, rect: CGRect) -> UIImage {
        let cgimage = image.cgImage!
        
        let imageRef: CGImage = cgimage.cropping(to: rect)!
        let resultImage: UIImage = UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
        
        return resultImage
    }
    
    
}
