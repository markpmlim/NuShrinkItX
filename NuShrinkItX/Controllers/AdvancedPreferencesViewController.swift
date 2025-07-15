//
//  AdvancedPreferences.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.


import Cocoa

class AdvancedPreferencesViewController: NSViewController {
	// We need 8 radio button outlets so that we can set
	// the correct one to an ON state
	@IBOutlet var noCompressionButton: NSButton!
	@IBOutlet var huffmanButton: NSButton!
	@IBOutlet var lzw1Button: NSButton!
	@IBOutlet var lzw2Button: NSButton!
	@IBOutlet var lzc12Button: NSButton!
	@IBOutlet var lzc16Button: NSButton!
	@IBOutlet var zipButton: NSButton!
	@IBOutlet var bzipButton: NSButton!
	var radioButtonTag: Int?

	// set up the option(s) correctly
	// Cocoa does not allow a common outlet so we do it the hard way
	override func awakeFromNib() {
        //Swift.print("AdvancedPreferencesViewController: awakeFromNib")
		let appDefaults = UserDefaults.standard
		let choice = appDefaults.integer(forKey: kCompressionFormat)
		radioButtonTag = choice
		switch(choice) {
		case 0:
			noCompressionButton.state = .on
		case 1:
			huffmanButton.state = .on
		case 2:
			lzw1Button.state = .on
		case 3:
			lzw2Button.state = .on
		case 4:
			lzc12Button.state = .on
		case 5:
			lzc16Button.state = .on
		case 6:
			zipButton.state = .on
		case 7:
			bzipButton.state = .on
		default:
			lzw2Button.state = .on
		}
	}

	func savePreferences() {
		let appDefaults = UserDefaults.standard
		appDefaults.set(radioButtonTag!,
		                forKey: kCompressionFormat)
		appDefaults.synchronize()
	}

	// Must have a common action for the 8 radio buttons to act as a group
	// i.e. selecting one button will unselect all other related buttons
	@IBAction func radioButtonHit(_ sender: AnyObject) {
		let button = sender as! NSButton
		radioButtonTag = button.tag
	}

	@IBAction func handleApplyButton(_ sender: AnyObject) {
		self.savePreferences()
	}

	// This must close the Preferences Window - not needed anymore
	@IBAction func handleCancelButton(_ sender: AnyObject) {
		self.view.window!.close()
	}

	// This must close the Preferences Window - not needed anymore
	// todo. check user did not type shk suffix
	@IBAction func handleOKButton(_ sender: AnyObject) {
		self.savePreferences()
		self.view.window!.close()
	}
}
