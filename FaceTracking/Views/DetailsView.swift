//  DetailsView.swift
//
//  Created by Nino
//  Copyright © 2018 Pawel Chmiel. All rights reserved.
//

import UIKit

class DetailsView: UIView {
    
    lazy var detailsLabel: UILabel = {
        let detailsLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height))
        detailsLabel.numberOfLines = 0
        detailsLabel.textColor = .white
        detailsLabel.font = UIFont.systemFont(ofSize: 18.0)
        detailsLabel.textAlignment = .left
        
        return detailsLabel
    }()
    
    func setup() {
        layer.borderColor = UIColor.red.withAlphaComponent(0.7).cgColor
        layer.borderWidth = 2.0
        
        addSubview(detailsLabel)
    }
    
    override var frame: CGRect {
        didSet(newFrame) {
            var detailsFrame = detailsLabel.frame
            detailsFrame = CGRect(x: 0, y: newFrame.size.height, width: newFrame.size.width * 2.0, height: newFrame.size.height / 2.0)
            detailsLabel.frame = detailsFrame
        }
    }
}
