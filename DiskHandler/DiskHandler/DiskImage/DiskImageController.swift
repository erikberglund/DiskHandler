//
//  DiskImageController.swift
//  DiskHandler
//
//  Created by Erik Berglund on 2017-06-24.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import Foundation

public class DiskImageController {

    static let shared = DiskController()
    
    init() {
        
    }
    
    // Set<DiskImage>? requires Hashable
    public func disks() -> Bool {
        
        var iterator: io_iterator_t = 0;
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOHDIXHDDrive"), &iterator)
        
        if result == kIOReturnSuccess {
            var service: io_object_t = 1
            while true {
                service = IOIteratorNext(iterator);
                print(service)
                if service == 0 {
                    break;
                }
                
                if let value = IORegistryEntrySearchCFProperty(service, kIOServicePlane, "image-path" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)) {
                    if (CFGetTypeID(value) == CFDataGetTypeID()) {
                        if let hexString = String(data: value as! CFData as Data, encoding: String.Encoding.utf8) {
                            print(hexString)
                        }
                    }
                }
                IOObjectRelease(service);
            }
        }
        
        return false
        
    }
    
    public func attach(url: URL, options: [String]?) -> [String : Any]? {
        
        // FIXME: Verify path exist and is a disk image
        
        var args: [String] = [ "attach", url.absoluteString ]

        if let opts = options {
            args.append(contentsOf: opts)
        }
        
        // Add option -plist if it isn't included in the options
        if !args.contains("-plist") {
            args.append("-plist")
        }
        
        let (stdOutDict, stdErr, exitCode) = runCommand(command: "/usr/bin/hdiutil", arguments: args)
        if exitCode == 0 {
            return stdOutDict
        } else {
            print("stdErr: \(stdErr)")
            print("exitCode: \(exitCode)")
            return nil
        }
    }
    
    public func detach(devName: String, force: Bool) -> [String : Any]? {
        
        // FIXME: Verify path exist and is a disk image
        
        var args: [String] = [ "detach", devName ]
        
        if force {
            args.append("-force")
        }
        
        let (stdOutDict, stdErr, exitCode) = runCommand(command: "/usr/bin/hdiutil", arguments: args)
        if exitCode == 0 {
            return stdOutDict
        } else {
            print("stdErr: \(stdErr)")
            print("exitCode: \(exitCode)")
            return nil
        }
    }
    
    public func info(url: URL) -> [String : Any]? {
        
        // FIXME: Verify path exist and is a disk image
        
        let (stdOutDict, stdErr, exitCode) = runCommand(command: "/usr/bin/hdiutil", arguments: [ "imageinfo", url.absoluteString, "-plist" ])
        if exitCode == 0 {
            return stdOutDict
        } else {
            print("stdErr: \(stdErr)")
            print("exitCode: \(exitCode)")
            return nil
        }
    }
    
    public func udifderez(url: URL) -> [String : Any]? {
        
        // FIXME: Verify path exist and is a disk image
        
        let (stdOutDict, stdErr, exitCode) = runCommand(command: "/usr/bin/hdiutil", arguments: [ "udifderez", "-xml", url.absoluteString ])
        if exitCode == 0 {
            print("stdOutDict: \(stdOutDict)")
            return stdOutDict
        } else {
            print("stdErr: \(stdErr)")
            print("exitCode: \(exitCode)")
            return nil
        }
    }
    
    
}

private func runCommand(command: String, arguments: Array<String>) -> (stdOutDict: Dictionary<String, Any>, stdErr: [String], exitCode: Int32) {
    
    var stdOutDict = [String:Any]()
    var stdErr: [String] = []
    
    let task:Process = Process()
    task.launchPath = command
    task.arguments = arguments
    
    let stdOutPipe = Pipe()
    task.standardOutput = stdOutPipe
    
    let stdErrPipe = Pipe()
    task.standardError = stdErrPipe
    
    task.launch()
    
    let stdOutData = stdOutPipe.fileHandleForReading.readDataToEndOfFile()
    if 0 < stdOutData.count {
        do {
            if let propertyList = try PropertyListSerialization.propertyList(from: stdOutData, format: nil) as? [String : Any] {
                stdOutDict = propertyList
            }
        } catch let error {
            // FIXME: Proper error handling
            print(error)
        }
    }
    
    let stdErrData = stdErrPipe.fileHandleForReading.readDataToEndOfFile()
    if 0 < stdErrData.count {
        if var stdErrString = String(data: stdErrData, encoding: .utf8) {
            stdErrString = stdErrString.trimmingCharacters(in: .newlines)
            stdErr = stdErrString.components(separatedBy: "\n")
        }
    }
    
    task.waitUntilExit()
    let exitCode = task.terminationStatus
    
    return (stdOutDict, stdErr, exitCode)
}
