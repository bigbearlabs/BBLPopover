//
//  ViewController.swift
//  BBLPopoverDemo
//
//  Created by ilo on 01/03/2019.
//  Copyright © 2019 Big Bear Labs. All rights reserved.
//

import Cocoa
import BBLPopover



class ViewController: NSViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }

  @IBAction
  func action_togglePopover(_ sender: Any?) {
    if popoverController.popoverWindow.isVisible {
      popoverController.hide()
    } else {
      popoverController.show(popoverContentRect: self.view.window!.contentView!.bounds)
    }
    
  }

  lazy var popoverController: PopoverController = {
    PopoverController(anchorView: self.button, popoverContentProvider: self.contentProvider)
  }()
  
  @IBOutlet weak var button: NSButton!
  
  lazy var contentProvider: PopoverContentProvider = {
    MyPopoverContentProvider()
  }()

}


class MyPopoverContentProvider: NSObject, PopoverContentProvider {
  
  @objc dynamic
  lazy var window: NSWindow? = {
    let contentVc = NSViewController(nibName: nil, bundle: nil)
    contentVc.view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    return NSWindow(contentViewController: contentVc)
  }()
  
  func refresh(contentFrame: NSRect, display: Bool) {
    self.window?.setIsVisible(display)
  }
  
  
}
