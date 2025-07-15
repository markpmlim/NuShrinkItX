//
//  PreferencesWindowController.swift
//  NuShrinkItX
//
//  Created by Mark Lim on 6/26/25.
//  Copyright © 2025 Incremental Innovation. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController
{

    // How do we get the tabView
    override func windowDidLoad() {
        let toolbar = self.window!.toolbar
        let firstToolbarItem = toolbar!.items[0]
        toolbar!.selectedItemIdentifier = firstToolbarItem.itemIdentifier
        self.window?.title = firstToolbarItem.label
        //Swift.print(firstToolbarItem.itemIdentifier)
        //Swift.print("window frame:", self.window!.frame)
        //Swift.print("content view", self.window!.contentView)
        //Swift.print("content view controller", self.window!.contentViewController?.children)
        let generalViewController = self.window!.contentViewController?.children[0]
        //Swift.print("General:", generalViewController!.view.frame)
        let advancedViewController = self.window!.contentViewController?.children[1]
        //Swift.print("Advanced", advancedViewController!.view.frame)
        //Swift.print("content view controller view", self.window!.contentViewController!.view.frame)
        //Swift.print("content view frame:", self.window!.contentView?.frame)

        // We have to manually set the window frame because the frame of the
        // view of the GeneralViewController is not initialised correctly.
        // Size of the window's content rectangle as-laid-specified-in-IB.
        let size = CGSize(width: 382, height: 147)
        let contentFrame = window!.frameRect(forContentRect: NSMakeRect(0.0, 0.0,
                                                                        size.width, size.height))
        var frame = window!.frame
        frame.origin.y = frame.origin.y + (frame.size.height - contentFrame.size.height)
        frame.size = contentFrame.size
        window!.setFrame(frame, display: false, animate: true)
    }
}
