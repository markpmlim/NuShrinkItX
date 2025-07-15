//
//  CleanupViewController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

class CleanupViewController: NSViewController
{
	@IBAction override func cancelOperation(_ sender: Any?) {
		//Swift.print("cancelOperation")
		NSApp.stopModal()
	}
}
