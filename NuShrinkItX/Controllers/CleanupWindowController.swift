//
//  CleanupWindowController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

class CleanupWindowController: NSWindowController, NSWindowDelegate
{
	// window delegate method. Connect window's "delegate" property
	// to the window controller object in storyboard.
	func windowWillClose(_ notification: Notification) {
		//Swift.print("window closing")
		NSApp.stopModal()
	}
}
