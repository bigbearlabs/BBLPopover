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
public protocol PopoverContentProvider {
  
  @objc
  var window: NSWindow? { get }
  
  func refresh(popoverContentFrame: NSRect)
}



/// we convolutedly synchronise popover behaviour to the window controller.
/// we tried stealing OverlayWindow's content view, which caused unwanted app activation when interacting (because the popover window was not a non-activating panel).
open class PopoverWindowController: NSObject, NSPopoverDelegate {
  
  let popover = NSPopover()
  let anchorView: NSView
  
  let popoverContentProvider: PopoverContentProvider
  
  
  /// the content frame, in screen coordinates.
  public var popoverContentFrame: CGRect? {
    return popover.window?.convertToScreen(
      (popover.contentViewController?.view.frame)!
    )
  }
  
  public init(anchorView: NSView, contentWindowController: PopoverContentProvider) {
    self.anchorView = anchorView
    self.popoverContentProvider = contentWindowController
    
    //    self.contentWindowController.setupWindowForOverlay()
    
    super.init()
    
    self.popover.delegate = self
  }
  
  
  // MARK: - visibility
  
  open func show(popoverContentRect: CGRect) {
    
    // show the popover using the same size as the overlay.
    self.popover.contentViewController = BlankViewController(frame: CGRect(origin: .zero, size: popoverContentRect.size))
    self.popover.contentSize = popoverContentRect.size
    self.popover.show(relativeTo: .zero, of: anchorView, preferredEdge: .minY)
      // TODO find where  anchor view position is set and consolidate to here.
    
    popoverContentProvider.refresh(popoverContentFrame: popoverContentRect )
  }
  
  open func hide() {
    self.popover.close()
  }
  
  
  // MARK: - popover delegate
  
  public func popoverDidShow(_ notification: Notification) {
    self.setupPopoverWindow()
    
    // give the popover size some room to settle.
    execOnMainAsync {
      let popoverContentFrame = self.popover.window!.convertToScreen(self.popover.window!.contentView!.frame)
      self.popoverContentProvider.refresh(popoverContentFrame: popoverContentFrame)
    }
    
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
    self.popoverContentProvider.window?.makeKeyAndOrderFront(self)
  }
  
}


extension NSPopover {
  
  var window: NSWindow? {
    return self.contentViewController?.view.window
  }
  
}
