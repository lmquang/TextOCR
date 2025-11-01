//
//  main.swift
//  TextOCR
//
//  Simple entry point for debugging
//

import AppKit

// Keep a strong reference to the delegate to prevent deallocation
private var appDelegate: AppDelegate?

// Print to confirm this file is being executed
print("*** main.swift is running ***")
NSLog("=== main.swift is running ===")
fputs("!!! main.swift STARTED !!!\n", stderr)

// Initialize the application
let app = NSApplication.shared
print("*** NSApplication created ***")

appDelegate = AppDelegate()
print("*** AppDelegate instantiated ***")

app.delegate = appDelegate
print("*** Delegate set ***")

// Run the app
print("*** About to call NSApplicationMain ***")
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
