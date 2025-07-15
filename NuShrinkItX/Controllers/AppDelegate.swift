//
//  AppDelegate.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//http://zappdesigntemplates.com/create-an-embedded-framework-in-xcode-with-swift/

import Cocoa
import NuFX

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var cleanupWinController: CleanupWindowController?
	var logFilePtr: UnsafeMutablePointer<FILE>?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		//Swift.print("applicationShouldTerminate")
        // When the user quits the application, the NSWindowController method `windowShouldClose`
        // will not be called. We will handle it here.
        var status = NSApplication.TerminateReply.terminateNow
        let docs = NSDocumentController.shared.documents as! [NUDocument]
		for doc in docs {
			if doc.isDirty {
                let alert = NSAlert()
                alert.alertStyle = .warning
                let archiveName = doc.originalURL?.lastPathComponent
                alert.messageText = NSLocalizedString("Changes have been made to the archive \(archiveName!)", comment: "The alert's messageText")
                alert.informativeText = NSLocalizedString("Changes to this archive will be lost once you quit this application",
                                                          comment: "The alert's informativeText")
                // The `Stop` button is the default button. It will respond to the <Enter> key.
                let stopButtonTitle = NSLocalizedString("Stop", comment: "The alert's Stop button")
                alert.addButton(withTitle: stopButtonTitle)
                let saveButtonTitle = NSLocalizedString("Save", comment: "The alert's Save button")
                alert.addButton(withTitle: saveButtonTitle)

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    status = NSApplication.TerminateReply.terminateCancel
                }
                else {
                    // Problem: if there is a folder name with the archive's filename and an
                    // file extension BAK.
                    // For example, if the document's name is "Archive.shk" and there is a folder
                    // named "Archive.shk.BAK" and both are at the same directory location.
                    doc.save(nil)
                    status = doc.didSave ? .terminateNow : .terminateCancel
                }
			}
		}
		return status
	}

	// This is called later.
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
		if (logFilePtr != nil) {
			fclose(logFilePtr)
		}
		//Swift.print("applicationWillTerminate")
	}
	
	// All working directories resides in the "NuShrinkItX" folder
	// Our working directories are created within the system's temporary folder.
	func applicationWorkDirectory() -> URL {
		let basePath = NSTemporaryDirectory()
		let baseURL = URL(fileURLWithPath: basePath)
		return baseURL.appendingPathComponent("NuShrinkItX")
	}

	// This method should be used to report errors returned by NSFileManager.
	func reportFileErrors(_ error: NSError?) {
		if let err = error {
			let docController = NSDocumentController.shared
			docController.presentError(err)
		}
	}

	// Create the directory URL:
	// file:///Users/user_name/Library/Application%20Support/NuShrinkItX
	// if it does not exists.
	// Returns the url of our custom log file but this func does not create it.
	func urlOfLogFile() -> URL? {
		let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
		                                                .userDomainMask, true)
		let baseURL = URL(fileURLWithPath: paths[0])
		//print(baseURL)
		let logDirUrl = baseURL.appendingPathComponent("NuShrinkItX")

		let fmgr = FileManager.default
		var isDir = ObjCBool(false)
		// NB. path must not have a trailing slash; the call below returns
		// false irrespective of whether or not there is a regular file at
		// the location /Users/user_name/Library/Application%20Support
		let exists = fmgr.fileExists(atPath: logDirUrl.path,
		                             isDirectory: &isDir)
		if (exists && !isDir.boolValue) {
			let descr = "A file which is not a folder exists at the location:\(baseURL.path)"
			var infoDict = [String : Any]()
			// message text
			infoDict[NSLocalizedDescriptionKey] = descr
			infoDict[NSLocalizedRecoverySuggestionErrorKey] = "All messages will be send to the system log."
			let error = NSError(domain: NSCocoaErrorDomain, code: 999, userInfo: infoDict)
			let alert = NSAlert(error: error)
			alert.runModal()
			logFilePtr = nil
			return nil
		}
		else if (!exists) {
			//Swift.print("Creating the Application Support folder: %@", logDirUrl);
			do {
				try fmgr.createDirectory(at: logDirUrl,
				                         withIntermediateDirectories: true,
				                         attributes: nil)
			}
			catch let error as NSError {
				self.reportFileErrors(error)
				logFilePtr = nil
				return nil
			}
		}

		// If we get here, the folder NuShrinkItX exists.
		// We just return the url of the log file which may not exist.
		// NB. the appendingPathComponent method automatically adds a /
		// after logDirUrl.
		let logUrl = logDirUrl.appendingPathComponent("messages.log")
		return logUrl
	}

	// The application will NOT create an Untitled Window.
	func applicationShouldOpenUntitledFile(_ theApplication: NSApplication) -> Bool {
		return false;
	}

	// Return a directory url to be used in the reading and writing of an NuFX archive.
	// This is the name of the root directory of the archive (archive-on-disk folder).
	// Its parent directory is the "NuShrinkItX" folder.
	@objc func uniqueDirectoryInApplicationWorkDirectory() -> URL? {

        let newDirName = ProcessInfo.processInfo.globallyUniqueString
		let appWorkDirURL = applicationWorkDirectory()                  // has a trailing slash
		let dirURL = appWorkDirURL.appendingPathComponent(newDirName)   // no trailing slash
		let fmgr = FileManager.default
		var isDir = ObjCBool(false)
		let exists = fmgr.fileExists(atPath: dirURL.path,
		                             isDirectory: &isDir)
		if (exists && isDir.boolValue) {
			// This should not happened; todo put up NSAlert here?
			NSLog("A folder already exists")
			return nil
		}
		else {
			//NSLog("Creating the working folder: %@", dirURL);
			do {
				try fmgr.createDirectory(at: dirURL,
				                         withIntermediateDirectories: true,
				                         attributes: nil)
			}
			catch let error as NSError {
				// KIV: report error
				self.reportFileErrors(error)
				return nil
			}
			return dirURL
		}
	}

	// Use to create the url of a regular file for I/O - not used
	func uniqueURLInApplicationWorkDirectory() -> URL? {

        let newFilename = ProcessInfo.processInfo.globallyUniqueString
		let appWorkDirURL = applicationWorkDirectory()
		let fmgr = FileManager.default
		var isDir = ObjCBool(false)
		let exists = fmgr.fileExists(atPath: appWorkDirURL.path,
		                             isDirectory: &isDir)
		if (exists && !isDir.boolValue) {
			// This should not happened; todo put up NSAlert here?
			Swift.print("A file which is not a folder exists")
		}
		else if (!exists) {
			//NSLog("Creating the Application Support folder: %@", appSupportURL);
			do {
				try fmgr.createDirectory(at: appWorkDirURL,
				                         withIntermediateDirectories: true,
				                         attributes: nil)
			}
			catch let error as NSError {
				self.reportFileErrors(error)
				return nil
			}
		}
		let theURL = appWorkDirURL.appendingPathComponent(newFilename)
		return theURL
	}

	@IBAction func showHelp(_ sender: AnyObject) {

		let pathToDocFile = Bundle.main.path(forResource: "Documentation",
		                                     ofType: "rtf")
		NSWorkspace.shared.openFile(pathToDocFile!)
 
	}

	// We assume nobody gets funny and deletes console.log
	@IBAction func showLogs(_ sender: AnyObject) {

        if logFilePtr != nil {
			fflush(logFilePtr)
			guard let url = self.urlOfLogFile() else {
				return
			}

            var fileData: Data?
			do {
				try fileData = Data(contentsOf: url,
				                    options: .mappedIfSafe)
			}
			catch let error1 as NSError {
				NSLog("showError: %@", error1)
				return
			}

            guard String(data: fileData!,
                         encoding: .utf8) != nil else {
				return
			}
			NSWorkspace.shared.openFile(url.path,
                                        withApplication: "Console.app")
		}
	}

	@IBAction func removeLogs(_ sender: AnyObject) {
		if (logFilePtr != nil) {
			fflush(logFilePtr)
			rewind(logFilePtr)
			ftruncate(fileno(logFilePtr), 0)
		}
	}

	//https://stackoverflow.com/questions/33260808/how-to-use-instance-method-as-callback-for-function-which-takes-only-func-or-lit
	func applicationDidFinishLaunching(_ aNotification: Notification) {

		if let url = self.urlOfLogFile() {
			// Send all NSLog messages to a custom console log file
			let logPath = url.path
			logFilePtr = freopen(logPath , "a+", stderr);
		}
		else {
			// All NSLog messages will be output to system log
			logFilePtr = nil
		}

		// Set up a default extended attributes object
		var tmp16: UInt16
		var tmp32: UInt32

		// Setup the initial extended attributes buffer
		let rawMemoryPtr = malloc(Int(XATTR_NUFX_LENGTH))
		let bufferPtr = rawMemoryPtr!.bindMemory(to: UInt8.self,
		                                         capacity: Int(XATTR_NUFX_LENGTH))
		memset(bufferPtr, 0, Int(XATTR_NUFX_LENGTH))
		tmp16 = NSSwapHostShortToLittle(1)		// file_sys_id: ProDOS
		memcpy(bufferPtr, &tmp16, 2)
		tmp16 = NSSwapHostShortToLittle(0x2f)	// file_sys_info: /
		memcpy(bufferPtr+2, &tmp16, 2)
		tmp32 = NSSwapHostIntToLittle(0xe3)		// full access
		memcpy(bufferPtr+4, &tmp32, 4)
		tmp16 = NSSwapHostShortToLittle(UInt16(kNuStorageUnknown.rawValue))
		memcpy(bufferPtr+8, &tmp16, 2)
		//Swift.print(bufferPtr)
		// Convert NSDate to NuDateTime - may not be needed
		let now = Date()
		var when = time_t(now.timeIntervalSince1970)
		var date = NuDateTime()
		UNIXTimeToDateTime(&when, &date)
		memcpy(bufferPtr+10, &date, 8)
		defaultExtendedAttributes = Data(bytes: UnsafePointer<UInt8>(bufferPtr),
		                                 count: Int(XATTR_NUFX_LENGTH))
		free(rawMemoryPtr)

		// Register program's defaults
		let defaultPrefsFile = Bundle.main.path(forResource: "defaultPrefs",
		                                        ofType: "plist")
		let defaultPreferences = NSDictionary(contentsOfFile: defaultPrefsFile!)
		UserDefaults.standard.register(defaults: defaultPreferences! as! [String : AnyObject])
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Secondary"), bundle: nil)
        cleanupWinController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("CleanupWindowController")) as? CleanupWindowController
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return false
	}

    // The delegate of NSApplication is part of the responder chain.
	// The function below is connected to the `New Archive...` menu item in IB.
    // So sender is: `New Archive...` menu item.
	@IBAction func newDocument(_ sender: AnyObject) {

        let appDefaults = UserDefaults.standard
		let savedFilename = appDefaults.string(forKey: kSavedArchiveName)
		// Put up a dialog to ask for the file name.
		let svPanel = NSSavePanel()
		svPanel.canCreateDirectories = true
		svPanel.prompt = "Create"
		svPanel.nameFieldStringValue = savedFilename!
		let button = svPanel.runModal()

        if (button == .OK) {
			let fmgr = FileManager.default
			let dirURL = svPanel.url?.deletingLastPathComponent()
			// The file may not exist so we test its containing folder instead.
			if fmgr.isWritableFile(atPath: dirURL!.path) {
				var url = svPanel.url!.deletingPathExtension()
				url = url.appendingPathExtension("shk")
				let overWrite = appDefaults.bool(forKey: kAutoOverWrite)
				let exists = fmgr.fileExists(atPath: url.path)
				if !exists || (exists && overWrite) {
					let docController = NSDocumentController.shared
					docController.newDocument(nil)		// This will call NUDocument's init method.
					let newDoc = docController.currentDocument as! NUDocument
					// We must set the document's "originalURL" property in case the user
					// 1) click on the close box or worse
					// 2) press Cmd-Q to quit.
					newDoc.originalURL = svPanel.url
					newDoc.originalURL = newDoc.originalURL!.deletingPathExtension()
					// The NuFX library only supports creating SHK archives.
					newDoc.originalURL = newDoc.originalURL!.appendingPathExtension("shk")
					newDoc.mainWinController?.window?.title = newDoc.originalURL!.lastPathComponent
					// KIV: more variables to be initialized?
				}
				else {
					// KIV: The file exists; create a unique path name?
					//Swift.print("The file exists")
					var infoDict = [String : Any]()
					// Message text
					infoDict[NSLocalizedDescriptionKey] = "The file already exists at the selected destination"
					// Informative text
					infoDict[NSLocalizedRecoverySuggestionErrorKey] = "Your preference is not to overwrite existing files." +
													"Use the General Preferences Window to change it."
					let buttonTitles = ["OK"]
					infoDict[NSLocalizedRecoveryOptionsErrorKey] = buttonTitles
					let error = NSError(domain: NSCocoaErrorDomain, code: 999, userInfo: infoDict)
					let alert = NSAlert(error: error)
					alert.runModal()
				}
			}
			else {
				let error = NSError(domain: NSCocoaErrorDomain,
				                    code: NSFileWriteVolumeReadOnlyError,
				                    userInfo: nil)
				let alert = NSAlert(error: error)
				alert.runModal()
			}
		}
	}


    // To remove extended attributes from all files within one or more selected folder
	// bug - nested blocks?
	@IBAction func removeExtendedAttributes(_ sender: AnyObject) {
		let op = NSOpenPanel()
		op.allowsMultipleSelection = true
		op.canChooseFiles = false
		op.canChooseDirectories = true
		op.prompt = "Clean"
		op.begin(completionHandler: {

            (result: NSApplication.ModalResponse) -> Void in

            if .OK == result {
				let fmgr = FileManager.default
				let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]

				let dirUrls = op.urls
				let session = NSApp.beginModalSession(for: (self.cleanupWinController?.window)!)
				var isCancelled = false;

				for dirURL in dirUrls {
					if let directoryEnumerator = fmgr.enumerator(at: dirURL,
					                                             includingPropertiesForKeys: nil,
					                                             options: options,
					                                             errorHandler: {
						// Error handler closure
						url, error in
						//Swift.print("`directoryEnumerator` error: \(error).")
						return true
					}) {
						// directoryEnumerator not nil
						while let theURL : URL = directoryEnumerator.nextObject() as? URL {
							var isDir = ObjCBool(false)
							if fmgr.fileExists(atPath: theURL.path,
													isDirectory:&isDir) && !isDir.boolValue {

								// We are only interested in leaves
								let eaSize = getxattr(theURL.path,
								                      XATTR_NUFX_NAME, nil,
								                      ULONG_MAX, 0, XATTR_NOFOLLOW)
								if eaSize > 0 {
									removexattr(theURL.path, XATTR_NUFX_NAME, XATTR_NOFOLLOW)
								}
							} // leaves

							if (NSApp.runModalSession(session) != .continue) {
								//NSLog(@"exit prematurely %@", [cleanController window]);
								// flag we will exit the for loop as well.
								isCancelled = true
								break				// exit the while loop.
							}
						} // while
					} // let
					if isCancelled {
						break
					}
					// Give the main loop some time to run
                    RunLoop.current.limitDate(forMode: RunLoop.Mode.default)
				} // for

				NSApp.endModalSession(session)
				self.cleanupWinController!.window!.orderOut(self)
				if !isCancelled {
					var infoDict = [String : Any]()
					// Message text
					infoDict[NSLocalizedDescriptionKey] = "The extended attributes of all files within the selected folders have been removed."
					// Informative text
					//infoDict[NSLocalizedRecoverySuggestionErrorKey] = ""
					let buttonTitles = ["OK"]
					infoDict[NSLocalizedRecoveryOptionsErrorKey] = buttonTitles
					let error = NSError(domain: NSFilePathErrorKey, code: NSFileWriteVolumeReadOnlyError, userInfo: infoDict)
					let alert = NSAlert(error: error)
					alert.runModal()
				} // isCancelled
			} // if
		})
	}
}

