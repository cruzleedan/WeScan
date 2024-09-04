//
//  File.swift
//
//
//  Created by Dan on 8/8/24.
//

import UIKit

class LinearGauge: UIControl, UIScrollViewDelegate {
    
    var minValue: CGFloat = -180
    var maxValue: CGFloat = 180
    var majorTickInterval: CGFloat = 30
    var minorTickInterval: CGFloat = 10
    var tickSpacing: CGFloat = 10
    var currentValue: CGFloat = 0
    var padding: CGFloat = 60.0
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let centerLine = UIView()
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // Setup scroll view
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        addSubview(scrollView)
        
        // Setup content view
        contentView.backgroundColor = .systemBackground
        scrollView.addSubview(contentView)
        
        // Setup center line
        centerLine.backgroundColor = .red
        addSubview(centerLine)
        
        // Prepare the haptic feedback generator
        feedbackGenerator.prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Layout scrollView and contentView
        scrollView.frame = bounds
        
        // Calculate total content width to allow scrolling beyond the visible bounds
        let totalTicks = (maxValue - minValue) / minorTickInterval
        let contentWidth = CGFloat(totalTicks) * tickSpacing
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)
        scrollView.contentSize = contentView.frame.size
        
        // Position the center line
        centerLine.frame = CGRect(x: bounds.midX - 1, y: bounds.minY, width: 2, height: bounds.height)
        
        // Draw the ruler
        drawRuler()
        
        // Center the initial scroll position
        let initialOffset = scrollView.contentSize.width / 4
        NSLog("initialOffset: \(initialOffset)")
        scrollView.contentOffset = CGPoint(x: initialOffset, y: 0)
    }
    
    private func drawRuler() {
        let tickSpacing: CGFloat = 10.0 // Space between each tick
        let totalTicks = Int((maxValue - minValue) / minorTickInterval)

        
        // Clear existing ticks
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Calculate the starting X position to center the ticks
        let rulerWidth = CGFloat(totalTicks) * tickSpacing
        let startX = (rulerWidth + padding) / 2
        NSLog("rulerWidth: \(rulerWidth)")
        for i in 0...totalTicks {
            let positionX = startX + CGFloat(i) * tickSpacing
            let value = minValue + CGFloat(i) * minorTickInterval
            
            let tickHeight: CGFloat = (i % Int(majorTickInterval / minorTickInterval) == 0) ? 20 : 10
            NSLog("i: \(i), positionX: \(positionX)")
            let tickView = UIView(frame: CGRect(x: positionX, y: bounds.midY - tickHeight / 2, width: 1, height: tickHeight))
            tickView.backgroundColor = .label
            contentView.addSubview(tickView)
            
            if tickHeight == 20 { // Major tick, add label
                let label = UILabel(frame: CGRect(x: positionX - 15, y: bounds.midY + tickHeight / 2, width: 30, height: 20))
                label.text = "\(Int(value))"
                label.textAlignment = .center
                label.font = UIFont.systemFont(ofSize: 10)
                label.textColor = .label
                contentView.addSubview(label)
            }
        }
        
        // Update contentView's width to accommodate all ticks
        contentView.layoutIfNeeded()
        contentView.frame.size.width = contentView.frame.size.width * 2.0 + padding
        NSLog("contentView width is now = \(contentView.frame.size.width)")
        scrollView.contentSize.width = contentView.frame.size.width
        
    }

    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCurrentValue()
    }
    
    private func updateCurrentValue() {
        let centerOffset = scrollView.contentSize.width / 4
        let totalTicks = (maxValue - minValue) / minorTickInterval
        let valuePerPoint = (maxValue - minValue) / (CGFloat(totalTicks) * tickSpacing)
        currentValue = ((minValue + maxValue) / 2) + valuePerPoint * (centerOffset - scrollView.contentOffset.x)
        
        if Int(currentValue) % Int(minorTickInterval) == 0 {
            feedbackGenerator.selectionChanged()
        }
        sendActions(for: .valueChanged)
    }
}
