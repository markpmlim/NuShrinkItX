//
//  PreviewWindowController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

// An object of this class is instantiated using the storyboard method: instantiateControllerWithIdentifier
class PreviewWindowController: NSWindowController {

    var wTitle: String?
	var hasHexDump: Bool = false

	// loads the text file and pass its contents to the associated view controller
	func formatDocument(atPath path: String) -> Bool {

        var result = false
		let fmgr = FileManager.default
		var attrDict: NSDictionary?	// [FileAttributeKey:Any]?
		do {
			attrDict = try fmgr.attributesOfItem(atPath: path) as NSDictionary
		}
		catch let error as NSError {
			print("Can't get the file's attributes:", error)
			return result
		}
        attrDict = TypesConvert.osxFileAttributes((attrDict! as! [AnyHashable : Any]),
		                                          toFileSystem:1) as NSDictionary?		// prodos, pascal, dos3.x
		let fType = (attrDict![PDOSFileType] as! NSNumber).uint32Value
		let aType = (attrDict![PDOSAuxType] as! NSNumber).uint32Value
		var itemData = fmgr.contents(atPath: path)
		if itemData == nil {
			// kiv: caller should not show the window
			return result
		}
		let tabViewController = self.contentViewController as! NSTabViewController
        let cvcs = tabViewController.children
		let listVC = cvcs[0] as! ListingViewController
		let hexVC = cvcs[1] as! HexViewController

		if (fType == 0x04 || fType == 0xB0 ||
			(fType == 0x50 && aType == 0x5445)) {
			if (fType == 0x04) {
				var mutableData = Data(itemData!)
				var index = mutableData.startIndex
				while index != mutableData.endIndex {
					mutableData[index] &= 0x7f			// strip off each char's msb
					index = index.advanced(by: 1)
				}
				itemData = Data(mutableData)
			}
			let string = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: (itemData! as NSData).bytes.bindMemory(to: Void.self,
                                                                                                                      capacity: itemData!.count)),
			                    length: itemData!.count,
			                    encoding: String.Encoding.macOSRoman,
			                    freeWhenDone: false)
			if (string != nil) {
				listVC.insertString(string!)
				result = true
			}
			self.removeHexTab()
		}
		else if (fType == 0x06 || fType == 0xFC || fType == 0xFF) {
			if (fType == 0xFC) {
				let string = AppleSoft.listing(itemData!)
				if (string != nil) {
					listVC.insertString(string!)
					result = true
				}
				self.removeHexTab()
			}
			else if (fType == 0x06 || fType == 0xFF) {
				let startAddr = (fType == 0xFF) ? 0x2000 : aType
				let string = Disasm65C02.listing(itemData!,
				                                 withAddress: UInt32(startAddr))
				let hexString = Disasm65C02.hexListing(itemData!,
				                                       withAddress: UInt32(startAddr))
				if (string != nil) {
					listVC.insertString(string!)
					result = true
				}
				if (hexString != nil) {
					hexVC.insertString(hexString!)
					hasHexDump = true
					result = true
				}
			}
		}

        listVC.txtView.isEditable = false
		if hasHexDump {
			hexVC.hexView.isEditable = false
		}
		wTitle = (path as NSString).lastPathComponent
		//self.window!.setTitleWithRepresentedFilename(wTitle)	// bug?
		return result
	}

	func removeHexTab() {
		let tabViewController = self.contentViewController as! NSTabViewController
		let tabView = tabViewController.tabView
		tabView.tabViewType = .noTabsNoBorder
		//Swift.print(tabView.tabViewItem(at: 1))

        // Problem below: May not return to caller!
        //let tabViewItems = tabView.tabViewItems
        //Swift.print(tabViewItems)
		//tabView.removeTabViewItem(tabViewItems[1])

        // Workaround:
        // The following instruction is enough to remove the TABView item.
        tabViewController.removeChild(at: 1)
	}

	override func windowTitle(forDocumentDisplayName displayName: String) -> String {
		return wTitle!
	}
}
