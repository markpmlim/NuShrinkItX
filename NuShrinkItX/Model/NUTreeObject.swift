//
//  NuTreeObject.swift
//	NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Foundation

/*
 This is the "representedObject" of the NSTreeNode widget.
 The objects of this class are accessed using the `content` property
 of the `treeController` var of the class `TreeViewController`.
 */
@objc class NUTreeObject : BaseTreeObject {
    // There is no starting / but an ending / if `pathName` is a folder.
    // In this app, it is relative to the archive-on-disk pathname.
	var pathName: String

    // All the properties below are managed by the NSTreeController object.
	@objc dynamic var fileName: String
	@objc dynamic var fileTypeTxt: String
	@objc dynamic var auxTypeTxt: String
	@objc dynamic var creationDate: String
	@objc dynamic var modificationDate: String
	@objc dynamic var fileSystemTxt: String		// ProDOS, DOS3.3 etc
	@objc dynamic var size: UInt32
	@objc dynamic var access: String

	// Designated initializer
	init(record: NUTreeRecord) {
		self.pathName = record.pathName
		self.fileName =  (record.pathName as NSString).lastPathComponent
		self.fileTypeTxt = record.fileTypeTxt
		if self.fileTypeTxt == "DIR" {
			self.creationDate = String()
			self.modificationDate = String()
			self.fileSystemTxt = String()
			self.auxTypeTxt =  String()
            self.size = 0
			self.access =  String()
		}
		else {
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "yyyy-MM-dd"
			self.creationDate = dateFormatter.string(from: record.creationDate)
			self.modificationDate = dateFormatter.string(from: record.modificationDate)
			self.fileSystemTxt = record.format
			self.auxTypeTxt =  record.auxTypeTxt
            self.size = record.size
			self.access =  record.access
		}
		super.init()
		parentObject = nil			// The parent object will be set by the addChild: method
        // NB. all folders must end with a slash.
		isLeaf = pathName.hasSuffix("/") ? false : true
		if isLeaf {
			children = nil
		}
	}

    // This seems necessary or the compiler will complain
    required init() {
        //Swift.print("Never called at all?")
        self.pathName = ""
        self.fileName = ""
        self.fileTypeTxt = ""
        self.auxTypeTxt = ""
        self.creationDate = String()
        self.modificationDate = String()
        self.fileSystemTxt = ""
        self.size = 0
        self.access = ""
        super.init()
    }
    
	// Name of the properties must be added to the original set of keys.
    // cf. BaseTreeObject.swift
	override func keysForEncoding() -> [String] {
		let keys = super.keysForEncoding() +
			["pathName", "fileName", "fileTypeTxt", "auxTypeTxt", "creationDate",
				"modificationDate", "fileSystemTxt", "size", "access"]
		return keys
	}

	// Use this class method to create a proxy root object for NUTree to use.
	// It is called by NUTree's buildWithPaths:inDirectory: class function.
	class func rootObject() -> NUTreeObject {

		let record = NUTreeRecord()
		record.pathName = "/"
		record.fileTypeTxt = "DIR"
		record.auxTypeTxt = ""
		record.creationDate = Date()
		record.modificationDate = Date()
		record.format = ""
		record.size = 0
		record.access = ""
		let obj = NUTreeObject(record: record)
	/*
		Notes:
		If the proxy root is created with a slash, some tree objects will end up
		with a leading slash. We don't want their "pathName" property to have a leading
		slash. These tree objects may be created from situations where the set of
		original paths is an incomplete flat list like those created by ShrinkItGS
		which are pathnames of the leaves.
	*/
		obj.pathName = String()		// empty strings
		obj.fileName = String()
		return obj
	}

	// An object of this class will receive this message when the receiver
	// (an instance of NUTreeObject) needs to arrange the `pathnames` alphabetically.
	@objc func compare(_ other : NUTreeObject) -> ComparisonResult {
		return self.pathName.localizedCaseInsensitiveCompare(other.pathName)
	}

	// unused
	@objc func compare2(_ obj1 : NUTreeObject, obj2 : NUTreeObject) ->Bool {
		let str1 = obj1.pathName
		let str2 = obj2.pathName
		return str1 < str2
	}
	
	// Add "entry" to a tree object's "children" collection
	func add(child entry: NUTreeObject) -> Bool {

        guard self.children != nil else {
            // The receiver of this message is a leaf.
            return true
        }

        // If we get here, the receiver is a folder.
		self.children!.add(entry)
		entry.parentObject = self
		self.children!.sort(using: #selector(NUTreeObject.compare(_:)))
		return true
	}

/*
	 May create a sub-folder node. Return nil if receiver is a leaf or the
	 targeted "name" is not found.
	 However, if the "createIfNotPresent" flag is YES, a sub-folder entry will
	 will created provided it does not exist and the receiver is itself a parent
	 entry.
 */
	func childDirectory(name: String,
						createIfNotPresent flag: Bool) -> NUTreeObject? {
		var childObject : NUTreeObject? = nil
		for entry in self.children! {
			if (entry as! NUTreeObject).fileName == name && !(entry as! NUTreeObject).isLeaf {
				childObject = entry as? NUTreeObject
				break
			}
		}

		// This branch may not be taken if the pathnames are in pre-order arrangement.
		if childObject == nil && flag && !self.isLeaf {
			let record = NUTreeRecord()
			// This sub-folder is definitely missing; the associated child object must be created.
			// A trailing slash is added to flag it is a folder.
			// Avoid using NRURL; cast instances of String to NSString where needed.
			record.pathName = (self.pathName as NSString).appendingPathComponent(name) + "/"
			record.fileTypeTxt = "DIR"
			record.auxTypeTxt = ""
			record.creationDate = Date()
			record.modificationDate = Date()
			record.format = ""		// filesystem: ProDOS, DOS3.3 etc
			record.size = 0
			record.access = ""
			childObject = NUTreeObject(record: record)
			// "pathName" must have a trailing slash to indicate it is a sub-folder.
			add(child: childObject!)
		}
		return childObject
	}

	// This method is called when we add a tree object to the root tree object.
	// The root tree object shouldn't be nil. Neither is the tree object itself.
	// NB. Both the node & the root node must be created before this method is called
    func add(to rootObject: NUTreeObject?) -> Bool {
		guard rootObject != nil else {
            // In case we may be passed a NIL root node!
            return false
        }

        var entryKind = rootObject
        let leadingPath: NSString = (self.pathName as NSString).deletingLastPathComponent as NSString
        let components = leadingPath.pathComponents		// [String]

        /*
         We use a for-loop to descend the directory tree, creating any
         child tree object(s) corresponding missing sub-folder(s) if necessary.
        */
        for component in components {
            entryKind = entryKind!.childDirectory(name: component,
                                                  createIfNotPresent: true)
        }
        guard let directoryFolder = entryKind else {
            return true
        }
        // Add "self" as a child to the directoryFolder.
        return directoryFolder.add(child: self)
    }
}
