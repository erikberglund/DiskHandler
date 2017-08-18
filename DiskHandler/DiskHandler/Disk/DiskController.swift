//
//  DiskController.swift
//  DiskHandler
//
//  Created by Erik Berglund on 2017-06-24.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import DiskArbitration
import Foundation

private var session : DASession?
private var availableDisks = Set<Disk>()

public var approvalMatchMount = Array<Dictionary<String, Any>>()
public var approvalMatchUnmount = Array<Dictionary<String, Any>>()
public var approvalMatchEject = Array<Dictionary<String, Any>>()

// MARK: DiskControllerDelegate

public protocol DiskControllerDelegate: class {
    func diskAppeared(disk: Disk)
    func diskDescriptionChanged(disk: Disk, keys: CFArray)
    func diskDisappeared(disk: Disk)
    func diskPeeked(disk: Disk)
}

public protocol DiskControllerMountDelegate: class {
    func diskMount(disk: Disk, dissenter: DADissenter?)
    func diskUnmount(disk: Disk, dissenter: DADissenter?)
    func diskEject(disk: Disk, dissenter: DADissenter?)
}

// MARK: -
// MARK: DiskController

public class DiskController {
    
    public static let shared = DiskController()
    
    public weak var delegate: DiskControllerDelegate?
    public weak var mountDelegate: DiskControllerMountDelegate?
    public weak var parent: Disk?
    public var children: Set<Disk>?
    
    // MARK: -
    // MARK: Init / Deinit
    
    public init() {
        initialize()
    }
    
    public init(withDelegate delegate: DiskControllerDelegate?) {
        self.delegate = delegate
        initialize()
    }
    
    private func initialize() {
        session = DASessionCreate(kCFAllocatorDefault)
        DASessionSetDispatchQueue(session!, DispatchQueue.global())
        
        DARegisterDiskAppearedCallback(session!, nil, diskAppearedCallback, nil)
        DARegisterDiskDisappearedCallback(session!, nil, diskDisappearedCallback, nil)
        DARegisterDiskDescriptionChangedCallback(session!, nil, nil, diskDescriptionChangedCallback, nil)
        DARegisterDiskPeekCallback(session!, nil, 0, diskPeekCallback, nil)
    }
    
    deinit {
        let diskAppearedCallbackPointer = unsafeBitCast(diskAppearedCallback, to: UnsafeMutableRawPointer.self)
        DAUnregisterCallback(session!, diskAppearedCallbackPointer, nil)
        
        let diskDisappearedCallbackPointer = unsafeBitCast(diskDisappearedCallback, to: UnsafeMutableRawPointer.self)
        DAUnregisterCallback(session!, diskDisappearedCallbackPointer, nil)
        
        let diskDescriptionChangedCallbackPointer = unsafeBitCast(diskDescriptionChangedCallback, to: UnsafeMutableRawPointer.self)
        DAUnregisterCallback(session!, diskDescriptionChangedCallbackPointer, nil)
        
        let diskPeekCallbackPointer = unsafeBitCast(diskPeekCallback, to: UnsafeMutableRawPointer.self)
        DAUnregisterCallback(session!, diskPeekCallbackPointer, nil)
        
        if approvalMatchMount.count != 0 {
            let diskMountApprovalCallbackPointer = unsafeBitCast(diskMountApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskMountApprovalCallbackPointer, nil)
        }
        
        if approvalMatchUnmount.count != 0 {
            let diskUnmountApprovalCallbackPointer = unsafeBitCast(diskUnmountApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskUnmountApprovalCallbackPointer, nil)
        }
        
        if approvalMatchEject.count != 0 {
            let diskEjectApprovalCallbackPointer = unsafeBitCast(diskEjectApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskEjectApprovalCallbackPointer, nil)
        }
    }
    
    // MARK: -
    // MARK: Disks
    
    public func disk(diskRef: DADisk) -> Disk? {
        return availableDisks.first(where: {CFHash($0.diskRef) == CFHash(diskRef) })
    }
    
    public func disks() -> Set<Disk>? {
        return availableDisks
    }
    
    public func disks(matching: Dictionary<String, Any>) -> Set<Disk>? {
        var matchingDisks = availableDisks
        for (key, value) in matching {
            matchingDisks = Set(matchingDisks.filter({
                if let diskValue = $0.description(key: key as CFString) {
                    return (diskValue as! NSObject) == (value as! NSObject)
                }
                
                // FIXME: This check should be reworked.
                // The issue is that if a value isn't returned, the matching won't work.
                guard let diskValue = $0.ioDescription(key: key) else {
                    if let v = value as? Bool {
                        return v == false
                    } else if let v = value as? String {
                        return v == ""
                    } else {
                        return false
                    }
                }
                
                return (diskValue as! NSObject) == (value as! NSObject)
            }))
        }
        return matchingDisks
    }
    
    public func disks(matching: Dictionary<String, Any>, inSet: Set<Disk>) -> Set<Disk>? {
        var matchingDisks = inSet
        matchLoop: for (key, value) in matching {
            matchingDisks = Set(matchingDisks.filter({
                if let diskValue = $0.description(key: key as CFString) {
                    return (diskValue as! NSObject) == (value as! NSObject)
                } else if let diskValue = $0.ioDescription(key: key) {
                    return (diskValue as! NSObject) == (value as! NSObject)
                }
                return false
            }))
        }
        return matchingDisks
    }
    
    // MARK: -
    // MARK: Approval: Mount
    
    public func allowMountFor(disk: Disk) {
        approvalMatchMount = approvalMatchMount.filter({
            if let matchDisk = $0["Disk"] as? Disk {
                if disk == matchDisk {
                    print("Disks are equal!")
                }
                return disk == matchDisk
            }
            return true
        })
        
        if approvalMatchMount.count == 0 {
            let diskMountApprovalCallbackPointer = unsafeBitCast(diskMountApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskMountApprovalCallbackPointer, nil)
        }
    }
    
    public func allowMountForDisks(matching: Dictionary<String, Any>) {
        approvalMatchMount = approvalMatchMount.filter({
            if let rules = $0["Rules"] as? Dictionary<String, Any> {
                return !NSDictionary(dictionary: rules).isEqual(to: matching)
            }
            return true
        })
        
        if approvalMatchMount.count == 0 {
            let diskMountApprovalCallbackPointer = unsafeBitCast(diskMountApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskMountApprovalCallbackPointer, nil)
        }
    }
    
    public func disallowMountFor(disk: Disk, message: String?) {
        if approvalMatchMount.count == 0 {
            DARegisterDiskMountApprovalCallback(session!, nil, diskMountApprovalCallback, nil)
        }
        
        let matchingDict: [String : Any] = ["Message" : message ?? "", "Disk" : disk]
        if !(approvalMatchMount.contains(where: { NSDictionary(dictionary: $0).isEqual(to: matchingDict) })) {
            approvalMatchMount.append(matchingDict)
        }
    }
    
    public func disallowMountForDisks(matching: Dictionary<String, Any>, message: String?) {
        if approvalMatchMount.count == 0 {
            DARegisterDiskMountApprovalCallback(session!, nil, diskMountApprovalCallback, nil)
        }
        
        let matchingDict: [String : Any] = ["Message" : message ?? "", "Rules" : matching]
        if !(approvalMatchMount.contains(where: { NSDictionary(dictionary: $0).isEqual(to: matchingDict) })) {
            approvalMatchMount.append(matchingDict)
        }
    }

    // MARK: -
    // MARK: Approval: Unmount

    public func allowUnmountFor(disk: Disk) {
        approvalMatchUnmount = approvalMatchUnmount.filter({
            if let matchDisk = $0["Disk"] as? Disk {
                if disk == matchDisk {
                    print("Disks are equal!")
                }
                return disk == matchDisk
            }
            return true
        })
        
        if approvalMatchUnmount.count == 0 {
            let diskUnmountApprovalCallbackPointer = unsafeBitCast(diskUnmountApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskUnmountApprovalCallbackPointer, nil)
        }
    }
    
    public func allowUnmountForDisks(matching: Dictionary<String, Any>) {
        approvalMatchUnmount = approvalMatchUnmount.filter({
            if let rules = $0["Rules"] as? Dictionary<String, Any> {
                return !NSDictionary(dictionary: rules).isEqual(to: matching)
            }
            return true
        })

        if approvalMatchUnmount.count == 0 {
            let diskUnmountApprovalCallbackPointer = unsafeBitCast(diskUnmountApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskUnmountApprovalCallbackPointer, nil)
        }
    }
    
    public func disallowUnmountFor(disk: Disk, message: String?) {
        if approvalMatchUnmount.count == 0 {
            DARegisterDiskUnmountApprovalCallback(session!, nil, diskUnmountApprovalCallback, nil)
        }
        
        let matchingDict: [String : Any] = ["Message" : message ?? "", "Disk" : disk]
        if !approvalMatchUnmount.contains(where: { NSDictionary(dictionary: $0).isEqual(to: matchingDict) }) {
            approvalMatchUnmount.append(matchingDict)
        }
    }
    
    public func disallowUnmountForDisks(matching: Dictionary<String, Any>, message: String?) {
        if approvalMatchUnmount.count == 0 {
            DARegisterDiskUnmountApprovalCallback(session!, nil, diskUnmountApprovalCallback, nil)
        }
        
        let matchingDict: [String : Any] = ["Message" : message ?? "", "Rules" : matching]
        if !approvalMatchUnmount.contains(where: { NSDictionary(dictionary: $0).isEqual(to: matchingDict) }) {
            approvalMatchUnmount.append(matchingDict)
        }
    }
    
    // MARK: -
    // MARK: Approval: Eject
    
    public func allowEjectFor(disk: Disk) {
        approvalMatchEject = approvalMatchEject.filter({
            if let matchDisk = $0["Disk"] as? Disk {
                if disk == matchDisk {
                    print("Disks are equal!")
                }
                return disk == matchDisk
            }
            return true
        })
        
        if approvalMatchEject.count == 0 {
            let diskEjectApprovalCallbackPointer = unsafeBitCast(diskEjectApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskEjectApprovalCallbackPointer, nil)
        }
    }
    
    public func allowEjectForDisks(matching: Dictionary<String, Any>) {
        approvalMatchEject = approvalMatchEject.filter({
            if let rules = $0["Rules"] as? Dictionary<String, Any> {
                return !NSDictionary(dictionary: rules).isEqual(to: matching)
            }
            return true
        })
        
        if approvalMatchEject.count == 0 {
            let diskEjectApprovalCallbackPointer = unsafeBitCast(diskEjectApprovalCallback, to: UnsafeMutableRawPointer.self)
            DAUnregisterCallback(session!, diskEjectApprovalCallbackPointer, nil)
        }
    }
    
    public func disallowEjectFor(disk: Disk, message: String?) {
        if approvalMatchEject.count == 0 {
            DARegisterDiskEjectApprovalCallback(session!, nil, diskEjectApprovalCallback, nil)
        }
        
        let matchingDict: [String : Any] = ["Message" : message ?? "", "Disk" : disk]
        if !(approvalMatchEject.contains(where: { NSDictionary(dictionary: $0).isEqual(to: matchingDict) })) {
            approvalMatchEject.append(matchingDict)
        }
    }
    
    public func disallowEjectForDisks(matching: Dictionary<String, Any>, message: String?) {
        if approvalMatchEject.count == 0 {
            DARegisterDiskEjectApprovalCallback(session!, nil, diskEjectApprovalCallback, nil)
        }
        
        let matchingDict: [String : Any] = ["Message" : message ?? "", "Rules" : matching]
        if !(approvalMatchEject.contains(where: { NSDictionary(dictionary: $0).isEqual(to: matchingDict) })) {
            approvalMatchEject.append(matchingDict)
        }
    }
    
    // MARK: -
    // MARK: Custom Functions
    
    fileprivate func insert(disk: Disk) {
        availableDisks.insert(disk)
        
        if !disk.isMediaWhole {
            guard let parentDiskRef = DADiskCopyWholeDisk(disk.diskRef) else {
                return
            }
            
            if let parentDisk = DiskController.shared.disk(diskRef: parentDiskRef) {
                disk.parent = parentDisk
            } else {
                let parentDisk = Disk.init(diskRef: parentDiskRef)
                disk.parent = parentDisk
                DiskController.shared.insert(disk: parentDisk)
            }
            
            disk.parent!.addChild(disk: disk)
        } else if disk.isCoreStorage {
            guard let devicePath = disk.devicePath else {
                return
            }
            
            if let disks = DiskController.shared.disks(matching: [kDADiskDescriptionDevicePathKey as String : devicePath,
                                                                  kDADiskDescriptionMediaWholeKey as String : true,
                                                                  kDADiskDescriptionMediaLeafKey as String : false]), disks.count != 0 {
                disk.parent = Array(disks).first
                disk.parent!.addChild(disk: disk)
            } else {
                print("Couldn't find the WHOLE disk, this should really be handled")
            }
        }
    }
}

// MARK: Callback: Disks

private let diskAppearedCallback : DADiskAppearedCallback = { (diskRef, context) in
    if let disk = DiskController.shared.disk(diskRef: diskRef) {
        return
    }
    
    let disk = Disk.init(diskRef: diskRef)
    DiskController.shared.insert(disk: disk)
    // FIXME: Print Values Call
    // disk.printValues()
    if let delegateMethod = DiskController.shared.delegate?.diskAppeared {
        delegateMethod(disk)
    }
}

private let diskDisappearedCallback : DADiskDisappearedCallback = { (diskRef, context) in
    guard let disk = DiskController.shared.disk(diskRef: diskRef) else {
        return
    }
    
    availableDisks.remove(disk)
    
    if let delegateMethod = DiskController.shared.delegate?.diskDisappeared {
        delegateMethod(disk)
    }
}

private let diskDescriptionChangedCallback : DADiskDescriptionChangedCallback = { (diskRef, keys, context) in
    guard let disk = DiskController.shared.disk(diskRef: diskRef) else {
        return
    }
    
    disk.updateDescription()
    
    if let delegateMethod = DiskController.shared.delegate?.diskDescriptionChanged {
        delegateMethod(disk, keys)
    }
}

private let diskPeekCallback : DADiskPeekCallback = { (diskRef, context) in
    if let disk = DiskController.shared.disk(diskRef: diskRef) {
        return
    }
    
    let disk = Disk.init(diskRef: diskRef)
    DiskController.shared.insert(disk: disk)
    
    if let delegateMethod = DiskController.shared.delegate?.diskPeeked {
        delegateMethod(disk)
    }
}

// MARK: Callback: Approval

private let diskMountApprovalCallback : DADiskMountApprovalCallback = { (diskRef, context) in
    if approvalMatchMount.count != 0, let disk = DiskController.shared.disk(diskRef: diskRef) {
        return dissenter(disk: disk, matching: approvalMatchMount)
    }
    return nil
}

private let diskUnmountApprovalCallback : DADiskUnmountApprovalCallback = { (diskRef, context) in
    if approvalMatchUnmount.count != 0, let disk = DiskController.shared.disk(diskRef: diskRef) {
        return dissenter(disk: disk, matching: approvalMatchUnmount)
    }
    return nil
}

private let diskEjectApprovalCallback : DADiskEjectApprovalCallback = { (diskRef, context) in
    if approvalMatchEject.count != 0, let disk = DiskController.shared.disk(diskRef: diskRef) {
        return dissenter(disk: disk, matching: approvalMatchEject)
    }
    return nil
}

private func dissenter(disk: Disk, matching: Array<Dictionary<String,Any>>) -> Unmanaged<DADissenter>? {
    matchLoop: for match in matching {
        var matchedDisk = false
        
        if match["Rules"] != nil {
            
            // Extract the rules Dictionary from the current match Dictionary
            guard let rules = match["Rules"] as? Dictionary<String, Any> else {
                continue
            }
        
            // Loop through each rule and try matching it with the current disk. If ANY test fail, continue with then next match Dictionary in the match Array.
            for (key, value) in rules {
                if let diskValue = disk.description(key: key as CFString), (diskValue as! NSObject) == (value as! NSObject) {
                    matchedDisk = true
                } else {
                    matchedDisk = false
                    continue matchLoop
                }
            }
        } else if match["Disk"] != nil {
            if let matchDisk = match["Disk"] as? Disk {
                if disk == matchDisk {
                    matchedDisk = true
                }
            }
        }
        
        // If the current disk matches a disk or all rules for a match dictionary, return a DADissenter with a NotPermitted status
        if matchedDisk {
            return Unmanaged.passRetained(DADissenterCreate(kCFAllocatorDefault, DAReturn(kDAReturnNotPermitted), match["Message"] as! String as CFString))
        }
    }
    return nil
}

// MARK: Callback: Mount / Unmount

let diskMountCallback : DADiskMountCallback = { (diskRef, dissenter, context) in
    guard let disk = DiskController.shared.disk(diskRef: diskRef) else {
        return
    }
    
    if let delegateMethod = DiskController.shared.mountDelegate?.diskMount {
        delegateMethod(disk, dissenter)
    }
    
    print("diskMountCallback")
    if let theDissenter = dissenter {
        let status = DADissenterGetStatus(theDissenter)
        print("Dissenter status: \(status)")
        if let statusString = DADissenterGetStatusString(theDissenter) {
            print("Dissenter status string: \(statusString)")
        }
    } else {
        print("diskMountCallback: No Dissenter")
    }
}

let diskUnmountCallback : DADiskUnmountCallback = { (diskRef, dissenter, context) in
    guard let disk = DiskController.shared.disk(diskRef: diskRef) else {
        return
    }
    
    if let disk = DiskController.shared.disk(diskRef: diskRef) {
        return
    }
    
    if let delegateMethod = DiskController.shared.mountDelegate?.diskUnmount {
        delegateMethod(disk, dissenter)
    }
    
    print("diskUnmountCallback")
    if let theDissenter = dissenter {
        let status = DADissenterGetStatus(theDissenter)
        print("Dissenter status: \(status)")
        if let statusString = DADissenterGetStatusString(theDissenter) {
            print("Dissenter status string: \(statusString)")
        }
    } else {
        print("diskUnmountCallback: No Dissenter")
    }
}

let diskEjectCallback : DADiskEjectCallback = { (diskRef, dissenter, context) in
    guard let disk = DiskController.shared.disk(diskRef: diskRef) else {
        return
    }
    
    if let delegateMethod = DiskController.shared.mountDelegate?.diskEject {
        delegateMethod(disk, dissenter)
    }
    
    print("diskEjectCallback")
    if let theDissenter = dissenter {
        let status = DADissenterGetStatus(theDissenter)
        print("Dissenter status: \(status)")
        if let statusString = DADissenterGetStatusString(theDissenter) {
            print("Dissenter status string: \(statusString)")
        }
    } else {
        print("diskEjectCallback: No Dissenter")
    }
}
