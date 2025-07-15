//
//  BaseTreeObject.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Foundation


@objc class BaseTreeObject : NSObject, NSCoding, NSCopying {

    // These 2 properties are managed by the NSTreeController object.
	@objc dynamic var children: NSMutableArray?
    @objc dynamic var isLeaf: Bool

    var nodeTitle: String
    weak var parentObject : BaseTreeObject?

	// Mark -- NSCopying
	required override init() {
		nodeTitle = "Untitled"
		children = NSMutableArray()	// KIV: use Swift arrays
		isLeaf = false
		//parentObject = nil
		super.init()
	}

	required convenience init?(coder decoder: NSCoder) {
		self.init()
		let keys = keysForEncoding()
		for key in keys {
			self.setValue(decoder.decodeObject(forKey: key),
			              forKey:key)
		}
	}

	// Mark -- NSCoping protocol method
	func copy(with zone: NSZone? = nil) -> Any {
		let theCopy = type(of: self).init()
		for key in keysForEncoding() {
			theCopy.setValue(self.value(forKey: key),
			                 forKey: key)
		}
		return theCopy
	}

	// Mark -- NSCoding protocol methods
	func keysForEncoding() -> [String] {
		return ["isLeaf", "children", "parentObject"]
	}

	func encode(with encoder: NSCoder) {
		let keys = keysForEncoding()
		for key in keys {
			encoder.encode(self.value(forKey: key),
			               forKey:key)
		}
	}

	/*
 	 Indexed accessor methods to handle objects/items in the array used by the TreeController.
     Swift supports methods like countOf<Key>, <key>AtIndexes: etc. if the objects are
     declared as NSMutableArray or NSMutableSet.
     Reference: Key-Value Coding Programming Guide - Accessor Search Patterns.

     The indexed accessor methods below only modify or access the `children` and `isLeaf` properties.
    */
	func countOfChildren() -> Int {
		////Swift.print("countOfChildren")
		if self.isLeaf {
			return 0
		}
		return self.children!.count
	}

	func insertObject(_ object : BaseTreeObject,
	                  inChildrenAtIndex index:Int) {
        //Swift.print("insertObject:inChildrenAtIndex:")
		if self.isLeaf {
			return
		}
		self.children!.insert(object,
		                      at: index)
	}

	func removeObjectFromChildrenAtIndex(_ index : Int) {
		//Swift.print("removeObjectFromChildrenAtIndex")
		if self.isLeaf {
			return
		}
		self.children!.removeObject(at: index)
	}

	func objectInChildrenAtIndex(_ index : Int) -> AnyObject? {
		//Swift.print("objectInChildrenAtIndex")
		if self.isLeaf {
			return nil
		}
		return self.children![index] as AnyObject?
	}

	func replaceObjectInChildrenAtIndex(_ index: Int,
										withObject object:BaseTreeObject) {
		//Swift.print("replaceObjectInChildrenAtIndex")
		if self.isLeaf {
			return
		}
		self.children!.replaceObject(at: index,
		                             with :object)
	}

	override func setNilValueForKey(_ key: String) {
		if key == "isLeaf" {
			self.isLeaf = false
		}
		else {
			super.setNilValueForKey(key)
		}
	}
}
