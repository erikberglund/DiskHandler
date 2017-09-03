//
//  DiskImage.swift
//  DiskHandler
//
//  Created by Erik Berglund on 2017-06-24.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import Foundation

public class DiskImagePartition {
    
    public var data: Data?
    public var fileSystems: Dictionary<String, Any>?
    public var hint: String?
    public var hintUUID: UUID?
    public var length: NSNumber?
    public var name: String?
    public var number: NSNumber?
    public var start: NSNumber?
    public var synthesized: Bool
    public var partitionUUID: UUID?
    
    public weak var disk: Disk?
    private weak var parentDiskImage: DiskImage?
    
    /*
     EFI_SYSTEM_PARTITION   = C12A7328-F81F-11D2-BA4B-00A0C93EC93B
     HFSPLUS_PARTITION      = 48465300-0000-11AA-AA11-00306543ECAC
     APPLE_RECOVERY         = 426F6F74-0000-11AA-AA11-00306543ECAC
     */
    
    private var debugKnownPartitionKeys: Set = ["partition-data",
                                                "partition-filesystems",
                                                "partition-hint",
                                                "partition-hint-UUID",
                                                "partition-length",
                                                "partition-name",
                                                "partition-number",
                                                "partition-start",
                                                "partition-synthesized",
                                                "partition-UUID"]
    
    init(partitionInfo: [String : Any], diskImage: DiskImage?) {

        // NOTE: Only while debugging
        let unknownKeys = Array(Set(partitionInfo.keys).subtracting(debugKnownPartitionKeys))
        if unknownKeys.count != 0 {
            print("UNKOWN PARTITION KEYS: \(unknownKeys)")
        }
        
        self.data          = partitionInfo["partition-data"] as? Data
        self.fileSystems   = partitionInfo["partition-filesystems"] as? [String : Any]
        self.hint          = partitionInfo["partition-hint"] as? String
        if let hintUUIDString = partitionInfo["partition-hint-UUID"] as? String {
            self.hintUUID = UUID.init(uuidString: hintUUIDString)
        } else {
            self.hintUUID = nil
        }
        self.length        = partitionInfo["partition-length"] as? NSNumber
        self.name          = partitionInfo["partition-name"] as? String
        self.number        = partitionInfo["partition-number"] as? NSNumber
        self.start         = partitionInfo["partition-start"] as? NSNumber
        self.synthesized   = partitionInfo["partition-synthesized"] as? NSNumber == 1 ? true : false
        if let partitionUUIDString = partitionInfo["partition-UUID"] as? String {
            self.partitionUUID = UUID.init(uuidString: partitionUUIDString)
        } else {
            self.partitionUUID = nil
        }
        
        if let partitionNumber = self.number, let parentDiskImage = diskImage {
            self.parentDiskImage = parentDiskImage
            if let parentDisk = parentDiskImage.disk(), let parentDiskBSDUnit = parentDisk.mediaBSDUnit {
                let bsdName = "disk\(parentDiskBSDUnit)s\(partitionNumber)"
                if let matchingDisks = DiskController.shared.disks(matching: [kDADiskDescriptionMediaBSDNameKey as String : bsdName]) {
                    self.disk = matchingDisks.first
                }
            }
        }
    }
}

public class DiskImage: Hashable, Equatable {
    
    public var url: URL?
    
    private var ioDeviceDictionary: [String: Any]?
    private var infoDictionary: [String : Any]?
    private var resourcesDictionary: [String : Any]?
    
    // Conforming to Hashable
    public var hashValue: Int {
        return (self.url?.hashValue)!
    }
    
    public init(url: URL) {
        self.url = url
        
        if let infoDict = self.infoDict() {
            self.infoDictionary = infoDict
        }
        
        if let resourcesDict = self.resourcesDict() {
            self.resourcesDictionary = resourcesDict
        }
    }
    
    init(devicePath: String) {
        
        let service = IORegistryEntryFromPath(kIOMasterPortDefault, (devicePath as NSString).deletingLastPathComponent)
        var cfProperties:Unmanaged<CFMutableDictionary>?
        
        guard
            KERN_SUCCESS == IORegistryEntryCreateCFProperties(service, &cfProperties, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)),
            let properties = cfProperties?.takeUnretainedValue() as? [String : Any]
            else {
                return
        }
        
        // FIXME: Print Properties
        // print("properties: \(properties)")
        
        guard let imagePathData = properties["image-path"], (CFGetTypeID(imagePathData as CFTypeRef) == CFDataGetTypeID()) else {
            return
        }
        
        if
            let imagePath = String(data: imagePathData as! CFData as Data, encoding: String.Encoding.utf8) {
            self.url = URL.init(fileURLWithPath: imagePath)
        }
        
        if let infoDict = self.infoDict() {
            self.infoDictionary = infoDict
        }
    }
    
    public func disk() -> Disk? {
        if let disks = DiskController.shared.disks(matching: [ kDADiskDescriptionDeviceModelKey as String : "Disk Image" ]) {
            var matchingDisks: Set<Disk> = disks
            matchingDisks = Set(matchingDisks.filter({
                if let url = $0.diskImageURL, $0.isMediaWhole {
                    return url == self.url
                }
                return false
            }))
            return matchingDisks.first ?? nil
        }
        return nil
    }
    
    public func infoDict() -> [String : Any]? {
        
        // Check if already exists and if file has changed
        if self.infoDictionary != nil {
            return self.infoDictionary
        } else if let url = self.url {
            return DiskImageController.shared.info(url: url)
        }
        return nil
    }
    
    public func resourcesDict() -> [String : Any]? {
        
        // Check if already exists and if file has changed
        if self.resourcesDictionary != nil {
            return self.resourcesDictionary
        } else if let url = self.url, !self.isMounted() {
            return DiskImageController.shared.udifderez(url: url)
        }
        return nil
    }
    
    public func isMounted() -> Bool {
        if let partitions = self.partitions {
            for partition in partitions {
                if let partitionDisk = partition.disk, partitionDisk.isVolumeMounted {
                    return true
                }
            }
        } else if let url = self.url {
            return DiskImageController.shared.isMounted(url: url)
        }
        return false
    }
    
    /*
     Custom functions to extend possible values
     */
    
    public func icon() -> NSImage? {
        if let url = self.url {
            return NSWorkspace.shared.icon(forFileType: url.pathExtension)
        }
        return nil
    }
    
    /* ROOT ITEMS */
    
    
    // Checksum Type
    public var checksumType: String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Checksum Type"] as? String
    }
    
    // Checksum Value
    public var checksumValue: String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Checksum Value"] as? String
    }
    
    // Class Name
    public var className: String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Class Name"] as? String
    }
    
    // Format
    public var format: String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Format"] as? String
    }
    
    // Format Description
    public var formatDescription: String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Format Description"] as? String
    }
    
    // Segments
    public var segments: Array<String>? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Segments"] as? Array<String>
    }
    
    // udif-ordered-chunks
    public var hasUDIFOrderedChunks: Bool {
        guard let infoDict = self.infoDict() else { return false }
        return infoDict["udif-ordered-chunks"] as? NSNumber == 1 ? true : false
    }
    
    
    /* PARTITIONS */
    
    
    // partitions:appendable
    public var isAppendable: Bool {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return false }
        return partitions["appendable"] as? NSNumber == 1 ? true : false
    }
    
    // partitions:block-size
    public var blockSize: NSNumber? {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return nil }
        return partitions["block-size"] as? NSNumber
    }
    
    // partitions:burnable
    public var isBurnable: Bool {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return false }
        return partitions["burnable"] as? NSNumber == 1 ? true : false
    }
    
    // partitions:partition-scheme
    public var partitionScheme: String? {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return nil }
        return partitions["partition-scheme"] as? String
    }
    
    // partitions:partitions
    public var partitions: Array<DiskImagePartition>? {
        var partitionsArray: Array<DiskImagePartition> = []
        guard
            let infoDict = self.infoDict(),
            let partitionsDict = infoDict["partitions"] as? [String : Any],
            let partitionsDictArray = partitionsDict["partitions"] as? Array<[String : Any]>
            else {
                return nil
        }
        for partitionDict in partitionsDictArray {
            let partition = DiskImagePartition.init(partitionInfo: partitionDict, diskImage: self)
            
            // We're only interested in file system partitions
            if (partition.number != nil) {
                partitionsArray.append(partition)
            }
        }
        return partitionsArray
    }
    
    /* PROPERTIES */
    
    
    // Properties:Checksummed
    public var isChecksummed: Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Checksummed"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Compressed
    public var isCompressed: Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Compressed"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Encrypted
    // NOTE: This might be wrong to use a lazy var if a DiskImage can change encryption state
    //       A fix might be to use the invalidate method to invalidate info that can change if the file has changed. Need to implement that.
    public lazy var isEncrypted: Bool = {
        if let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] {
            return properties["Encrypted"] as? NSNumber == 1 ? true : false
        } else if
            let url = self.url,
            let isEncryptedDict = DiskImageController.shared.isEncrypted(url: url),
            let isEncrypted = isEncryptedDict["encrypted"] as? Bool {
            return isEncrypted
        } else {
            // FIXME: This is not correct, how to check this? URL can't be required, so what is the next fallback. IOKit probably
            return false
        }
    }()
    
    // Properties:Kernel Compatible
    public var isKernelCompatible: Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Kernel Compatible"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Partitioned
    public var isPartitioned: Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Partitioned"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Software License Agreement
    public var hasSoftwareLicenseAgreement: Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Software License Agreement"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Software License Agreement Text
    public var softwareLicenseAgreementText: String? {
        if let resourcesDict = self.resourcesDict() {
            print("resourcesDict: \(resourcesDict)")
        }
        return ""
    }
    
    /* SIZE INFORMATION */
    
    
    // Size Information:CUDIFEncoding-bytes-in-use
    public var cudifEncodingBytesInUse: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["CUDIFEncoding-bytes-in-use"] as? NSNumber
    }
    
    // Size Information:CUDIFEncoding-bytes-total
    public var cudifEncodingBytesTotal: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["CUDIFEncoding-bytes-total"] as? NSNumber
    }
    
    // Size Information:CUDIFEncoding-bytes-wasted
    public var cudifEncodingBytesWasted: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["CUDIFEncoding-bytes-wasted"] as? NSNumber
    }
    
    // Size Information:Compressed Bytes
    public var compressedBytes: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Compressed Bytes"] as? NSNumber
    }
    
    // Size Information:Compressed Ratio
    public var compressedRatio: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Compressed Ratio"] as? NSNumber
    }
    
    // Size Information:Sector Count
    public var sectorCount: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Sector Count"] as? NSNumber
    }
    
    // Size Information:Total Bytes
    public var totalBytes: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Total Bytes"] as? NSNumber
    }
    
    // Size Information:Total Empty Bytes
    public var totalEmptyBytes: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Total Empty Bytes"] as? NSNumber
    }
    
    // Size Information:Total Non-Empty Bytes
    public var totalNonEmptyBytes: NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Total Non-Empty Bytes"] as? NSNumber
    }
}

// Conforming to Equatable
public func ==(lhs: DiskImage, rhs: DiskImage) -> Bool {
    return lhs.url == rhs.url
}
