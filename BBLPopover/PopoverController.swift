//
//  PopoverWindowController.swift
//  contexter
//
//  Created by ilo on 01/06/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

import Foundation
import BBLBasics



@objc
public protocol PopoverContentProvider {
  
  @objc
  var window: NSWindow? { get }
  
  func refresh(contentFrame: NSRect, display: Bool)
}



/// we convolutedly synchronise popover behaviour to a content window controller.
/// we tried stealing OverlayWindow's content view, which caused unwanted app activation when interacting (because the popover window was not a non-activating panel).
open class PopoverController: NSObject {
  
  let anchorView: NSView
  
  @objc dynamic
  let popoverContentProvider: PopoverContentProvider
  
  
  open lazy var popoverWindow: NSWindow! = {
    if let window = self.popover.window {
      return window
    }
    
    // for first-time access, zero the content rect.
    self.show(popoverContentRect: .zero)

    return popover.window!
  }()
  
  
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
    
    observeContentWindowFrame()
    
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
  
  
  // MARK: - presentation
  
  // REFACTOR only a size is used.
  open func show(popoverContentRect: CGRect) {
    
    // show the popover using the same size as the overlay.
    self.popover.contentViewController = BlankViewController(frame: CGRect(origin: .zero, size: popoverContentRect.size))
    self.popover.contentSize = popoverContentRect.size
    self.popover.show(relativeTo: .zero, of: anchorView, preferredEdge: .minY)
    
    // case: when popover content already shown, influence the key window state.
    if let contentWindow = self.popoverContentProvider.window,
      contentWindow.isVisible {
      contentWindow.makeKeyAndOrderFront(self)
    }
  }
  
  open func hide() {
    self.popover.close()
  }
  
  
  // MARK: - internals
  
  let popover = NSPopover()
  
}


// MARK: - popover delegate

extension PopoverController: NSPopoverDelegate {
  
  public func popoverDidShow(_ notification: Notification) {
    
    // this is the first chance to set up the popover's window, as previously it might not have been instantiated.
    self.setupPopoverWindow()
    
    // * update content provider frame to match popover.
    
    // give the popover size some room to settle.
    execOnMainAsync {
      
      // DEV prevent the popover from obscuring the screen when breakpoint is hit.
      if UserDefaults.standard.bool(forKey: "debug.devInfo") == true {
        self.popoverWindow.level = NSWindow.Level.normal
      }

      self.popoverContentProvider.refresh(contentFrame: self.popoverContentFrame!, display: true)
      
      // make popover window a child of the content provider's window.
      self.popoverWindow.addChildWindow(self.popoverContentProvider.window!, ordered: .above)
      
    }
    
  }
  
  public func popoverDidClose(_ notification: Notification) {
    self.popoverContentProvider.refresh(contentFrame: popoverWindow.frame, display: false)
  }
  
  func setupPopoverWindow() {
    self.popover.window?.delegate = self
    
  }
  
  
  // MARK: -
  
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
