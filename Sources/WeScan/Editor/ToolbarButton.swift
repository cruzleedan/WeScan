//
//  File.swift
//  
//
//  Created by Dan on 8/2/24.
//

import UIKit

class ToolbarButton: UIButton {
    init(systemName: String, target: Any?, action: Selector) {
        super.init(frame: .zero)
        
        if let image = UIImage(systemName: systemName) {
            self.setImage(image, for: .normal)
            self.tintColor = .systemBlue
        }
        
        self.addTarget(target, action: action, for: .touchUpInside)
        
        self.frame.size = CGSize(width: 50, height: 50)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(equalToConstant: 50).isActive = true
        self.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
