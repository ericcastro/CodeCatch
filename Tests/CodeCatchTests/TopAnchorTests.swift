import AppKit
import Testing

@testable import CodeCatch

/// A closed popover kept resizing against SwiftUI's own sizing forever, at 60% CPU; opening it must still fit it.
@MainActor @Test func popoverFitsOnlyWhileOpen() {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 100, width: 420, height: 354), styleMask: .borderless, backing: .buffered, defer: true)
    let anchor = TopAnchor.AnchorView()
    window.contentView?.addSubview(anchor)
    let top = window.frame.maxY

    anchor.fit(300)
    #expect(window.frame.height == 354)

    window.orderFront(nil)
    defer { window.orderOut(nil) }
    anchor.fit(300)
    #expect(window.frame.height == 300)
    #expect(window.frame.maxY == top)
}
