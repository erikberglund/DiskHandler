//
//  DiskImageController.swift
//  DiskHandler
//
//  Created by Erik Berglund on 2017-06-24.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import Foundation

private var availableDiskImages = Set<DiskImage>()

public protocol DiskImageControllerDelegate: class {
   func progress(stdOut: String)
   func progress(stdErr: String)
   func progress(percent: Double)
}

public class DiskImageController {
   
   public static let shared = DiskImageController()
   
   public weak var delegate: DiskImageControllerDelegate?
   //public weak var mountDelegate: DiskControllerMountDelegate?
   
   private init() {}
   
   // MARK: -
   // MARK: DiskImages
   public func diskImage(url: URL) -> DiskImage? {
      return availableDiskImages.first(where: {$0.url == url })
   }
   
   public func diskImages() -> Set<DiskImage>? {
      return availableDiskImages
   }
   
   public func isMounted(url: URL) -> Bool {
      if let disks = DiskController.shared.disks(matching: [kDADiskDescriptionDeviceModelKey as String: "Disk Image"]),
         let disk = disks.first(where: { return $0.diskImageURL == url }) {
         return (disk.isVolumeMounted || disk.children.contains(where: { return $0.isVolumeMounted }))
      } else {
         return false
      }
      
      /*
      var iterator: io_iterator_t = 0;
      let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOHDIXHDDrive"), &iterator)
      if result == kIOReturnSuccess {
         var service: io_object_t = 1
         while true {
            service = IOIteratorNext(iterator)
            if service == 0 {
               break
            }
                        
            if let value = IORegistryEntrySearchCFProperty(service, kIOServicePlane, "image-path" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)) {
               if (CFGetTypeID(value) == CFDataGetTypeID()) {
                  if let hexString = String(data: value as! CFData as Data, encoding: String.Encoding.utf8) {
                     Swift.print("hexString: \(hexString)")
                     if hexString == url.path {
                        IOObjectRelease(service)
                        return true
                     }
                  }
               }
            }
            IOObjectRelease(service)
         }
      }
      return false
 */
   }
   
   public func attach(url: URL, options: [String]?, password: String?) -> (Int32, [String : Any]?) {
      
      // FIXME: Should return error
      guard url.fileExists, url.fileIsDiskImage else { return (-1, nil) }
      
      var args: [String] = [ "attach", url.absoluteString ]
      
      if let opts = options { args.append(contentsOf: opts) }
      
      // Add option -plist if it isn't included in the options
      if !args.contains("-plist") { args.append("-plist") }
      
      let (stdOutDict, stdErr, exitCode) = hdiutil(arguments: args, password: password)
      if exitCode == 0 {
         return (exitCode, stdOutDict as? [String : Any])
      } else {
         print("stdErr: \(stdErr)")
         print("exitCode: \(exitCode)")
         return (exitCode, nil)
      }
   }
   
   public func create(url: URL, options: [String]?, sourceFolder: URL, password: String?) -> (Int32, [String]?) {
      
      // FIXME: Should return error
      guard !url.fileExists else { return (-1, nil) }
      
      var args: [String] = [ "-srcfolder", sourceFolder.absoluteString ]
      
      if let opts = options { args.append(contentsOf: opts) }
      
      return self.create(url: url, options: args, password: password)
   }
   
   public func create(url: URL, options: [String]?, password: String?) -> (Int32, [String]?) {
      
      var args: [String] = [ "create" ]
      
      if let opts = options { args.append(contentsOf: opts) }
      
      // Add option -plist if it isn't included in the options
      if !args.contains("-plist") { args.append("-plist") }
      
      // Add option -puppetstrings if it isn't included in the options
      if !args.contains("-puppetstrings") { args.append("-puppetstrings") }
      
      if password != nil, !args.contains("-encryption") { args.append("-encryption") }
      
      args.append(url.absoluteString)
      
      let (stdOutDict, stdErr, exitCode) = hdiutil(arguments: args, password: password)
      if exitCode == 0 {
         return (exitCode, stdOutDict as? [String])
      } else {
         Swift.print("stdErr: \(stdErr)")
         Swift.print("exitCode: \(exitCode)")
         return (exitCode, stdErr)
      }
   }
   
   public func detach(devName: String, force: Bool) -> (Int32, [String : Any]?) {
      
      guard FileManager.default.fileExists(atPath: devName) else { return (-1, nil) }
      
      var args: [String] = [ "detach", devName ]
      
      if force {
         args.append("-force")
      }
      
      let (stdOutDict, stdErr, exitCode) = hdiutil(arguments: args, password: nil)
      if exitCode == 0 {
         return (exitCode, stdOutDict as? [String : Any])
      } else {
         print("stdErr: \(stdErr)")
         print("exitCode: \(exitCode)")
         return (exitCode, nil)
      }
   }
   
   public func isEncrypted(url: URL) -> [String : Any]? {
      
      guard url.fileExists, url.fileIsDiskImage else { return nil }
      
      let (stdOutDict, stdErr, exitCode) = hdiutil(arguments: [ "isencrypted", url.absoluteString, "-plist" ], password: nil)
      if exitCode == 0 {
         return stdOutDict as? [String : Any]
      } else {
         print("stdErr: \(stdErr)")
         print("exitCode: \(exitCode)")
         return nil
      }
   }
   
   public func info(url: URL) -> [String : Any]? {
      
      guard
         url.fileExists,
         url.fileIsDiskImage,
         let encryptedDict = self.isEncrypted(url: url),
         let isEncrypted = encryptedDict["encrypted"] as? Bool,
         isEncrypted
         else {
            return nil
      }
            
      let (stdOutDict, stdErr, exitCode) = hdiutil(arguments: [ "imageinfo", url.absoluteString, "-plist" ], password: nil)
      if exitCode == 0 {
         return stdOutDict as? [String : Any]
      } else {
         print("stdErr: \(stdErr)")
         print("exitCode: \(exitCode)")
         return nil
      }
   }
   
   public func udifderez(url: URL) -> [String : Any]? {
      
      guard
         url.fileExists,
         url.fileIsDiskImage,
         let encryptedDict = self.isEncrypted(url: url),
         let isEncrypted = encryptedDict["encrypted"] as? Bool,
         isEncrypted
         else {
            return nil
      }
      
      let (stdOutDict, stdErr, exitCode) = hdiutil(arguments: [ "udifderez", "-xml", url.absoluteString ], password: nil)
      if exitCode == 0 {
         return stdOutDict as? [String : Any]
      } else {
         print("stdErr: \(stdErr)")
         print("exitCode: \(exitCode)")
         return nil
      }
   }
   
   private func hdiutil(arguments: [String], password: String?) -> (stdOut: Any?, stdErr: [String], exitCode: Int32) {
      
      var stdOutDictComponents: [String] = []
      var stdErr: [String] = []
      
      let task:Process = Process()
      task.launchPath = "/usr/bin/hdiutil"
      
      var args = arguments
      if let pass = password, let passwordData = pass.data(using: .utf8) {
         if !args.contains("-stdinpass") { args.append("-stdinpass") }
         let stdInPipe = Pipe()
         task.standardInput = stdInPipe
         stdInPipe.fileHandleForWriting.write(passwordData)
         stdInPipe.fileHandleForWriting.closeFile()
      }
      
      let stdOutPipe = Pipe()
      task.standardOutput = stdOutPipe
      
      let stdErrPipe = Pipe()
      task.standardError = stdErrPipe
      
      if let progressDelegate = self.delegate {
         stdOutPipe.fileHandleForReading.readabilityHandler = {
            if let stdOutString = String(data: $0.availableData, encoding: .utf8) {
               if stdOutString.hasPrefix("PERCENT:"),
                  let percentString = stdOutString.components(separatedBy: ":").last?.replacingOccurrences(of: "\n", with: ""),
                  let percent = Double(percentString) {
                  progressDelegate.progress(percent: percent)
               } else if stdOutString.hasPrefix("<") {
                  stdOutDictComponents.append(stdOutString)
               } else {
                  progressDelegate.progress(stdOut: stdOutString)
               }
            }
         }
         
         stdErrPipe.fileHandleForReading.readabilityHandler = {
            if let stdErrString = String(data: $0.availableData, encoding: .utf8) {
               progressDelegate.progress(stdErr: stdErrString)
            }
         }
      }
      
      task.arguments = args
      task.launch()
      
      let stdErrData = stdErrPipe.fileHandleForReading.readDataToEndOfFile()
      if 0 < stdErrData.count {
         if var stdErrString = String(data: stdErrData, encoding: .utf8) {
            stdErrString = stdErrString.trimmingCharacters(in: .newlines)
            stdErr = stdErrString.components(separatedBy: "\n")
         }
      }
      
      task.waitUntilExit()
      
      let stdOutDictString = stdOutDictComponents.joined(separator: "\n")
      if let stdOutDictData = stdOutDictString.data(using: .utf8) {
         do {
            let propertyList = try PropertyListSerialization.propertyList(from: stdOutDictData, format: nil)
            return (propertyList, stdErr, task.terminationStatus)
         } catch let error {
            return (nil, [error.localizedDescription], task.terminationStatus)
         }
      }
      
      return (nil, stdErr, task.terminationStatus)
   }
}

extension URL {
   var fileExists: Bool {
      return FileManager.default.fileExists(atPath: self.path)
   }
   
   var fileIsDiskImage: Bool {
      if let typeIdentifier = self.typeIdentifier { return typeIdentifier.hasPrefix("com.apple.disk-image") } else { return false }
   }
   
   var typeIdentifier: String? {
      return (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
   }
}


