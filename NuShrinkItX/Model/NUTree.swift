//
//  NUTree.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

// Note: casting [NUTreeObject] to NSMutableArray may fail
class NUTree: NSObject {

    /*
     Inputs:
         flatLists:             an array of fullpathnames of files/folders residing in
                                the "targetDirectoryPath" folder.
         targetDirectoryPath:   the full pathname of the archive-on-disk folder or
                                the proposedParent folder during a drag-and-drop operation.
     Returns an NSMutableArray of NUTreeObjects.
     NB. An instance of NSMutableArray is created so that indexed accessor methods like
     countOf<Key>, <key>AtIndexes: etc. can be called by other Swift methods.
	*/
	class func buildWithPaths(_ flatLists: [String],
	                          inDirectory targetDirectoryPath: String) -> NSMutableArray?
    {
		var treeObjects = [NUTreeObject]()
		for path in flatLists {
			let treeRec = NUTreeRecord(path: path,
			                           inDirectory: targetDirectoryPath)
			let treeObject = NUTreeObject(record: treeRec!)
			treeObjects.append(treeObject)
			//Swift.print("\(treeRec!.pathName): \(treeRec!.fileTypeTxt) : \(treeRec!.auxTypeTxt): \(treeRec!.creationDate): \(treeRec!.modificationDate) : \(treeRec!.size)")
		}

		// Insert the tree objects into their proper positions within the tree;
		// the "pathName" property of the NUTreeObject is used for this purpose.
		let proxyRootObj = NUTreeObject.rootObject()
		for treeObject in treeObjects {
            treeObject.add(to: proxyRootObj)
		}
		
		// Top level children will become the roots of a multi-rooted tree, their
		// "parentObject" properties has been set to "proxyRootObj" and is not relevant
		// anymore. So we might as well set them to NIL.
		let rootObjects = NSMutableArray()
		if proxyRootObj.children!.count != 0 {
			for child in proxyRootObj.children! {
				rootObjects.add(child as! NUTreeObject)
				(child as! NUTreeObject).parentObject = nil
			}
			return rootObjects
		}
		else {
			return nil
		}
	}
}
