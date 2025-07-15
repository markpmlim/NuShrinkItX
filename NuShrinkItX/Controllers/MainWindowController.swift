//
//  MainWindowController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Foundation

class MainWindowController: NSWindowController, NSWindowDelegate {
	@IBOutlet weak var searchField: NSSearchField!
	@IBOutlet weak var arrayController: NSArrayController!
	var tableViewController: TableViewController?
	
	// This instance variable is set by its associated document object
	// when it adds this object to its list of window controllers.
	// On window closing, its value will be set to nil
	override var document: AnyObject? {
		didSet {
			// The property `contentViewController` is declared in macOS 10.10.
			// This property is very important in this application because
			// inter-document drag-and-drops depends on getting access to it.
			let tabViewController = self.contentViewController as! NSTabViewController

            // Setting the view controllers' `representObject` property in the NUDocument class
			// might lead to a crash; the solution is to set it here.
            for object in tabViewController.children {
				let childViewController = object as NSViewController
				childViewController.representedObject = self.document		// instance of NUDocument
			}

            // We need to send a message to the following view controller.
            tableViewController = tabViewController.children[1] as? TableViewController
		}
	}

    // When the user types in the `Search Box` on the upper-left corner of the window.
	@IBAction func handleQuery(_ sender: AnyObject) {
		let tabViewController = self.contentViewController as! NSTabViewController
		let len = searchField.stringValue.lengthOfBytes(using: String.Encoding.utf8)
		if (len > 0) {
			let doc = self.document as! NUDocument
			doc.fileEntries = doc.readFileEntries()
			// Show the tableview
			tabViewController.tabView.selectTabViewItem(at: 1)
			tableViewController?.fileFilter()
		}
		else {
			// Display outline view
			tabViewController.tabView.selectTabViewItem(at: 0)
		}
	}

    /*
     NB. In IB, bind the window's delegate to the WindowController object
     since "windowShouldClose:" is a method of NSWindowDelegate.
     This method is called when the window's close box is clicked.
     It will not be called when the application quits.
    */
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        var shouldClose = true
        let doc = document as! NUDocument
        if doc.isDirty {
            let alert = NSAlert()
            alert.alertStyle = .warning
            let archiveName = doc.originalURL?.lastPathComponent
            alert.messageText = NSLocalizedString("Changes have been made to the archive \(archiveName!)", comment: "The alert's messageText")
            alert.informativeText = NSLocalizedString("Changes to this archive will be lost once you close the ShrinkIt document",
                                                      comment: "The alert's informativeText")
            // The `Cancel` button is the default button. It will respond to the <Enter> key. ESC doesn't work at all.
            // NB. This `Cancel` button is the First Button (not the usual `Cancel` button).
            let cancelButtonTitle = NSLocalizedString("Cancel", comment: "The alert's cancel button")
            alert.addButton(withTitle: cancelButtonTitle)
            let closeButtonTitle = NSLocalizedString("Close", comment: "The alert's close button")
            alert.addButton(withTitle: closeButtonTitle)
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                shouldClose = false
                break
            case .alertSecondButtonReturn:
                shouldClose = true
                break
            default:
                break
            }
        }
        return shouldClose
    }
}
