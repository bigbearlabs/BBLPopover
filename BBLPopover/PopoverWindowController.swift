//
//  PopoverWindowController.swift
//  contexter
//
//  Created by ilo on 01/06/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

import Foundation
import SwiftNotificationCenterMac
import BBLBasics



@objc
public protocol PopoverWindowSubject {
  
  @objc
  var window: NSWindow? { get }
  
  func refresh(popoverFrame: NSRect)
}


public protocol PopoverWindowProvider {
  
  func
    on(windowVisible: Bool, frame: CGRect)
  
}

extension PopoverWindowController: PopoverWindowProvider {
  
}

/// we convolutedly synchronise popover behaviour to the window controller.
/// we tried stealing OverlayWindow's content view, which caused unwanted app activation when interacting (because the popover window was not a non-activating panel).
open class PopoverWindowController: NSObject, NSPopoverDelegate {
  
  let popover = NSPopover()
  let anchorView: NSView
  
  let contentWindowController: PopoverWindowSubject
  
  
  public init(anchorView: NSView, contentWindowController: PopoverWindowSubject) {
    self.anchorView = anchorView
    self.contentWindowController = contentWindowController
    
    //    self.contentWindowController.setupWindowForOverlay()
    
    super.init()
    
    self.popover.delegate = self
    
    observePopoverWindowSubject()
  }
  
  func observePopoverWindowSubject() {
    Broadcaster.register(PopoverWindowProvider.self, observer: self)
  }
  
  public func on(windowVisible: Bool, frame: CGRect) {
    if windowVisible {
      
      self.show(referenceFrame: frame)
    }
    else {
      self.hide()
    }
  }
  
  
  // MARK: - visibility
  
  open func show(referenceFrame: CGRect) {
    
    // show the popover using the same size as the overlay.
    self.popover.contentViewController = BlankViewController(frame: CGRect(origin: .zero, size: referenceFrame.size))
    self.popover.contentSize = referenceFrame.size
    self.popover.show(relativeTo: .zero, of: anchorView, preferredEdge: .minY)
      // TODO find where  anchor view position is set and consolidate to here.
    
    contentWindowController.refresh(popoverFrame: referenceFrame )
  }
  
  open func hide() {
    self.popover.close()
  }
  
  
  // MARK:
  // MARK: popover delegate
  
  public func popoverDidShow(_ notification: Notification) {
    self.setupPopoverWindow()
    
    let popoverContentFrame = popover.window!.convertToScreen(popover.window!.contentView!.frame)
    contentWindowController.refresh(popoverFrame: popoverContentFrame)
  }
  
  func setupPopoverWindow() {
    self.popover.window?.delegate = self
  }
  
  
  // MARK:
  
  class BlankViewController: NSViewController {
    init(frame: CGRect) {
      super.init(nibName: nil, bundle: nil)
      
      self.view = NSView(frame: frame)
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }
  
}



extension PopoverWindowController: NSWindowDelegate {
  
  // prevent the popover window from coming above the overlay window.
  public func windowDidBecomeKey(_ notification: Notification) {
    print("\(self): handing over key status to the content wc.")
    self.contentWindowController.window?.makeKeyAndOrderFront(self)
  }
  
}


extension NSPopover {
  
  var window: NSWindow? {
    return self.contentViewController?.view.window
  }
  
}
