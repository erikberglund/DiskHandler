//
//  Disk.swift
//  DiskHandler
//
//  Created by Erik Berglund on 2017-06-24.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import DiskArbitration
import Foundation

public class Disk: Hashable, Equatable {
    
    public var diskRef: DADisk
    public var parent: Disk?
    public var children = Set<Disk>()
    
    // Conforming to Hashable
    public var hashValue: Int {
        return Int(CFHash(self.diskRef))
    }
    
    private var diskDescription: [String : Any]?
    private var diskIODescription: [String : Any]?
    private var diskOptions: [String : Any]?
    private var diskImageInstance: DiskImage?
    
    init(diskRef: DADisk) {
        self.diskRef = diskRef
        self.updateDescription()
    }
    
    // Update the local variable diskDescription
    public func updateDescription() {
        self.diskDescription = self.description()
        self.diskIODescription = self.ioDescription()
    }
        
    // Get disk description dictionary
    public func description() -> [String : Any]? {
        return DADiskCopyDescription(self.diskRef) as? [String : Any]
    }
    
    // Get disk description value for passed key
    public func description(key: CFString) -> Any? {
        if let diskDescription = self.diskDescription {
            return diskDescription[key as String]
        }
        return nil
    }
    
    // Get disk IO description dictionary
    public func ioDescription() -> [String : Any]? {
        guard let mediaPath = self.mediaPath() else {
            return nil
        }
        
        let service = IORegistryEntryFromPath(kIOMasterPortDefault, mediaPath)
        var cfProperties:Unmanaged<CFMutableDictionary>?
        
        if
            KERN_SUCCESS == IORegistryEntryCreateCFProperties(service, &cfProperties, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)),
            let properties = cfProperties?.takeUnretainedValue() as? [String : Any] {
            
            // FIXME: Print properties
            // print("properties: \(properties)")
            return properties
        } else {
            return nil
        }
    }
    
    // Get disk IO description value for passed key
    public func ioDescription(key: String) -> Any? {
        if let diskIODescription = self.diskIODescription {
            return diskIODescription[key]
        }
        return nil
    }
    
    public func addChild(disk: Disk) {
        if !self.children.contains(disk) {
            self.children.insert(disk)
        }
    }
    
    // MARK: -
    // MARK: Mount
    
    public func mount() {
        DADiskMount(self.diskRef, nil, DADiskMountOptions(kDADiskMountOptionDefault), diskMountCallback, nil)
        
        // NOTE: Only for testing DADiskMountWithArguments
        // self.mount(atURL: nil, arguments: ["rdonly", "nobrowse"])
    }
    
    public func mount(atURL: URL) {
        DADiskMount(self.diskRef, atURL as CFURL, DADiskMountOptions(kDADiskMountOptionDefault), diskMountCallback, nil)
    }
    
    public func mount(atURL: URL?, arguments: [String]) {

        // Need to bridge this to Objective-C until i figure out how to call this from Swift.
        // Se commments below for the current issue.
        
        DiskArbitrationBridge.mountDisk(self.diskRef, at: atURL, options: DADiskMountOptions(kDADiskMountOptionDefault), arguments: arguments, callback: diskMountCallback)
        
        // Initiate a CFURL with nil, and if a URL was passed, use that.
        
        /*
         var url: CFURL? = nil
         if let cfURL = atURL as CFURL? {
            url = cfURL
        }
         */
        
        
        // * ISSUE *
        
        // DADiskMountWithArguments last argument: "arguments" expects a null-terminated c array, that in swift wants a: UnsafeMutablePointer<Unmanaged<CFString>>!
        
        // This presents a problem of how to get a Swift array of strings, to a null terminated c array that matches that type.
        // I asked a question about this on StackOverflow but have yet to find a valid solution: https://stackoverflow.com/questions/44865574/swift-array-of-strings-to-unsafemutablepointerunmanagedcfstring

        // From the comments in that post, doing this gets me a [Unmanaged<CFString>] variable, that can be passed directly. But it isn't null terminated, so that will crash.
        
        // var args = arguments.map { Unmanaged.passRetained($0 as CFString ) }
        // DADiskMountWithArguments(self.diskRef, url, DADiskMountOptions(kDADiskMountOptionDefault), diskMountCallback, nil, &args)
        
        // Another comment suggests that it might be a bug as the Unmanaged<CFString> is not marked as an optional, and hence cannot be null-terminated.
        
        // I created a bug report in the Swift projects bug reporter: https://bugs.swift.org/browse/SR-5365
        
        // Below is a small dummy implementation that tries to imitate the Objective-C version found in the Objective-C bridging file.
        
        // let arguments = ["rdonly", "noowners", "nobrowse", "-j"]
        
        // Create an UnsafeMutableRawPointer and allocate the correct string size
        // let argsUnsafeMutableRawPointer = calloc(arguments.count + 1, MemoryLayout<CFString>.size)
        
        // Convert the Mutable pointer to an Immutable one
        // let argsUnsafeRawPointer: UnsafeRawPointer? = UnsafeRawPointer.init(argsUnsafeMutableRawPointer)
        
        // CFArrayGetValues expects an UnsafeMutablePointer<UnsafeRawPointer?>. I have an UnsafeRawPointer, but can't get it into an UnsafeMutablePointer<T>.
        // let argsUnsafeMutablePointer: UnsafeMutablePointer<UnsafeRawPointer?>! = UnsafeMutablePointer.
        
        // Call CFArrayGetValues
        // CFArrayGetValues(arguments as CFArray, CFRangeMake(0, CFIndex(arguments.count)), argsUnsafeMutablePointer)
        
        // Call DADiskMountWithArguments
        // DADiskMountWithArguments(self.diskRef, url, DADiskMountOptions(kDADiskMountOptionDefault), diskMountCallback, nil, argsUnsafeMutablePointer)
    }
    
    // MARK: -
    // MARK: Unmount
    
    public func unmount(options: DADiskUnmountOptions?) {
        let unmountOptions: DADiskUnmountOptions
        if let opts: DADiskUnmountOptions = options {
            unmountOptions = opts
        } else {
            unmountOptions = DADiskUnmountOptions(kDADiskUnmountOptionDefault)
        }
        
        DADiskUnmount(self.diskRef, unmountOptions, diskUnmountCallback, nil)
    }
    
    
    // MARK: -
    // MARK: Eject
    
    public func eject() {
        
        if !self.isMediaEjectable() {
            print("Disk is NOT ejectable!")
            return
        }
        
        /*
        // FIXME: Handle self as parent
        // Also, verify this is neccessary
        if let parent = self.parent {
            for child in parent.children {
                if child.volumeMounted() {
                    child.unmount(options: nil)
                }
            }
        }
 */
        DADiskEject(self.diskRef, DADiskEjectOptions(kDADiskEjectOptionDefault), diskEjectCallback, nil)
    }
    
    
    // MARK: -
    // MARK: Disk Image
    
    
    // Disk Image
    public func diskImage() -> DiskImage? {
        
        if !self.isDiskImage() {
            return nil
        }
        
        if self.diskImageInstance != nil {
            return self.diskImageInstance
        }
        
        if let diskImageURL = self.diskImageURL() {
            self.diskImageInstance = DiskImage.init(url: diskImageURL)
            return self.diskImageInstance!
        }
        return nil
    }
    
    // Disk Image URL
    public func diskImageURL() -> URL? {
        
        if !self.isDiskImage() {
            return nil
        }
        
        guard let devicePath = self.devicePath() else {
            return nil
        }
        
        let service = IORegistryEntryFromPath(kIOMasterPortDefault, (devicePath as NSString).deletingLastPathComponent)
        var cfProperties:Unmanaged<CFMutableDictionary>?
        
        guard
            KERN_SUCCESS == IORegistryEntryCreateCFProperties(service, &cfProperties, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)),
            let properties = cfProperties?.takeUnretainedValue() as? [String : Any]
            else {
                return nil
        }
        
        guard
            let imagePathData = properties["image-path"],
            (CFGetTypeID(imagePathData as CFTypeRef) == CFDataGetTypeID())
            else {
            return nil
        }
        
        if let imagePath = String(data: imagePathData as! CFData as Data, encoding: String.Encoding.utf8) {
            return URL.init(fileURLWithPath: imagePath)
        }
        
        return nil
    }
    
    // Is Disk Image
    public func isDiskImage() -> Bool { return (self.deviceModel() == "Disk Image") }
    
    // MARK: -
    // MARK: Appearance Time
    
    
    // DAAppearanceTime
    public func appearanceTime() -> Date? {
        if let time = self.description(key: "DAAppearanceTime" as CFString) as? Double {
            return Date(timeIntervalSinceReferenceDate: time)
        }
        return nil
    }
    
    
    // MARK: -
    // MARK: Bus
    
    
    // DABusName
    public func busName() -> String? { return self.description(key: kDADiskDescriptionBusNameKey) as? String }
    
    // DABusPath
    public func busPath() -> String? { return self.description(key: kDADiskDescriptionBusPathKey) as? String }
    
    
    // MARK: -
    // MARK: CoreStorage
    
    
    // CoreStorage
    public func isCoreStorage() -> Bool { return self.ioDescription(key: "CoreStorage") as? NSNumber == 1 ? true : false }
    
    // CoreStorage Encrypted
    public func isCoreStorageEncrypted() -> Bool { return self.ioDescription(key: "CoreStorage Encrypted") as? NSNumber == 1 ? true : false }
    
    // CoreStorage CPDK
    public func isCoreStorageCPDK() -> Bool { return self.ioDescription(key: "CoreStorage CPDK") as? NSNumber == 1 ? true : false }
    
    // CoreStorage LVF UUID
    public func coreStorageLVFUUID() -> UUID? {
        
        // CFUUID / NSUUID / UUID is NOT toll-free bridged
        if let cfUUID = (self.ioDescription(key: "CoreStorage LVF UUID")) {
            return UUID.init(uuidString: CFUUIDCreateString(nil, cfUUID as! CFUUID) as String)
        }
        return nil
    }
    
    // CoreStorage LVG UUID
    public func coreStorageLVGUUID() -> UUID? {
        
        // CFUUID / NSUUID / UUID is NOT toll-free bridged
        if let cfUUID = (self.ioDescription(key: "CoreStorage LVG UUID")) {
            return UUID.init(uuidString: CFUUIDCreateString(nil, cfUUID as! CFUUID) as String)
        }
        return nil
    }
    
    
    // MARK: -
    // MARK: Device
    
    
    // Device GUID
    public func deviceGUID() -> String? { return self.description(key: kDADiskDescriptionDeviceGUIDKey) as? String }
    
    // DADeviceInternal
    public func isDeviceInternal() -> Bool { return self.description(key: kDADiskDescriptionDeviceInternalKey) as? NSNumber == 1 ? true : false }
    
    // DADeviceModel
    public func deviceModel() -> String? { return self.description(key: kDADiskDescriptionDeviceModelKey) as? String }
    
    // DADevicePath
    public func devicePath() -> String? { return self.description(key: kDADiskDescriptionDevicePathKey) as? String }
    
    // DADeviceProtocol
    public func deviceProtocol() -> String? { return self.description(key: kDADiskDescriptionDeviceProtocolKey) as? String }
    
    // DADeviceRevision
    public func deviceRevision() -> String? { return self.description(key: kDADiskDescriptionDeviceRevisionKey) as? String }
    
    // DADeviceUnit
    public func deviceUnit() -> NSNumber? { return self.description(key: kDADiskDescriptionDeviceUnitKey) as? NSNumber }
    
    // DADeviceVendor
    public func deviceVendor() -> String? { return self.description(key: kDADiskDescriptionDeviceVendorKey) as? String }
    
    
    // MARK: -
    // MARK: Media
    
    
    // DAMediaBlockSize
    public func mediaBlockSize() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBlockSizeKey) as? NSNumber }
    
    // DAMediaBSDMajor
    public func mediaBSDMajor() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBSDMajorKey) as? NSNumber }
    
    // DAMediaBSDMinor
    public func mediaBSDMinor() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBSDMinorKey) as? NSNumber }
    
    // DAMediaBSDName
    public func mediaBSDName() -> String? { return self.description(key: kDADiskDescriptionMediaBSDNameKey) as? String }
    
    // DAMediaBSDUnit
    public func mediaBSDUnit() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBSDUnitKey) as? NSNumber }
    
    // DAMediaContent
    public func mediaContent() -> String? { return self.description(key: kDADiskDescriptionMediaContentKey) as? String }
    
    // DAMediaEjectable
    public func isMediaEjectable() -> Bool { return self.description(key: kDADiskDescriptionMediaEjectableKey) as? NSNumber == 1 ? true : false }
    
    // DAMediaKind
    public func mediaKind() -> String? { return self.description(key: kDADiskDescriptionMediaKindKey) as? String }
    
    // DAMediaLeaf
    public func isMediaLeaf() -> Bool { return self.description(key: kDADiskDescriptionMediaLeafKey) as? NSNumber == 1 ? true : false }
    
    // DAMediaName
    public func mediaName() -> String? { return self.description(key: kDADiskDescriptionMediaNameKey) as? String }
    
    // DAMediaPath
    public func mediaPath() -> String? { return self.description(key: kDADiskDescriptionMediaPathKey) as? String }
    
    // DAMediaRemovable
    public func isMediaRemovable() -> Bool { return self.description(key: kDADiskDescriptionMediaRemovableKey) as? NSNumber == 1 ? true : false }
    
    // DAMediaSize
    public func mediaSize() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaSizeKey) as? NSNumber }
    
    // ?? Media Type
    public func mediaType() -> String? { return self.description(key: kDADiskDescriptionMediaTypeKey) as? String }
    
    // DAMediaUUID
    public func mediaUUID() -> UUID? {
        
        // CFUUID / NSUUID / UUID is NOT toll-free bridged
        if let cfUUID = (self.description(key: kDADiskDescriptionMediaUUIDKey)) {
            return UUID.init(uuidString: CFUUIDCreateString(nil, cfUUID as! CFUUID) as String)
        }
        return nil
    }
    
    // DAMediaWhole
    public func isMediaWhole() -> Bool { return self.description(key: kDADiskDescriptionMediaWholeKey) as? NSNumber == 1 ? true : false }
    
    // DAMediaWritable
    public func isMediaWritable() -> Bool { return self.description(key: kDADiskDescriptionMediaWritableKey) as? NSNumber == 1 ? true : false }
    
    // DAMediaIcon
    public func mediaIcon() -> NSImage? {
        guard let mediaIconDict = self.description(key: kDADiskDescriptionMediaIconKey) as? Dictionary<String, Any> else {
            return nil
        }
        
        guard let bundleIdentifier = mediaIconDict[kCFBundleIdentifierKey as String] as? String else {
            return nil
        }
        
        guard let bundle = KextManagerBridge.bundle(forIdentifier: bundleIdentifier) else {
            return nil
        }
        
        guard let iconName = mediaIconDict[kIOBundleResourceFileKey as String] as? String else {
            return nil
        }
        
        return bundle.image(forResource: iconName)
    }
    
    
    // MARK: -
    // MARK: Volume
    
    
    // Volume Booted
    public func isVolumeBooted() -> Bool {
        if let volumePath = self.volumePath(), volumePath.path == "/" {
            return true
        }
        return false
    }
    
    // DAVolumeKind
    public func volumeKind() -> String? { return self.description(key: kDADiskDescriptionVolumeKindKey) as? String }
    
    // DAVolumeMountable
    public func isVolumeMountable() -> Bool { return self.description(key: kDADiskDescriptionVolumeMountableKey) as? NSNumber == 1 ? true : false }
    
    // Volume Mounted
    public func isVolumeMounted() -> Bool {
        return self.ioDescription(key: "Open") as? NSNumber == 1 ? true : false
        // return (self.volumePath() != nil)
    }
    
    // DAVolumeName
    public func volumeName() -> String? { return self.description(key: kDADiskDescriptionVolumeNameKey) as? String }
    
    // DAVolumeNetwork
    public func isVolumeNetwork() -> Bool { return self.description(key: kDADiskDescriptionVolumeNetworkKey) as? NSNumber == 1 ? true : false }
    
    // DAVolumePath
    public func volumePath() -> URL? { return self.description(key: kDADiskDescriptionVolumePathKey) as? URL }
    
    // DAVolumeType
    public func volumeType() -> String? { return self.description(key: kDADiskDescriptionVolumeTypeKey) as? String }
    
    // DAVolumeUUID
    public func volumeUUID() -> UUID? {
        
        // CFUUID / NSUUID / UUID is NOT toll-free bridged
        if let cfUUID = (self.description(key: kDADiskDescriptionVolumeUUIDKey)) {
            return UUID.init(uuidString: CFUUIDCreateString(nil, cfUUID as! CFUUID) as String)
        }
        return nil
    }
    
        
    public func printValues() {
        
        print("\n** CALCULATED VALUES **")
        print("Is Disk Image: \(String(describing: self.isDiskImage()))")
        print("Disk Image URL: \(String(describing: self.diskImageURL()))")
        print("Volume Mounted: \(String(describing: self.isVolumeMounted()))")
        
        print("\n\n** APPEARANCE TIME **")
        print("Appearance Time: \(String(describing: self.appearanceTime()))")
        
        print("\n** BUS **")
        print("Bus Name: \(String(describing: self.busName()))")
        print("Bus Path: \(String(describing: self.busPath()))")
        
        print("\n** DEVICE **")
        print("Device GUID: \(String(describing: self.deviceGUID()))")
        print("Device Internal: \(String(describing: self.isDeviceInternal()))")
        print("Device Model: \(String(describing: self.deviceModel()))")
        print("Device Path: \(String(describing: self.devicePath()))")
        print("Device Protocol: \(String(describing: self.deviceProtocol()))")
        print("Device Revision: \(String(describing: self.deviceRevision()))")
        print("Device Unit: \(String(describing: self.deviceUnit()))")
        print("Device Vendor: \(String(describing: self.deviceVendor()))")
        
        print("\n** MEDIA **")
        print("Media Block Size: \(String(describing: self.mediaBlockSize()))")
        print("Media BSD Major: \(String(describing: self.mediaBSDMajor()))")
        print("Media BSD Minor: \(String(describing: self.mediaBSDMinor()))")
        print("Media BSD Name: \(String(describing: self.mediaBSDName()))")
        print("Media BSD Unit: \(String(describing: self.mediaBSDUnit()))")
        print("Media Content: \(String(describing: self.mediaContent()))")
        print("Media Ejectable: \(String(describing: self.isMediaEjectable()))")
        print("Media Icon: \(String(describing: self.mediaIcon()))")
        print("Media Kind: \(String(describing: self.mediaKind()))")
        print("Media Leaf: \(String(describing: self.isMediaLeaf()))")
        print("Media Name: \(String(describing: self.mediaName()))")
        print("Media Path: \(String(describing: self.mediaPath()))")
        print("Media Removable: \(String(describing: self.isMediaRemovable()))")
        print("Media Size: \(String(describing: self.mediaSize()))")
        print("Media Type: \(String(describing: self.mediaType()))")
        print("Media UUID: \(String(describing: self.mediaUUID()))")
        print("Media Whole: \(String(describing: self.isMediaWhole()))")
        print("Media Writable: \(String(describing: self.isMediaWritable()))")
        
        print("\n** VOLUME **")
        print("Volume Kind: \(String(describing: self.volumeKind()))")
        print("Volume Mountable: \(String(describing: self.isVolumeMountable()))")
        print("Volume Name: \(String(describing: self.volumeName()))")
        print("Volume Network: \(String(describing: self.isVolumeNetwork()))")
        print("Volume Path: \(String(describing: self.volumePath()))")
        print("Volume Type: \(String(describing: self.volumeType()))")
        print("Volume UUID: \(String(describing: self.volumeUUID()))")
    }
}

// Conforming to Equatable
public func ==(lhs: Disk, rhs: Disk) -> Bool {
    return CFHash(lhs.diskRef) == CFHash(rhs.diskRef)
}
