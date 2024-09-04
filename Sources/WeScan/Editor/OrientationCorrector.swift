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
    
    func convertToGrayscale(_ image: Mat) -> Mat {
        let cgImage = image.toCGImage();
        
        let context = CIContext(options: nil)
        let ciImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CIPhotoEffectNoir")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey) // Set saturation to 0 for grayscale
        
        let outputImage = filter.outputImage!
        let cgImg = context.createCGImage(outputImage, from: outputImage.extent)!
        
        return Mat(uiImage: UIImage(cgImage: cgImg))
    }
    
    func preprocessImage(_ image: Mat) -> Mat {
        NSLog("preprocessImage")
        // Convert to grayscale
        let grayImage = Mat()
        Imgproc.cvtColor(src: image, dst: grayImage, code: .COLOR_BGR2GRAY)
        
        // Apply Gaussian blur to reduce noise and smooth out the image
        let blurredImage = Mat()
        Imgproc.GaussianBlur(src: grayImage, dst: blurredImage, ksize: Size(width: 5, height: 5), sigmaX: 0)
        
        // Use morphological operations to reduce shadows
        let morphImage = Mat()
        let kernel = Imgproc.getStructuringElement(shape: .MORPH_RECT, ksize: Size(width: 5, height: 5))
        Imgproc.morphologyEx(src: blurredImage, dst: morphImage, op: .MORPH_CLOSE, kernel: kernel)
        
        // Normalize the image to improve contrast
        let normalizedImage = Mat()
        Core.normalize(src: morphImage, dst: normalizedImage, alpha: 0, beta: 255, norm_type: .NORM_MINMAX)
        
        // Apply bilateral filter to reduce noise while preserving edges
        let bilateralFilteredImage = Mat()
        Imgproc.bilateralFilter(src: normalizedImage, dst: bilateralFilteredImage, d: 9, sigmaColor: 75, sigmaSpace: 75)
        
        // Apply median filter to further reduce noise
        let medianFilteredImage = Mat()
        Imgproc.medianBlur(src: bilateralFilteredImage, dst: medianFilteredImage, ksize: 5)
        
        // Apply adaptive thresholding
        let adaptiveThresholdImage = Mat()
        Imgproc.adaptiveThreshold(
            src: medianFilteredImage,
            dst: adaptiveThresholdImage,
            maxValue: 255,
            adaptiveMethod: .ADAPTIVE_THRESH_GAUSSIAN_C,
            thresholdType: .THRESH_BINARY,
            blockSize: 11,
            C: 2)
        
        // Invert the image if necessary
        // Core.bitwise_not(src: adaptiveThresholdImage, dst: adaptiveThresholdImage)
        
        return adaptiveThresholdImage
    }
    func rotateImage(_ image: Mat, by angle: Double) -> Mat {
        // Define the center of rotation
        let center = Point2f(x: Float(image.cols()) / 2, y: Float(image.rows()) / 2)
        // Define the rotation matrix
        let rotMatrix = Imgproc.getRotationMatrix2D(center: center, angle: angle, scale: 1.0)
        // Rotate the source image
        let rotatedImage = Mat()
        Imgproc.warpAffine(src: image, dst: rotatedImage, M: rotMatrix, dsize: Size(width: image.cols(), height: image.rows()))
        return rotatedImage
    }
    func sumRows(_ roi: Mat) -> [Double] {
        var rowSums: [Double] = []
        for i in 0..<roi.rows() {
            let row = roi.row(i)
            rowSums.append(Double(Core.sum(src: row).val[0]))
        }
        return rowSums
    }
    
    func calculateScore(_ image: Mat, angle: Double) -> Double {
        let rotatedImage = rotateImage(image, by: angle)
        
        // Crop the center 1/3rd of the image
        let h = rotatedImage.rows()
        let w = rotatedImage.cols()
        
        let aspectRatio = Double(w) / Double(h)
        let scaleFactor: Double = 2.0 // Adjust this factor to change the ROI size
        
        let buffer = Int32(Double(min(h, w)) - (Double(min(h, w)) / scaleFactor))
        let newWidth = Int32(Double(buffer) * aspectRatio)
        let newHeight = buffer
        
        let roiRect = Rect(x: (w - newWidth)/2, y: (h - newHeight)/2, width: newWidth, height: newHeight)
        let roi = Mat(mat: rotatedImage, rect: roiRect)
        
        // Create background to draw transform on
        var bg = Mat.zeros(newHeight, cols: newWidth, type: CvType.CV_8U)
        
        // Threshold image
        var thresholdedRoi = Mat()
        Imgproc.threshold(src: roi, dst: thresholdedRoi, thresh: 140, maxval: 255, type: .THRESH_BINARY)
        
        // Compute the sums of the rows
        let rowSums = sumRows(thresholdedRoi)
        
        // High score --> Zebra stripes
        let score = Double(rowSums.filter { $0 > 0 }.count)
        
        return score
    }
    
    func findBestRotation(for image: Mat) -> Double {
        let initialScore = Double.greatestFiniteMagnitude
        var bestScore = Double.greatestFiniteMagnitude
        var bestAngle = 0.0
        
        for angle in stride(from: 0, through: 45, by: 0.5) {
            let score = calculateScore(image, angle: angle)
            print("+score \(angle) : \(score)")
            if score < bestScore {
                bestScore = score
                bestAngle = angle
            }
            if score > bestScore && bestScore < initialScore {
                break
            }
        }
        
        for angle in stride(from: 0, through: -45, by: -0.5) {
            let score = calculateScore(image, angle: angle)
            print("-score \(angle) : \(score)")
            if score < bestScore {
                bestScore = score
                bestAngle = angle
            }
        }
        NSLog("findBestRotation \(bestAngle) degrees")
        NSLog("Best Score: \(bestScore)")
        return bestAngle
    }
    func deskewImage(_ image: Mat) -> Mat {
        NSLog("deskewImage")
        let preprocessedImage = preprocessImage(image)
        let bestAngle = findBestRotation(for: preprocessedImage)
        NSLog("Row Count: \(preprocessedImage.rows())")
        return rotateImage(preprocessedImage, by: bestAngle)
    }
}


