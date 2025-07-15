//
//  GeneralViewController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

class GeneralPreferencesViewController: NSViewController {

    @IBOutlet var saveArchiveText: NSTextField!
	@IBOutlet var autoSaveCheckBox: NSButton!

	// Set up the states(s) correctly
	override func awakeFromNib() {
		let appDefaults = UserDefaults.standard
		let overWriteFlag = appDefaults.bool(forKey: kAutoOverWrite)
		autoSaveCheckBox.state = overWriteFlag ? .on : .off
		let saveAsArchiveName = appDefaults.string(forKey: kSavedArchiveName)
		saveArchiveText.stringValue = saveAsArchiveName!
	}

	private func savePreferences() {
		let appDefaults = UserDefaults.standard
		let newArchiveName = saveArchiveText.stringValue
		var overWriteFlag = false
		// Can we get a NSMixedState?
		if autoSaveCheckBox.state == .on {
			overWriteFlag = true
		}
		appDefaults.set(newArchiveName,
		                forKey: kSavedArchiveName)
		appDefaults.set(overWriteFlag,
		                forKey: kAutoOverWrite)
		appDefaults.synchronize()
	}

	@IBAction func handleApplyButton(_ sender: AnyObject) {
		self.savePreferences()
	}
	
	// This will close the Preferences Window
    // Not required anymore. Just click on Close Box.
	@IBAction func handleCancelButton(_ sender: AnyObject) {
		self.view.window!.close()
	}

	// This must close the Preferences Window
	// todo. check user did not type shk suffix
	@IBAction func handleOKButton(_ sender: AnyObject) {
		self.savePreferences()
		self.view.window!.close()
	}
}
