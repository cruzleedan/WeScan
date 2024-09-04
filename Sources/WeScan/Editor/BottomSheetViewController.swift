//
//  File.swift
//  
//
//  Created by Dan on 8/2/24.
//
import UIKit
import Vision

class BottomSheetViewController: UIViewController {
    
    weak var delegate: BottomSheetViewControllerDelegate?
    
    let ocv = Ocv()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var deskewButton: ToolbarButton = {
        let button = ToolbarButton(systemName: "skew", target: self, action: #selector(deskewImage))
        button.setImage(UIImage(systemName: "skew"), for: .normal)
        return button
    }()
    
    private lazy var highlightTextButton: ToolbarButton = {
        let button = ToolbarButton(systemName: "text.viewfinder", target: self, action: #selector(highlightText))
        button.setImage(UIImage(systemName: "text.viewfinder"), for: .normal)
        return button
    }()
    
    // MARK: - LifeCycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the bottom sheet view
        view.backgroundColor = .systemBackground
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        setupStackView()
        setupConstraints()
    }
    // MARK: - Setup Methods
    
    private func setupStackView() {
        stackView.addArrangedSubview(deskewButton)
        stackView.addArrangedSubview(highlightTextButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    // MARK: - Methods
    
    @objc
    private func deskewImage() {
        NSLog("deskewImage")
        guard let delegate = delegate, let image = delegate.image else { return }
        delegate.showSpinner()
//        let grayscaleImage = delegate.image?.noir?.advancedInvert()
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let imageMat = self.ocv.loadImage(image)
            let deskewedImageMat = self.ocv.deskewImage(imageMat)
            let deskewedUIImage = UIImage(mat: deskewedImageMat)
            DispatchQueue.main.async {
                delegate.onImageDeskewed(image: deskewedUIImage)
                delegate.hideSpinner()
            }
        }
    }
    
    @objc
    private func highlightText() {
        NSLog("highlightText")
        guard let delegate = delegate,
              let image = delegate.image,
              let cgImage = image.cgImage
        else { return }
        
        var documentImage = UIImage(cgImage: cgImage)
        
        delegate.showSpinner()
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            detectTextRectangles(in: documentImage) { observations in
                guard let observations = observations else {
                    print("No text rectangles detected")
                    return
                }
                
                for (index, observation) in observations.enumerated() {
                    let boundingBox = observation.boundingBox
                    print("Text area \(index + 1): \(boundingBox)")
                    
                    // If you want to draw these rectangles on the image:
                    guard let newImage = self.drawRectangle(on: documentImage, boundingBox: boundingBox) else { continue }
                    documentImage = newImage
                }
                
                DispatchQueue.main.async {
                    delegate.onImageDeskewed(image: documentImage)
                    delegate.hideSpinner()
                }
            }
        }
    }
    
    func detectTextRectangles(in image: UIImage, completion: @escaping ([VNTextObservation]?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNDetectTextRectanglesRequest { request, error in
            guard let observations = request.results as? [VNTextObservation] else {
                completion(nil)
                return
            }
            completion(observations)
        }
        
        // Set this to true if you want to detect individual characters
        request.reportCharacterBoxes = false
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform text rectangle detection: \(error)")
            completion(nil)
        }
    }
    
    func drawRectangle(on image: UIImage, boundingBox: CGRect) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, 0)
        let context = UIGraphicsGetCurrentContext()!
        
        image.draw(at: CGPoint.zero)
        
        context.setLineWidth(2)
        context.setStrokeColor(UIColor.red.cgColor)
        
        let box = CGRect(x: boundingBox.minX, y: 1 - boundingBox.minY, width: boundingBox.width, height: boundingBox.height)
        
        let rectangleInImageCoordinates = VNImageRectForNormalizedRect(box, Int(image.size.width), Int(image.size.height))
        
        context.stroke(rectangleInImageCoordinates)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}


protocol BottomSheetViewControllerDelegate: class {
    var image: UIImage? { get }
    func onImageDeskewed(image: UIImage?)
    func showSpinner()
    func hideSpinner()
}
