//
//  File.swift
//  
//
//  Created by Dan on 7/31/24.
//
import opencv2
import UIKit

func extractLines(image: UIImage) -> UIImage {
    // Show source image
    let src = Mat(uiImage: image)

    // Transform source image to gray if it is not already
    let gray: Mat
    if (src.channels() == 3) {
        gray = Mat()
        Imgproc.cvtColor(src: src, dst: gray, code: .COLOR_BGR2GRAY)
    } else {
        gray = src
    }

    // Apply adaptiveThreshold at the bitwise_not of gray, notice the ~ symbol
    let notGray = Mat()
    Core.bitwise_not(src: gray, dst: notGray)

    let bw = Mat()
    Imgproc.adaptiveThreshold(src: notGray, dst: bw, maxValue: 255, adaptiveMethod: .ADAPTIVE_THRESH_MEAN_C, thresholdType: .THRESH_BINARY, blockSize: 15, C: -2)

    // Create the images that will use to extract the horizontal lines
    let horizontal = bw.clone()
    let vertical = bw.clone()

    // Specify size on horizontal axis
    let horizontalSize = horizontal.cols() / 30
    // Create structure element for extracting horizontal lines through morphology operations
    let horizontalStructure = Imgproc.getStructuringElement(shape: .MORPH_RECT, ksize: .init(width: horizontalSize, height: 1))
    // Apply morphology operations
    Imgproc.erode(src: horizontal, dst: horizontal, kernel: horizontalStructure, anchor: .init(x: -1, y: -1))
    Imgproc.dilate(src: horizontal, dst: horizontal, kernel: horizontalStructure, anchor: .init(x: -1, y: -1))

    // Specify size on vertical axis
    let verticalSize = vertical.rows() / 30

    // Create structure element for extracting vertical lines through morphology operations
    let verticalStructure = Imgproc.getStructuringElement(shape: .MORPH_RECT, ksize: .init(width: 1, height: verticalSize))

    // Apply morphology operations
    Imgproc.erode(src: vertical, dst: vertical, kernel: verticalStructure, anchor: .init(x: -1, y: -1))
    Imgproc.dilate(src: vertical, dst: vertical, kernel: verticalStructure, anchor: .init(x: -1, y: -1))

    // Inverse vertical image
    Core.bitwise_not(src: vertical, dst: vertical)

    // Extract edges and smooth image according to the logic
    // 1. extract edges
    // 2. dilate(edges)
    // 3. src.copyTo(smooth)
    // 4. blur smooth img
    // 5. smooth.copyTo(src, edges)
    // Step 1
    let edges = Mat();
    Imgproc.adaptiveThreshold(src: vertical, dst: edges, maxValue: 255, adaptiveMethod: .ADAPTIVE_THRESH_MEAN_C, thresholdType: .THRESH_BINARY, blockSize: 3, C: -2)

    // Step 2
    let kernel = Mat.ones(rows: 2, cols: 2, type: CvType.CV_8UC1)
    Imgproc.dilate(src: edges, dst: edges, kernel: kernel)

    // Step 3
    let smooth = Mat();
    vertical.copy(to: smooth)

    // Step 4
    Imgproc.blur(src: smooth, dst: smooth, ksize: .init(width: 2, height: 2))

    // Step 5
    smooth.copy(to: vertical, mask: edges)

    // Show final result
    let result = vertical.toUIImage()

    return result
}

func deskewImageUsingPHT(_ image: UIImage) -> UIImage? {
    NSLog("deskewImageUsingPHT")
    let mat = Mat(uiImage: image)
    
    // Convert to grayscale
    let gray = Mat()
    Imgproc.cvtColor(src: mat, dst: gray, code: .COLOR_BGR2GRAY)
    
    // Apply edge detection
    let edges = Mat()
    Imgproc.Canny(image: gray, edges: edges, threshold1: 50, threshold2: 150, apertureSize: 3)
    
    // Apply Probabilistic Hough Transform
    let lines = Mat()
    Imgproc.HoughLinesP(image: edges, lines: lines, rho: 1, theta: .pi/180, threshold: 50, minLineLength: 20, maxLineGap: 40)
    
    // Calculate the angle
    var sum = 0.0
    var count = 0
    for i in 0..<lines.rows() {
        let vec4f = lines.get(row: i, col: 0)
        let x1 = vec4f[0]
        let y1 = vec4f[1]
        let x2 = vec4f[2]
        let y2 = vec4f[3]
        
        let angle = atan2(Double(y2 - y1), Double(x2 - x1))
        sum += angle
        count += 1
    }
    
    // If no lines were detected, return the original image
    NSLog("Detected line count \(count)")
    guard count > 0 else { return image }
    
    let averageAngle = sum / Double(count)
    let rotationAngle = averageAngle * 180 / .pi
    
    NSLog("Average angle \(rotationAngle)")
    
    
    // Rotate the image
    let center = Point2f(x: Float(mat.cols()) / 2, y: Float(mat.rows()) / 2)
    let rotMat = Imgproc.getRotationMatrix2D(center: center, angle: rotationAngle, scale: 1.0)
    let rotated = Mat()
    Imgproc.warpAffine(src: mat, dst: rotated, M: rotMat, dsize: mat.size())
    
    // Convert Mat back to UIImage
    let ns = NSData(bytes: rotated.dataPointer(), length: Int(rotated.total()) * rotated.elemSize())
    let cfdata = ns as CFData
    let provider = CGDataProvider(data: cfdata)
    let cgimage = CGImage(width: Int(rotated.cols()),
                          height: Int(rotated.rows()),
                          bitsPerComponent: 8,
                          bitsPerPixel: 32,
                          bytesPerRow: Int(rotated.cols()) * 4,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                          provider: provider!,
                          decode: nil,
                          shouldInterpolate: true,
                          intent: .defaultIntent)
    
    return cgimage.flatMap { UIImage(cgImage: $0) }
}



class Ocv {
    func loadImage(_ image: UIImage) -> Mat {
        return Mat(uiImage: image)
    }
    
    func preprocessImage(_ image: Mat) -> Mat {
        NSLog("preprocessImage")
        let grayImage = Mat()
        Imgproc.cvtColor(src: image, dst: grayImage, code: .COLOR_BGR2GRAY)
        Core.bitwise_not(src: grayImage, dst: grayImage)
        return grayImage
    }
    func rotateImage(_ image: Mat, by angle: Double) -> Mat {
        NSLog("rotateImage to \(angle) degrees")
        let center = Point2f(x: Float(image.cols()) / 2, y: Float(image.rows()) / 2)
        let rotMatrix = Imgproc.getRotationMatrix2D(center: center, angle: angle, scale: 1.0)
        let rotatedImage = Mat()
        Imgproc.warpAffine(src: image, dst: rotatedImage, M: rotMatrix, dsize: Size(width: image.cols(), height: image.rows()))
        return rotatedImage
    }
    func sumRows(_ image: Mat) -> [Double] {
        var rowSums: [Double] = []
        for row in 0..<image.rows() {
            let rowSum = Core.sum(src: image.row(row)).val[0]
            rowSums.append(Double(rowSum))
        }
        if let maxSum = rowSums.max() {
            rowSums = rowSums.map { $0 / maxSum * 255 }
        }
        return rowSums
    }
    func scoreRotation(_ rowSums: [Double]) -> Double {
        return Double(rowSums.filter { $0 < 255 }.count)
    }
    
    func findBestRotation(for image: Mat) -> Double {
        var bestScore = Double.greatestFiniteMagnitude
        var bestAngle = 0.0
        
        for angle in stride(from: -45.0, through: 45.0, by: 0.5) {
            let rotatedImage = rotateImage(image, by: angle)
            let rowSums = sumRows(rotatedImage)
            let score = scoreRotation(rowSums)
            if score < bestScore {
                bestScore = score
                bestAngle = angle
            }
        }
        NSLog("findBestRotation \(bestAngle) degrees")
        return bestAngle
    }
    func deskewImage(_ image: Mat) -> Mat {
        NSLog("deskewImage")
        let preprocessedImage = preprocessImage(image)
        let bestAngle = findBestRotation(for: preprocessedImage)
        return rotateImage(image, by: bestAngle)
    }
}


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
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let providerRef = CGDataProvider(data: cfdata) else {
            return nil
        }
        
        guard let cgImage = CGImage(width: width,
                                    height: height,
                                    bitsPerComponent: bitsPerComponent,
                                    bitsPerPixel: bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                    provider: providerRef,
                                    decode: nil,
                                    shouldInterpolate: true,
                                    intent: .defaultIntent) else {
            return nil
        }
        
        self.init(cgImage: cgImage)
    }
}
