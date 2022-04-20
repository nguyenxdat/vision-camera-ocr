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
        print("args = \(args)");
        guard (CMSampleBufferGetImageBuffer(frame.buffer) != nil) else {
          print("Failed to get image buffer from sample buffer.")
          return nil
        }
        
        if let imageBuffer = CMSampleBufferGetImageBuffer(frame.buffer) {
            let ciimage = CIImage(cvPixelBuffer: imageBuffer)
            let image = self.convert(cmage: ciimage, orientation: frame.orientation)
            let visionImage = VisionImage(image: image)
            do {
                let result = try TextRecognizer.textRecognizer(options: TextRecognizerOptions())
                  .results(in: visionImage)
                return [
                    "result": [
                        "text": result.text,
                        "blocks": getBlockArray(result.blocks),
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
    
}
