//
//  File.swift
//  
//
//  Created by Dan on 7/31/24.
//
import UIKit

class SpinnerViewController: UIViewController {
    var spinner = UIActivityIndicatorView(style: .medium)
    var blurEffectView: UIVisualEffectView!
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor.clear
        
        // Create a blur effect view
        let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.layer.cornerRadius = 10
        blurEffectView.clipsToBounds = true
        
        view.addSubview(blurEffectView)
        blurEffectView.contentView.addSubview(spinner)
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        
        NSLayoutConstraint.activate([
            blurEffectView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurEffectView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            blurEffectView.widthAnchor.constraint(equalToConstant: 100),
            blurEffectView.heightAnchor.constraint(equalToConstant: 100),
            
            spinner.centerXAnchor.constraint(equalTo: blurEffectView.contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: blurEffectView.contentView.centerYAnchor)
        ])
    }
}

extension UIViewController {
    func showSpinner() {
        let spinnerViewController = SpinnerViewController()
        addChild(spinnerViewController)
        spinnerViewController.view.frame = view.bounds
        view.addSubview(spinnerViewController.view)
        spinnerViewController.didMove(toParent: self)
    }
    
    func hideSpinner() {
        for child in children {
            if let spinnerViewController = child as? SpinnerViewController {
                spinnerViewController.willMove(toParent: nil)
                spinnerViewController.view.removeFromSuperview()
                spinnerViewController.removeFromParent()
            }
        }
    }
}
