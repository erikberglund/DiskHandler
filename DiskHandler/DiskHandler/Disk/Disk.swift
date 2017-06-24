//
//  Disk.swift
//  DiskHandler
//
//  Created by Erik Berglund on 2017-06-24.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import DiskArbitration
import Foundation

public class Disk: Hashable {
    
    public var diskRef: DADisk
    public var hashValue: Int {
        return Int(CFHash(self.diskRef))
    }
    
    init(diskRef: DADisk) {
        self.diskRef = diskRef
    }
    
    // Get disk description values for passed key
    func description() -> [String: Any]? {
        return DADiskCopyDescription(self.diskRef) as? [String: Any]
    }
    
    // Get disk description values for passed key
    func description(key: CFString) -> Any? {
        if let diskDescription = description() {
            return diskDescription[key as String]
        }
        return nil
    }
    
    // Return the CFHashCode for disk ref
    func hash() -> CFHashCode {
        return CFHash(self.diskRef)
    }
    
    /*
     Convenience methods to get disk values by calling instance methods
     */
    
    
    /* APPEARANCE TIME */
    
    
    // DAAppearanceTime
    func appearanceTime() -> Date? {
        if let time = self.description(key: "DAAppearanceTime" as CFString) as? Double {
            return Date(timeIntervalSinceReferenceDate: time)
        }
        return nil
    }
    
    
    /* BUS */
    
    
    // DABusName
    func busName() -> String? { return self.description(key: kDADiskDescriptionBusNameKey) as? String }
    
    // DABusPath
    func busPath() -> String? { return self.description(key: kDADiskDescriptionBusPathKey) as? String }
    
    
    /* DEVICE */
    
    
    // Device GUID
    func deviceGUID() -> String? { return self.description(key: kDADiskDescriptionDeviceGUIDKey) as? String }
    
    // DADeviceInternal
    func deviceInternal() -> Bool { return self.description(key: kDADiskDescriptionDeviceInternalKey) as? NSNumber == 0 ? true : false }
    
    // DADeviceModel
    func deviceModel() -> String? { return self.description(key: kDADiskDescriptionDeviceModelKey) as? String }
    
    // DADevicePath
    func devicePath() -> String? { return self.description(key: kDADiskDescriptionDevicePathKey) as? String }
    
    // DADeviceProtocol
    func deviceProtocol() -> String? { return self.description(key: kDADiskDescriptionDeviceProtocolKey) as? String }
    
    // DADeviceRevision
    func deviceRevision() -> String? { return self.description(key: kDADiskDescriptionDeviceRevisionKey) as? String }
    
    // DADeviceUnit
    func deviceUnit() -> NSNumber? { return self.description(key: kDADiskDescriptionDeviceUnitKey) as? NSNumber }
    
    // DADeviceVendor
    func deviceVendor() -> String? { return self.description(key: kDADiskDescriptionDeviceVendorKey) as? String }
    
    
    /* MEDIA */
    
    // DAMediaBlockSize
    func mediaBlockSize() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBlockSizeKey) as? NSNumber }
    
    // DAMediaBSDMajor
    func mediaBSDMajor() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBSDMajorKey) as? NSNumber }
    
    // DAMediaBSDMinor
    func mediaBSDMinor() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBSDMinorKey) as? NSNumber }
    
    // DAMediaBSDName
    func mediaBSDName() -> String? { return self.description(key: kDADiskDescriptionMediaBSDNameKey) as? String }
    
    // DAMediaBSDUnit
    func mediaBSDUnit() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaBSDUnitKey) as? NSNumber }
    
    // DAMediaContent
    func mediaContent() -> String? { return self.description(key: kDADiskDescriptionMediaContentKey) as? String }
    
    // DAMediaEjectable
    func mediaEjectable() -> Bool { return self.description(key: kDADiskDescriptionMediaEjectableKey) as? NSNumber == 0 ? true : false }
    
    // DAMediaKind
    func mediaKind() -> String? { return self.description(key: kDADiskDescriptionMediaKindKey) as? String }
    
    // DAMediaLeaf
    func mediaLeaf() -> Bool { return self.description(key: kDADiskDescriptionMediaLeafKey) as? NSNumber == 0 ? true : false }
    
    // DAMediaName
    func mediaName() -> String? { return self.description(key: kDADiskDescriptionMediaNameKey) as? String }
    
    // DAMediaPath
    func mediaPath() -> String? { return self.description(key: kDADiskDescriptionMediaPathKey) as? String }
    
    // DAMediaRemovable
    func mediaRemovable() -> Bool { return self.description(key: kDADiskDescriptionMediaRemovableKey) as? NSNumber == 0 ? true : false }
    
    // DAMediaSize
    func mediaSize() -> NSNumber? { return self.description(key: kDADiskDescriptionMediaSizeKey) as? NSNumber }
    
    // ?? Media Type
    func mediaType() -> String? { return self.description(key: kDADiskDescriptionMediaTypeKey) as? String }
    
    // DAMediaUUID
    func mediaUUID() -> UUID? {
        
        // CFUUID / NSUUID / UUID is NOT toll-free bridged
        if let cfUUID = (self.description(key: kDADiskDescriptionMediaUUIDKey)) {
            return UUID.init(uuidString: CFUUIDCreateString(nil, cfUUID as! CFUUID) as String)
        }
        return nil
    }
    
    // DAMediaWhole
    func mediaWhole() -> Bool { return self.description(key: kDADiskDescriptionMediaWholeKey) as? NSNumber == 0 ? true : false }
    
    // DAMediaWritable
    func mediaWritable() -> Bool { return self.description(key: kDADiskDescriptionMediaWritableKey) as? NSNumber == 0 ? true : false }
    
    // DAMediaIcon
    func mediaIcon() -> NSImage? {
        guard let mediaIconDict = self.description(key: kDADiskDescriptionMediaIconKey) as? Dictionary<String, Any> else {
            return nil
        }
        
        guard let bundleIdentifier = mediaIconDict[kCFBundleIdentifierKey as String] as? String else {
            return nil
        }
        
        guard let bundle = KextManager.bundle(forIdentifier: bundleIdentifier) else {
            return nil
        }
        
        guard let iconName = mediaIconDict[kIOBundleResourceFileKey as String] as? String else {
            return nil
        }
        
        return bundle.image(forResource: iconName)
    }
    
    
    /* VOLUME */
    
    // DAVolumeKind
    func volumeKind() -> String? { return self.description(key: kDADiskDescriptionVolumeKindKey) as? String }
    
    // DAVolumeMountable
    func volumeMountable() -> Bool { return self.description(key: kDADiskDescriptionVolumeMountableKey) as? NSNumber == 0 ? true : false }
    
    // Volume Mounted
    func volumeMounted() -> Bool { return (self.volumePath() != nil) }
    
    // DAVolumeName
    func volumeName() -> String? { return self.description(key: kDADiskDescriptionVolumeNameKey) as? String }
    
    // DAVolumeNetwork
    func volumeNetwork() -> Bool { return self.description(key: kDADiskDescriptionVolumeNetworkKey) as? NSNumber == 0 ? true : false }
    
    // DAVolumePath
    func volumePath() -> URL? { return self.description(key: kDADiskDescriptionVolumePathKey) as? URL }
    
    // DAVolumeType
    func volumeType() -> String? { return self.description(key: kDADiskDescriptionVolumeTypeKey) as? String }
    
    // DAVolumeUUID
    func volumeUUID() -> UUID? {
        
        // CFUUID / NSUUID / UUID is NOT toll-free bridged
        if let cfUUID = (self.description(key: kDADiskDescriptionVolumeUUIDKey)) {
            return UUID.init(uuidString: CFUUIDCreateString(nil, cfUUID as! CFUUID) as String)
        }
        return nil
    }
}

// Conforming class Disk to Equatable
public func ==(lhs: Disk, rhs: Disk) -> Bool {
    return CFHash(lhs.diskRef) == CFHash(rhs.diskRef)
}
