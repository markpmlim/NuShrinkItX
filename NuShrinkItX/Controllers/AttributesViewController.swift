//
//  AttributesViewController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.

import Foundation

class AttributesViewController: NSViewController
{
	@IBOutlet var pathNameField: NSTextField!
	@IBOutlet var fileTypePullDown: NSPopUpButton!
	@IBOutlet var auxTypeEditField: NSTextField!
	@IBOutlet var readCheckBox: NSButton!
	@IBOutlet var writeCheckBox: NSButton!
	@IBOutlet var invisbleCheckBox: NSButton!
	@IBOutlet var backupCheckBox: NSButton!
	@IBOutlet var renameCheckBox: NSButton!
	@IBOutlet var destroyCheckBox: NSButton!

	var targetTreeNode: NSTreeNode?
	var fullPath = String()
    // Further improvements.
    var currFileType: UInt32 = 0
    var currAuxType: UInt32 = 0
    var currAccess: UInt32 = 0
    var isModified = false

	// Caller must set this view controller's "representedObject" property
	// before its associated window is displayed.
	// KIV. pass over an instance of NUTreeObject directly if the instance of
	// NSTreeNode could not be passed properly; its representedObject might be nil.
	override var representedObject: Any? {
		didSet {
            // This is set by the editAttributes function.
			targetTreeNode = representedObject as? NSTreeNode
		}
	}

	override func awakeFromNib() {
		//Swift.print("awakeFromNib")
		fileTypePullDown.removeAllItems()
		fileTypePullDown.addItems(withTitles: fileTypeNames)
		// The property "state" must be set manually - possibly bug in Interface Builder.
		fileTypePullDown.state = .on
	}

    override func viewDidAppear() {

        // Assumes `targetTreeNode` is passed correctly by the editAttributes function.
		let treeObject = targetTreeNode!.representedObject as! NUTreeObject
		// Remember to set the "document" property of the associated 
		// window controller or the statement below will cause a crash.
		let doc = view.window?.windowController?.document as! NUDocument
		let workDir = doc.archiveOnDiskPath     // has trailing slash
		let relativePath = treeObject.pathName
		self.pathNameField.stringValue = relativePath
		fullPath = workDir! + relativePath
		//Swift.print(fullPath)
		let title =  (relativePath as NSString).lastPathComponent + " Attributes"
		let fmgr = FileManager.default
		var fileAttr: NSDictionary?
		do {
			try fileAttr = fmgr.attributesOfItem(atPath: fullPath) as NSDictionary?
		}
		catch let error as NSError {
			fileAttr = nil
			(NSApp.delegate as! AppDelegate).reportFileErrors(error)
			return
		}

        // Get the various dnbwr fields
        let rawMemoryPtr = malloc(Int(XATTR_NUFX_LENGTH))
		getxattr(fullPath, XATTR_NUFX_NAME,
		         rawMemoryPtr, Int(XATTR_NUFX_LENGTH), 0, XATTR_NOFOLLOW)
		var bufferPtr = rawMemoryPtr!.bindMemory(to: UInt8.self,
		                                         capacity: Int(XATTR_NUFX_LENGTH))
		bufferPtr += 4
        let access: UInt32 = bufferPtr.withMemoryRebound(to: UInt32.self, capacity: 1, {
            (ptr: UnsafeMutablePointer<UInt32>) in
			return ptr.pointee.littleEndian
		})
        destroyCheckBox.state  = (access & 0x80) != 0 ? .on : .off
		renameCheckBox.state   = (access & 0x40) != 0 ? .on : .off
		backupCheckBox.state   = (access & 0x20) != 0 ? .on : .off
		invisbleCheckBox.state = (access & 0x04) != 0 ? .on : .off
		writeCheckBox.state    = (access & 0x02) != 0 ? .on : .off
		readCheckBox.state     = (access & 0x01) != 0 ? .on : .off

        currAccess = access

		fileAttr = TypesConvert.osxFileAttributes(fileAttr as! [String: AnyObject],
		                                          toFileSystem: 1) as NSDictionary?
		currFileType = (fileAttr![PDOSFileType] as! NSNumber).uint32Value
		currAuxType = (fileAttr![PDOSAuxType] as! NSNumber).uint32Value
		fileTypePullDown.selectItem(at: Int(currFileType))
		auxTypeEditField.stringValue = NSString(format:"%04X", currAuxType) as String
		view.window?.setTitleWithRepresentedFilename(title)
		free(rawMemoryPtr)
	}

	// Question: if the window is closed, can this method be called?
	// Yes, but first set window controller to be the window's delegate.
	@IBAction func applyChanges(_ sender: AnyObject) {

        //Swift.print("applyChanges")
		// Get the file/aux types changes from the UI elements
		let newFileType = UInt32(fileTypePullDown.indexOfSelectedItem)
		let newAuxType = UInt32(auxTypeEditField.intValue)
		var fileAttr = NSDictionary()   //We can't use [FileAttributeKey: Any] here

         if (newFileType != currFileType || newAuxType != currAuxType) {
            // Convert prodos file/aux types to HFSType and HFSCreator codes
            currFileType = newFileType
            currAuxType = newAuxType
            isModified = true

            fileAttr = TypesConvert.hfsCodes(forFileType: currFileType,
                                              andAuxType: currAuxType,
                                              toFileSystem: 1) as NSDictionary        // proDOS, DOS3.x, Pascal

            // Modify the file attributes permanently
            let fmgr = FileManager.default
            var newFileAttr: [FileAttributeKey: Any]?
            do {
                try newFileAttr = fmgr.attributesOfItem(atPath: fullPath)
            }
            catch let error as NSError {
                newFileAttr = nil
                (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                return
            }
            //Swift.print(fileAttr[FileAttributeKey.hfsTypeCode.rawValue], fileAttr[FileAttributeKey.hfsCreatorCode.rawValue])
            newFileAttr![FileAttributeKey.hfsTypeCode] = fileAttr[FileAttributeKey.hfsTypeCode.rawValue]
            newFileAttr![FileAttributeKey.hfsCreatorCode] = fileAttr[FileAttributeKey.hfsCreatorCode.rawValue]
            do {
                try fmgr.setAttributes(newFileAttr!,
                                       ofItemAtPath: fullPath)
            }
            catch let error as NSError {
                (NSApp.delegate as! AppDelegate).reportFileErrors(error)
                return
            }
         }
  
		var newAccess: UInt32 = 0
		newAccess |=  destroyCheckBox.state == .on ? 0x80 : 0x00
		newAccess |=   renameCheckBox.state == .on ? 0x40 : 0x00
		newAccess |=   backupCheckBox.state == .on ? 0x20 : 0x00
		newAccess |= invisbleCheckBox.state == .on ? 0x04 : 0x00
		newAccess |=    writeCheckBox.state == .on ? 0x02 : 0x00
		newAccess |=     readCheckBox.state == .on ? 0x01 : 0x00

        //// Modify the extended attributes
         if currAccess != newAccess {
            currAccess = newAccess
            isModified = true

            let rawMemoryPtr = malloc(Int(XATTR_NUFX_LENGTH))
            getxattr(fullPath, XATTR_NUFX_NAME,
                     rawMemoryPtr, Int(XATTR_NUFX_LENGTH), 0, XATTR_NOFOLLOW)
            newAccess = NSSwapLittleIntToHost(newAccess)
            let bufferPtr = rawMemoryPtr!.bindMemory(to: UInt8.self,
                                                     capacity: Int(XATTR_NUFX_LENGTH))
            memcpy(bufferPtr+4, &newAccess, 4)
            setxattr(fullPath, XATTR_NUFX_NAME,
                     rawMemoryPtr, Int(XATTR_NUFX_LENGTH),
                     0, XATTR_NOFOLLOW)
            free(rawMemoryPtr)
         }

        // Have the file attribues been modified?
        if isModified {
            // Yes, update the UI
            let treeObject = targetTreeNode!.representedObject as! NUTreeObject
            let doc = view.window?.windowController?.document as! NUDocument
            let workDir = doc.archiveOnDiskPath
            let treeRec = NUTreeRecord(path: fullPath, inDirectory: workDir!)
            let newTreeObject = NUTreeObject(record: treeRec!)
            // Inform the objects there are changes
            treeObject.willChangeValue(forKey: "fileTypeTxt")
            treeObject.fileTypeTxt = newTreeObject.fileTypeTxt
            treeObject.didChangeValue(forKey: "fileTypeTxt")
            treeObject.willChangeValue(forKey: "auxTypeTxt")
            treeObject.auxTypeTxt = newTreeObject.auxTypeTxt
            treeObject.didChangeValue(forKey: "auxTypeTxt")
            treeObject.willChangeValue(forKey: "access")
            treeObject.access = newTreeObject.access
            treeObject.didChangeValue(forKey: "access")

            doc.mainWinController?.setDocumentEdited(true)
            doc.isDirty = true
        }
	}
}
