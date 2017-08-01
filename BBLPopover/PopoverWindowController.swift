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
  
}


public protocol PopoverWindowProvider {
  
  func on(windowVisible: Bool, frame: CGRect)
  
}



extension PopoverWindowController: PopoverWindowProvider {
  
  public func on(windowVisible: Bool, frame: CGRect) {
    if windowVisible {
      
      self.show()
    }
    else {
      self.hide()
    }
  }
 
}

/// we convolutedly synchronise popover behaviour to the window controller.
/// we tried stealing OverlayWindow's content view, which caused unwanted app activation when interacting (because the popover window was not a non-activating panel).
open class PopoverWindowController: NSObject, NSPopoverDelegate {
  
  let popover = NSPopover()
  let anchorView: NSView
  
  let contentWindowController: PopoverWindowSubject
  
  
  public init(anchorView: NSView, contentWindowController: PopoverWindowSubject, appearance: NSAppearance? = nil) {
    self.anchorView = anchorView
    self.contentWindowController = contentWindowController
    
    //    self.contentWindowController.setupWindowForOverlay()
    
    super.init()
    
    self.popover.delegate = self
    
    if appearance != nil {
      self.popover.appearance = appearance
    }
    
    observePopoverWindowSubject()
  }
  
  func observePopoverWindowSubject() {
    Broadcaster.register(PopoverWindowProvider.self, observer: self)
  }
  
  
  // MARK: - visibility
  
  open func show(preferredEdge: NSRectEdge =  .minY) {
    
    // show the popover using the same size as the overlay.
    self.popover.contentViewController = BlankViewController(frame: self.contentWindowController.window?.windowFrameView?.bounds ?? .zero)
    self.popover.contentSize = self.contentWindowController.window!.frame.size
    self.popover.show(relativeTo: .zero, of: anchorView, preferredEdge: preferredEdge)
    
    updateContentWindowFrame()
  }
  
  open func hide() {
    self.popover.close()
  }
  
  
  // MARK:
  // MARK: popover delegate
  
  public func popoverDidShow(_ notification: Notification) {
    self.setupPopoverWindow()
    
    self.popover.window?.orderFrontRegardless()
    self.contentWindowController.window?.orderFrontRegardless()

    updateContentWindowFrame()
  }
  
  func setupPopoverWindow() {
    self.popover.window?.delegate = self
  }
  
  // MARK:
  
  func updateContentWindowFrame() {
    // update content window frame to line up with the popover content view.
    let contentWindow = self.contentWindowController.window!
    let popoverContentView = self.popover.contentViewController!.view
    if let popoverContentFrame = popoverContentView.window?.convertToScreen(popoverContentView.frame) {
      contentWindow.setFrame(popoverContentFrame, display: true)
    }
    
    // since we started showing the overlay window on top of a popover, we have seen edge cases where the window doesn't display until something redraws the window.
    // calling #display seems to force redraw and resolve the edge case.
    contentWindow.display()
  }
  
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
