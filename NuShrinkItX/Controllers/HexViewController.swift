//
//  HexViewController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

class HexViewController: NSViewController
{
	@IBOutlet var hexView: NSTextView!
	
	func insertString(_ contents: String) {
		let newFont = NSFont.userFixedPitchFont(ofSize: 13.0)
		hexView.font = newFont
		hexView.insertText(contents)
	}
}
