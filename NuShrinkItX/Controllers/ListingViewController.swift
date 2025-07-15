//
//  ListingViewController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

class ListingViewController: NSViewController
{
	@IBOutlet var txtView: NSTextView!

	func insertString(_ contents: String) {
		let newFont = NSFont.userFixedPitchFont(ofSize: 13.0)
		txtView.font = newFont
		txtView.insertText(contents)
	}
}
