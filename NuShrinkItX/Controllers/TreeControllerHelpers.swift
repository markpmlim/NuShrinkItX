//
//  TreeControllerHelpers.swift
//  NuShrinkItX
//
//  Created by Mark Lim Pak Mun on 23/06/2025.
//  Copyright © 2025 Mark Lim. All rights reserved.
//

// Helper functions
extension TreeViewController {

    // Manually set the document as dirty.
    // We have disabled autoSave. We can't use the method "updateChangeCount" either.
    func setDirty() {
        let win = view.window
        win?.windowController!.setDocumentEdited(true)
        document!.isDirty = true
        willChangeValue(forKey: "totalSize")
        self.totalSize = archiveSize()
        didChangeValue(forKey: "totalSize")
    }

    // The instance of NSTreeController will manage the array of NUTreeObject.
    // Fix the `pathName` and `parentObject` properties of the instance
    // of NUTreeObject that is represented by the `node` parameter.
    // What about the `children` & `isLeaf` properties of NUTreeObject?
    // Ans: managed by the tree controller.
    func recursiveFix(_ node: NSTreeNode) {

        let treeObj = node.representedObject as! NUTreeObject
        if node.indexPath.count != 1 {
            // The node is not at the root level of the directory tree.
            //Swift.print("non-root level node")
            let parentObj = node.parent?.representedObject as! NUTreeObject
            let newPath = parentObj.pathName + treeObj.fileName
            treeObj.parentObject = parentObj
            if node.isLeaf {
                //Swift.print("Leaf node at sub-folder level")
                treeObj.pathName = newPath
                treeObj.isLeaf = true
            }
            else {
                //Swift.print("Non-leaf node at sub-folder level")
                treeObj.pathName = newPath + "/"        // folders should have a trailing slash.
                treeObj.isLeaf = false
            }
        }
        else {
            // `node` is at root level
            treeObj.parentObject = nil
            if node.isLeaf {
                // We have a leaf node at root level.
                //Swift.print("leaf node at root level")
                treeObj.pathName = treeObj.fileName
                treeObj.isLeaf = true
            }
            else {
                // Non-leaf node at root level.
                //Swift.print("non-leaf node at root level")
                treeObj.pathName = treeObj.fileName + "/"   // folders should have a trailing slash.
                treeObj.isLeaf = false
            }
        }

        if (!node.isLeaf) {
            guard let childNodes = node.children
            else {
                return
            }
            // Move down the tree
            for childNode in childNodes {
                recursiveFix(childNode)
            }
        }
    }

    // This method not only fix the parentObjects but also the pathnames.
    // This is the preferred method because it does not rely on the
    // `parentObject` property being set correctly.
    func fixPaths() {

        let proxyRoot = self.treeController.arrangedObjects
        guard let childNodes = proxyRoot.children
        else {
            return
        }
        // Root level nodes of the directory tree
        //Swift.print("# of children", childNodes.count)
        for childNode in childNodes {
        /*
            let childObj = childNode.representedObject as! NUTreeObject
            Swift.print(childNode.indexPath.count,
                        childObj.pathName)
        */
            recursiveFix(childNode)
        }
    }

    // We don't have to be concerned about FinderInfo.
    func copyFile(atPath srcPath: String,
                  toPath destPath: String,
                  createIfNeeded: Bool) throws {

        let fmgr = FileManager.default
        var attr: [FileAttributeKey : Any]?
        do {
            // Note: extended attributes are not returned by the method below.
            attr = try fmgr.attributesOfItem(atPath: srcPath)
        }
        catch let error as NSError {
            attr = nil
            throw NSError(domain: error.domain, code: error.code, userInfo: error.userInfo)
        }

        let dataContents = fmgr.contents(atPath: srcPath)
        //Swift.print("createFileAtPath")
        // This should write out the data fork of the destination file.
        fmgr.createFile(atPath: destPath,
                        contents: dataContents,
                        attributes: attr)
        
        // We have to get the resource fork of the src file and set the
        // resource fork of the dest file. OS X cannot do it if the methods
        // createFileAtPath:, copyItemAtURL and copyItemAtPath are used.
        // On the other hand, the methods moveItemAtURL and moveItemAtPath
        // will support "moving" of extended attributes.
        let rsrcSize = getxattr(srcPath, XATTR_RESOURCEFORK_NAME,
                                nil, ULONG_MAX, 0, XATTR_NOFOLLOW)

        if rsrcSize > 0 {
            //Swift.print("Writing resource fork", destPath)
            let buf = malloc(rsrcSize)
            getxattr(srcPath, XATTR_RESOURCEFORK_NAME,
                     buf, rsrcSize, 0, XATTR_NOFOLLOW)

            setxattr(destPath, XATTR_RESOURCEFORK_NAME,
                     buf, rsrcSize, 0, XATTR_NOFOLLOW)
            free(buf)
        }

        // This flag is true if it's a drop from Finder.
        // The following are also considered to be drops from Finder:
        // inter-doc and inter-app drops
        if (createIfNeeded) {
            let fileSize = ((attr![FileAttributeKey.size] as! NSNumber).uint64Value)
            let bufferPtr = malloc(Int(XATTR_NUFX_LENGTH)).bindMemory(to: UInt8.self,
                                                                      capacity: Int(XATTR_NUFX_LENGTH))
            var tmp16: UInt16 = 0
            // Attempt to get the custom extended attributes
            let eaSize = getxattr(srcPath, XATTR_NUFX_NAME,
                                  nil, ULONG_MAX, 0, XATTR_NOFOLLOW)
            if (eaSize < 0) {
                // If doesn't exist, create one by modifying the default set
                // of extended attributes
                // Problem: if files are from DiskImages with file systems DOS 3.2, DOS 3.3, Pascal?
                memcpy(bufferPtr, (defaultExtendedAttributes as NSData).bytes,
                       defaultExtendedAttributes.count)
                // Is this necessary? Will the NuFX lib set the storage_type for us? Yes
                if (rsrcSize > 0) {
                    tmp16 = NSSwapHostShortToLittle(UInt16(kNuStorageExtended.rawValue))
                    memcpy(bufferPtr+8, &tmp16, 2)
                }
                else if (fileSize <= 512) {
                    // seedling, sapling, tree? -> depends on the filesize
                    tmp16 = NSSwapHostShortToLittle(UInt16(kNuStorageSeedling.rawValue))
                    memcpy(bufferPtr+8, &tmp16, 2)
                }
                else if (fileSize > 512 && fileSize < 133376) {
                    tmp16 = NSSwapHostShortToLittle(UInt16(kNuStorageSapling.rawValue))
                    memcpy(bufferPtr+8, &tmp16, 2)
                }
                else if (fileSize >= 133376 && fileSize <= 16777216) {
                    tmp16 = NSSwapHostShortToLittle(UInt16(kNuStorageTree.rawValue))
                    memcpy(bufferPtr+8, &tmp16, 2)
                }
                else {
                    tmp16 = NSSwapHostShortToLittle(UInt16(kNuStorageUnknown.rawValue))
                    memcpy(bufferPtr+8, &tmp16, 2)
                }
            }
            else {
                // Files dropped from Finder may already have extended attributes attached
                // as a result of a previous drag-and-drop action from an NuFX document
                // to Finder. So we need to fix the fileSysInfo value; fileSysID is not changed
                getxattr(srcPath, XATTR_NUFX_NAME,
                         bufferPtr, Int(XATTR_NUFX_LENGTH), 0, XATTR_NOFOLLOW)
                //tmp16 = NSSwapHostShortToLittle(1)    // proDOS
                //memcpy(bufferPtr, &tmp16, 2)
                tmp16 = NSSwapHostShortToLittle(0x2f)    // slash
                memcpy(bufferPtr+2, &tmp16, 2)
            }
            // Must change the archived time of this file.
            let now = Date()
            var when = time_t(now.timeIntervalSince1970)
            var date = NuDateTime()
            UNIXTimeToDateTime(&when, &date)
            memcpy(bufferPtr+10, &date, 8)
            setxattr(destPath, XATTR_NUFX_NAME,
                     bufferPtr, Int(XATTR_NUFX_LENGTH),
                     0, XATTR_NOFOLLOW)
            free(bufferPtr)
        }
    }

    // Delete a file from the archive-on-disk.
    func deleteItem(at node: NSTreeNode) {

        let targetTreeObject = node.representedObject as! NUTreeObject
        // Get the relative pathname
        let targetPathname = targetTreeObject.pathName
        // Remember `archiveOnDiskPath` has a trailing slash.
        let absolutePath = self.document!.archiveOnDiskPath + targetPathname
        let fmgr = FileManager.default
        do {
            // The method below works for folders too.
            // We assume any resource fork will also be deleted.
            try fmgr.removeItem(atPath: absolutePath)
        }
        catch let error as NSError {
            (NSApp.delegate as! AppDelegate).reportFileErrors(error)
        }
    }

}
