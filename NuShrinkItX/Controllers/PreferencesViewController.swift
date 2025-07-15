//
//  PreferencesViewController.swift
//  NuShrinkItX
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//  Copyright © 2015 Karl Moskowski. All rights reserved.


import Cocoa

// NB. The delegate of the instance of NSTabView (in main storyboard) is set to this controller object.
// Now, it is redundant to declare NSTabViewController conforms to the protocol NSTabViewDelegate.
class PreferencesViewController: NSTabViewController {

    // Use a Swift Dictionary
	lazy var originalSizes = [String : NSSize]()

    // The 2 functions below get called even before the window is displayed.
	override func tabView(_ tabView: NSTabView,
                          willSelect tabViewItem: NSTabViewItem?) {
		super.tabView(tabView, willSelect: tabViewItem)

/*
		// https://github.com/emiscience/SwiftPrefs/issues/1
		if let currentTabViewItem = tabView.selectedTabViewItem {
			currentTabViewItem.view!.hidden = true
		}
*/
		tabViewItem!.view!.isHidden = true

		// For each tabViewItem, save the original, as-laid-out-in-IB view size,
		// so it can be used to resize the window with the selected tab changes
		let originalSize = self.originalSizes[tabViewItem!.label]
		if (originalSize == nil) {
			self.originalSizes[tabViewItem!.label] = (tabViewItem!.view?.frame.size)!
		}
	}

    /*
    The toolbar is included in the window's frame rectangle but not the content rectangle
     */
	override func tabView(_ tabView: NSTabView,
                          didSelect tabViewItem: NSTabViewItem?) {
		super.tabView(tabView, didSelect: tabViewItem)
		if let window = self.view.window {
			window.title = tabViewItem!.label
			let size = (self.originalSizes[tabViewItem!.label])!
            //let size = tabViewItem!.view!.fittingSize
			let contentFrame = window.frameRect(forContentRect: NSMakeRect(0.0, 0.0,
                                                                           size.width, size.height))
			var frame = window.frame
			frame.origin.y = frame.origin.y + (frame.size.height - contentFrame.size.height)
			frame.size = contentFrame.size
			window.setFrame(frame, display: false, animate: true)
		}
        // The instance of NSTabViewItem is not nil even if the containing window is NIL.
		tabViewItem!.view?.isHidden = false
	}

}
