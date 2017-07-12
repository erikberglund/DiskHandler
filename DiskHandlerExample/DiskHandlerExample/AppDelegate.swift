//
//  AppDelegate.swift
//  DiskHandlerExample
//
//  Created by Erik Berglund on 2017-06-24.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import Cocoa
import DiskHandler

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // Initialize Disk Arbitration
        
        /*
        //diskHandler?.disks()
        
        // IOHDIXController
        // IOHDIXHDDrive
        // IOHDIXHDDriveOutKernel
        
        let testService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOHDIXHDDriveOutKernel"))
        if testService != 0 {
            print("testService: \(testService)")
        
            var properties:Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(testService, &properties, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively))
            let prop = properties?.takeUnretainedValue() as? [String:Any]
            print("propertiesDict: \(prop)")
        }
        
        print(IOServiceMatching("IOHDIXHDDriveOutKernel"))
        print(IOServiceNameMatching("IOHDIXHDDriveOutKernel@0"))
        print(testService)
        
        let matchDict = ["IOProviderClass": "IOHDIXHDDriveOutKernel", ]
        
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
*/
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
