//
//  AttributesWindowController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.

import Foundation

class AttributesWindowController: NSWindowController, NSWindowDelegate {

    // The property `document` is set by the function editAttributes(_ :)
	override var document: AnyObject? {
		didSet {
		}
	}

	func windowWillClose(_ notification: Notification) {
		//let vc = window!.contentViewController as! AttributesViewController
		//vc.applyChanges(self)
		let application = NSApplication.shared
		application.stopModal()
	}
}
