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
  
  func refresh(contentFrame: NSRect)
}



/// we convolutedly synchronise popover behaviour to a content window controller.
/// we tried stealing OverlayWindow's content view, which caused unwanted app activation when interacting (because the popover window was not a non-activating panel).
open class PopoverController: NSObject {
  
  let popover = NSPopover()

  
  let anchorView: NSView
  
  @objc dynamic
  let popoverContentProvider: PopoverContentProvider
  
  
  var contentWindowVisibilityObservation: NSKeyValueObservation?

  
  /// the content frame, in screen coordinates.
  public var popoverContentFrame: CGRect? {
    return popover.window?.convertToScreen(
      (popover.contentViewController?.view.frame)!
    )
  }
  
  public init(anchorView: NSView, contentWindowController: PopoverContentProvider) {
    self.anchorView = anchorView
    self.popoverContentProvider = contentWindowController
    
    
    super.init()
    
    self.popover.delegate = self
    
    observeContentWindowVisible()
    
    observeContentWindowFrame()
    
  }
  
  func observeContentWindowVisible() {
    contentWindowVisibilityObservation = observe(\.popoverContentProvider.window?.isVisible, options: [.initial, .new]) { (object, change) in
      if let contentVisible = change.newValue {
        switch (contentVisible, self.popover.isShown)  {
        case (true?, false):
          self.show(popoverContentRect: self.popoverContentProvider.window!.frame)
        case (false?, true):
          self.hide()
        default:
          ()
        }
      }
    }
  }
  
  func observeContentWindowFrame() {
    contentWindowFrameObservation = observe(\.popoverContentProvider.window?.frame, options: [.initial, .new]) { object, change in
      // condition: popover visible.
      if let value = change.newValue,
        let contentWindowFrame = value,
        let display = self.popover.window?.isVisible {
        
        // response: update popover frame to match content window position.
        self.popover.window?.setFrame(contentWindowFrame, display: display)
      }
    }
    
    // enhancement: tracking can be choppy. before releasing, consider reimplementing by making the popover's topmost parent window be a child of the content window. (setup may be tricky / brittle over window lifecycles)
    // deferring until we're sure of the priority of this.
  }
  var contentWindowFrameObservation: NSKeyValueObservation!
  
  // MARK: - visibility
  
  open func show(popoverContentRect: CGRect) {
    
    // show the popover using the same size as the overlay.
    self.popover.contentViewController = BlankViewController(frame: CGRect(origin: .zero, size: popoverContentRect.size))
    self.popover.contentSize = popoverContentRect.size
    self.popover.show(relativeTo: .zero, of: anchorView, preferredEdge: .minY)
  }
  
  open func hide() {
    self.popover.close()
  }
}


// MARK: - popover delegate

extension PopoverController: NSPopoverDelegate {
  
  public func popoverDidShow(_ notification: Notification) {
    
    // this is the first chance to set up the popover's window, as previously it might not have been instantiated.
    self.setupPopoverWindow()
    
    // * update content provider frame to match popover.
    
    // give the popover size some room to settle.
    execOnMainAsync {
      self.popoverContentProvider.refresh(contentFrame: self.popoverContentFrame!)
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


// MARK: - NSWindowDelegate

extension PopoverController: NSWindowDelegate {
  
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
