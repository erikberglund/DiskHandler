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
            
            if let parentDisk = parentDiskImage.disk(), let parentDiskBSDUnit = parentDisk.mediaBSDUnit() {
                let bsdName = "disk\(parentDiskBSDUnit)s\(partitionNumber)"
                if let matchingDisks = DiskController.shared.disks(matching: [kDADiskDescriptionMediaBSDNameKey as String : bsdName]) {
                    self.disk = matchingDisks.first
                }
            }
        }
    }
    
    public func printValues() {
        
        print("\n** PARTITION INFO **")
        print("Partition Data: \(String(describing: self.data))")
        print("Partition Filesystems: \(String(describing: self.fileSystems))")
        print("Partition Hint: \(String(describing: self.hint))")
        print("Partition Hint UUID: \(String(describing: self.hintUUID))")
        print("Partition Length: \(String(describing: self.length))")
        print("Partition Name: \(String(describing: self.name))")
        print("Partition Number: \(String(describing: self.number))")
        print("Partition Start: \(String(describing: self.start))")
        print("Partition Synthesized: \(String(describing: self.synthesized))")
        print("Partition UUID: \(String(describing: self.partitionUUID))")
    }
}

public class DiskImage {
    
    public var url: URL?
    
    private var infoDictionary: [String : Any]?
    private var resourcesDictionary: [String : Any]?
    
    init(url: URL) {
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
                if let url = $0.diskImageURL(), $0.isMediaWhole() {
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
            return DiskImageController().info(url: url)
        }
        return nil
    }
    
    public func resourcesDict() -> [String : Any]? {
        
        // Check if already exists and if file has changed
        if self.resourcesDictionary != nil {
            return self.resourcesDictionary
        } else if let url = self.url, !self.isMounted() {
            return DiskImageController().udifderez(url: url)
        }
        return nil
    }
    
    public func isMounted() -> Bool {
        if let partitions = self.partitions() {
            for partition in partitions {
                if let partitionDisk = partition.disk, partitionDisk.isVolumeMounted() {
                    return true
                }
            }
        }
        return false
    }
    
    /*
     Custom functions to extend possible values
     */
    
    public func icon() -> NSImage? {
        if let url = self.url {
            return NSWorkspace.shared().icon(forFileType: url.pathExtension)
        }
        return nil
    }
    
    /* ROOT ITEMS */
    
    
    // Checksum Type
    public func checksumType() -> String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Checksum Type"] as? String
    }
    
    // Checksum Value
    public func checksumValue() -> String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Checksum Value"] as? String
    }
    
    // Class Name
    public func className() -> String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Class Name"] as? String
    }
    
    // Format
    public func format() -> String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Format"] as? String
    }
    
    // Format Description
    public func formatDescription() -> String? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Format Description"] as? String
    }
    
    // Segments
    public func segments() -> Array<String>? {
        guard let infoDict = self.infoDict() else { return nil }
        return infoDict["Segments"] as? Array<String>
    }
    
    // udif-ordered-chunks
    public func hasUDIFOrderedChunks() -> Bool {
        guard let infoDict = self.infoDict() else { return false }
        return infoDict["udif-ordered-chunks"] as? NSNumber == 1 ? true : false
    }
    
    
    /* PARTITIONS */
    
    
    // partitions:appendable
    public func isAppendable() -> Bool {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return false }
        return partitions["appendable"] as? NSNumber == 1 ? true : false
    }
    
    // partitions:block-size
    public func blockSize() -> NSNumber? {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return nil }
        return partitions["block-size"] as? NSNumber
    }
    
    // partitions:burnable
    public func isBurnable() -> Bool {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return false }
        return partitions["burnable"] as? NSNumber == 1 ? true : false
    }
    
    // partitions:partition-scheme
    public func partitionScheme() -> String? {
        guard let infoDict = self.infoDict(), let partitions = infoDict["partitions"] as? [String : Any] else { return nil }
        return partitions["partition-scheme"] as? String
    }
    
    // partitions:partitions
    public func partitions() -> Array<DiskImagePartition>? {
        var partitionsArray: Array<DiskImagePartition> = []
        guard let infoDict = self.infoDict(),
            let partitionsDict = infoDict["partitions"] as? [String : Any],
            let partitionsDictArray = partitionsDict["partitions"] as? Array<[String : Any]> else { return nil }
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
    public func isChecksummed() -> Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Checksummed"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Compressed
    public func isCompressed() -> Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Compressed"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Encrypted
    public func isEncrypted() -> Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Encrypted"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Kernel Compatible
    public func isKernelCompatible() -> Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Kernel Compatible"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Partitioned
    public func isPartitioned() -> Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Partitioned"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Software License Agreement
    public func hasSoftwareLicenseAgreement() -> Bool {
        guard let infoDict = self.infoDict(), let properties = infoDict["Properties"] as? [String : Any] else { return false }
        return properties["Software License Agreement"] as? NSNumber == 1 ? true : false
    }
    
    // Properties:Software License Agreement Text
    public func softwareLicenseAgreementText() -> String? {
        if let resourcesDict = self.resourcesDict() {
            print("resourcesDict: \(resourcesDict)")
        }
        return ""
    }
    
    /* SIZE INFORMATION */
    
    
    // Size Information:CUDIFEncoding-bytes-in-use
    public func cudifEncodingBytesInUse() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["CUDIFEncoding-bytes-in-use"] as? NSNumber
    }
    
    // Size Information:CUDIFEncoding-bytes-total
    public func cudifEncodingBytesTotal() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["CUDIFEncoding-bytes-total"] as? NSNumber
    }
    
    // Size Information:CUDIFEncoding-bytes-wasted
    public func cudifEncodingBytesWasted() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["CUDIFEncoding-bytes-wasted"] as? NSNumber
    }
    
    // Size Information:Compressed Bytes
    public func compressedBytes() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Compressed Bytes"] as? NSNumber
    }
    
    // Size Information:Compressed Ratio
    public func compressedRatio() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Compressed Ratio"] as? NSNumber
    }
    
    // Size Information:Sector Count
    public func sectorCount() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Sector Count"] as? NSNumber
    }
    
    // Size Information:Total Bytes
    public func totalBytes() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Total Bytes"] as? NSNumber
    }
    
    // Size Information:Total Empty Bytes
    public func totalEmptyBytes() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Total Empty Bytes"] as? NSNumber
    }
    
    // Size Information:Total Non-Empty Bytes
    public func totalNonEmptyBytes() -> NSNumber? {
        guard let infoDict = self.infoDict(), let sizeInfo = infoDict["Size Information"] as? [String : Any] else { return nil }
        return sizeInfo["Total Non-Empty Bytes"] as? NSNumber
    }
    
    
    /* PRINT VALUES */
    
    
    public func printValues() {
        
        print("\n** ROOT ITEMS **")
        print("Checksum Type: \(String(describing: self.checksumType()))")
        print("Checksum Value: \(String(describing: self.checksumValue()))")
        print("Class Name: \(String(describing: self.className()))")
        print("Format: \(String(describing: self.format()))")
        print("Format Description: \(String(describing: self.formatDescription()))")
        print("Segments: \(String(describing: self.segments()))")
        print("UDIF Ordered Chunks: \(String(describing: self.hasUDIFOrderedChunks()))")
        
        print("\n** PARTITIONS **")
        print("Appendable: \(String(describing: self.isAppendable()))")
        print("Block Size: \(String(describing: self.blockSize()))")
        print("Burnable: \(String(describing: self.isBurnable()))")
        print("Partition Scheme: \(String(describing: self.partitionScheme()))")
        print("Partitions: \(String(describing: self.partitions()))")
        
        print("\n** PROPERTIES **")
        print("Checksummed: \(String(describing: self.isChecksummed()))")
        print("Compressed: \(String(describing: self.isCompressed()))")
        print("Encrypted: \(String(describing: self.isEncrypted()))")
        print("Kernel Compatible: \(String(describing: self.isKernelCompatible()))")
        print("Partitioned: \(String(describing: self.isPartitioned()))")
        print("Software License Agreement: \(String(describing: self.hasSoftwareLicenseAgreement()))")
        print("Software License Agreement Text: \(String(describing: self.softwareLicenseAgreementText()))")
        
        print("\n** SIZE INFORMATION **")
        print("CUDIFEncoding-bytes-in-use: \(String(describing: self.cudifEncodingBytesInUse()))")
        print("CUDIFEncoding-bytes-total: \(String(describing: self.cudifEncodingBytesTotal()))")
        print("CUDIFEncoding-bytes-wasted: \(String(describing: self.cudifEncodingBytesWasted()))")
        print("Compressed Bytes: \(String(describing: self.compressedBytes()))")
        print("Compressed Ratio: \(String(describing: self.compressedRatio()))")
        print("Sector Count: \(String(describing: self.sectorCount()))")
        print("Total Bytes: \(String(describing: self.totalBytes()))")
        print("Total Empty Bytes: \(String(describing: self.totalEmptyBytes()))")
        print("Total Non-Empty Bytes: \(String(describing: self.totalNonEmptyBytes()))")
        
    }
}
