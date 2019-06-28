import Foundation
import BBLBasics


/// limitations:
/// NSPopover does not always show the popover on the preferred edge of the anchor view, if space is tight. this can result in having to choose between the popover obscuring critical controls, or having the disclosure triangle positioned in an awkward location.
/// notes:
/// consider re-implementing using github/SFBPopovers since it allows more control over disclosure triangle location et.

public protocol PopoverContentProvider: class {
  
  var window: NSWindow? { get }
  
  var frame: CGRect? { get set }

  var isVisible: Bool { get set }
}



/// we convolutedly synchronise popover behaviour to a content window controller.
/// we tried stealing OverlayWindow's content view, which caused unwanted app activation when interacting (because the popover window was not a non-activating panel).
open class PopoverController: NSObject {
  
  let anchorView: NSView
  
  dynamic weak
  var popoverContentProvider: PopoverContentProvider!

  let onShow: (PopoverController) -> Void
  
  lazy var popover: NSPopover = {
    let popover = NSPopover()
    popover.animates = false
    return popover
  }()
  
  @objc dynamic
  open lazy var popoverWindow: NSWindow = {
    if let window = self.popover.window {
      return window
    }

    // for first-time access, show with a zero content rect to initialise popover.window.
    self.show(popoverContentSize: .zero)

    return self.popover.window!
  }()
  
  
  /// the content frame, in screen coordinates.
  public var popoverContentFrame: CGRect? {
    return popover.window?.convertToScreen(
      (popover.contentViewController?.view.frame)!
    )
  }
  
  public init(anchorView: NSView, popoverContentProvider: PopoverContentProvider,
              onShow: @escaping (PopoverController) -> Void
    ) {
    self.anchorView = anchorView
    self.popoverContentProvider = popoverContentProvider
    
    self.onShow = onShow
    
    super.init()
    
    self.popover.delegate = self
    
    // on content provider window resize, update popover window size.
    _ = self.windowResizeObservation
  }
  
  lazy var windowResizeObservation: Any = {
    // update popover window frame to match content provider window.
    NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: nil) { [unowned self] notification in
      if let window = notification.object as? NSWindow,
        window === self.popoverContentProvider.window {
        self.popover.window?.setFrame(window.frame, display: window.isVisible)
      }
    }
  }()
  
  deinit {
    NotificationCenter.default.removeObserver(self.windowResizeObservation)
  }
  
  
  // MARK: - presentation
  
  // REFACTOR only a size is used.
  open func show(
    popoverContentSize: CGSize? = nil,
    positioningRect: CGRect = .zero,
    preferredEdge: NSRectEdge = .minY) {
    
    guard self.popover.window?.isVisible != true else {
      return
    }

    let popoverContentSize = popoverContentSize
      ?? popoverContentProvider.window!.frame.size
    
    // show the popover using the same size as the overlay.
    self.popover.contentViewController =
      self.popover.contentViewController ??
        BlankViewController(frame: CGRect(origin: .zero, size: popoverContentSize))
    
    self.popover.contentSize = popoverContentSize
    self.popover.show(relativeTo: positioningRect, of: self.anchorView, preferredEdge: preferredEdge)
    
    // case: when popover content already shown, influence the key window state.
    if let contentWindow = self.popoverContentProvider.window,
      contentWindow.isVisible {
      contentWindow.makeKeyAndOrderFront(self)
    }
  }
  
  open func hide() {
    if self.popover.isShown {
      self.popover.close()
    } else {
      self.popoverContentProvider.isVisible = false
    }
  }
  
}


// MARK: - popover delegate

extension PopoverController: NSPopoverDelegate {
  
  public func popoverDidShow(_ notification: Notification) {
    
    // this is the first chance to set up the popover's window, as previously it might not have been instantiated.
    self.setupPopoverWindow()
    
    // * call the handler.
    onShow(self)
    
    // DEV prevent the popover from obscuring the screen when breakpoint is hit.
    if UserDefaults.standard.bool(forKey: "debug.devInfo") == true {
      self.popoverWindow.level = NSWindow.Level.normal
    }
    
    // * update content provider frame to match popover.
    self.popoverContentProvider.frame = self.popoverContentFrame!
    
    // make content provider's window a child window of the popover window,
    // so it follows the popover.
    self.popoverWindow.addChildWindow(self.popoverContentProvider.window!, ordered: .above)
  }
  
  public func popoverDidClose(_ notification: Notification) {
    self.popoverContentProvider.isVisible = false
  }
  
  func setupPopoverWindow() {
    
    // set self as the popover window's delegate, so we can intercept key status and pass on to the content window.
    self.popoverWindow.delegate = self
    
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
    if (notification.object as? NSWindow) === self.popover.window {
      print("\(self): handing over key status to the content wc.")
      self.popoverContentProvider.window?.makeKeyAndOrderFront(self)
    }
  }
  
}


extension NSPopover {
  
  var window: NSWindow? {
    return self.contentViewController?.view.window
  }
  
}
