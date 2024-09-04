//
//  File.swift
//
//
//  Created by Dan on 8/3/24.
//
import UIKit
import opencv2

extension UIImage {
    convenience init?(mat: Mat) {
        // Ensure the Mat is valid
        guard !mat.empty() else {
            return nil
        }
        
        // Convert the Mat to CGImage
        let ns = NSData(bytes: mat.dataPointer(), length: Int(mat.total()) * mat.elemSize())
        let cfdata = ns as CFData
        let width = Int(mat.cols())
        let height = Int(mat.rows())
        let bitsPerComponent = 8
        let bytesPerRow = mat.step1()
        
        // Determine color space and bitmap info based on number of channels
        let channels = mat.channels()
        let colorSpace: CGColorSpace
        let bitmapInfo: CGBitmapInfo
        
        if channels == 1 {
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        } else if channels == 3 {
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        } else if channels == 4 {
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        } else {
            return nil
        }
        
        guard let providerRef = CGDataProvider(data: cfdata) else {
            return nil
        }
        
        guard let cgImage = CGImage(width: width,
                                    height: height,
                                    bitsPerComponent: bitsPerComponent,
                                    bitsPerPixel: bitsPerComponent * Int(channels),
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo,
                                    provider: providerRef,
                                    decode: nil,
                                    shouldInterpolate: true,
                                    intent: .defaultIntent) else {
            return nil
        }
        
        self.init(cgImage: cgImage)
    }
    
}

extension UIImage {
    var noir: UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
    
    func invert() -> UIImage? {
        // Create a CIImage from the UIImage
        guard let ciImage = CIImage(image: self) else { return nil }
        
        // Create an inverted filter
        let filter = CIFilter(name: "CIColorInvert")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Get the output CIImage
        guard let outputCIImage = filter?.outputImage else { return nil }
        
        // Convert CIImage back to UIImage
        let context = CIContext()
        if let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return nil
    }
    
    func advancedInvert() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
           
           let width = cgImage.width
           let height = cgImage.height
           let bitsPerComponent = cgImage.bitsPerComponent
           let bytesPerRow = cgImage.bytesPerRow
           let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
           let bitmapInfo = cgImage.bitmapInfo
           
           // Create a CGContext to manipulate the image
           guard let context = CGContext(data: nil,
                                         width: width,
                                         height: height,
                                         bitsPerComponent: bitsPerComponent,
                                         bytesPerRow: bytesPerRow,
                                         space: colorSpace,
                                         bitmapInfo: bitmapInfo.rawValue) else {
               return nil
           }
           
           // Draw the image into the context
           context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
           
           // Get the raw image data
           guard let imageData = context.data else { return nil }
           
           // Invert the image data
           let buffer = imageData.bindMemory(to: UInt8.self, capacity: width * height * 4)
           let pixelCount = width * height
           
           for i in 0..<pixelCount {
               let pixelIndex = i * 4
               buffer[pixelIndex] = 255 - buffer[pixelIndex]       // Red
               buffer[pixelIndex + 1] = 255 - buffer[pixelIndex + 1] // Green
               buffer[pixelIndex + 2] = 255 - buffer[pixelIndex + 2] // Blue
               // Alpha remains unchanged
           }
           
           // Create a new CGImage from the context
           guard let invertedCGImage = context.makeImage() else { return nil }
           
           // Convert CGImage back to UIImage
           return UIImage(cgImage: invertedCGImage)
    }
}
