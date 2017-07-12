//
//  SplitViewController.swift
//  DiskHandlerExample
//
//  Created by Erik Berglund on 2017-06-26.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

import Cocoa
import DiskHandler

class SplitViewController: NSSplitViewController {

    @IBOutlet weak var splitViewItemLeft: NSSplitViewItem!
    @IBOutlet weak var splitViewItemRight: NSSplitViewItem!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        /*
        if let disks = DiskController.shared.disks(matching: [kDADiskDescriptionDeviceModelKey as String: "Disk Image"]),
            let disk = disks.first {
            DiskController.shared.disallowUnmountFor(disk: disk, message: "NOPE!")
        }
 */
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.splitView.delegate = self
        
        if  let diskListViewController = splitViewItemLeft.viewController as? DiskListViewController,
            let diskInfoViewController = splitViewItemRight.viewController as? DiskInfoViewController {
            diskListViewController.delegate = diskInfoViewController
        }
    }
}

// MARK: -
// MARK: DiskListViewController
// MARK: -

public protocol DiskListViewDelegate: class {
    func selectionDidChange(selectedDisk: Disk?)
}

class DiskListViewController : NSViewController, DiskControllerDelegate, DiskControllerMountDelegate {
    
    @IBOutlet weak var outlineView: NSOutlineView!
    public weak var delegate: DiskListViewDelegate?
    
    var diskMatchWhole: [String : Any] = [kDADiskDescriptionMediaWholeKey as String : true, "CoreStorage" : false]
    var disks = Array<Disk>()
    
    override func viewDidLoad() {
        
        DiskController.shared.delegate = self
        DiskController.shared.mountDelegate = self
        
        super.viewDidLoad()
        
        updateDisks()
        
        self.outlineView.delegate = self
        self.outlineView.dataSource = self
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func updateDisks() {
        if let disks = DiskController.shared.disks(matching: diskMatchWhole) {
            self.disks = Array(disks)
        }
        DispatchQueue.main.async(execute: {
            let currentSelection = self.outlineView.selectedRowIndexes
            self.outlineView.reloadData()
            self.outlineView.selectRowIndexes(currentSelection, byExtendingSelection: false)
        })
    }
    
    func diskAppeared(disk: Disk) {
        updateDisks()
    }
    
    func diskDescriptionChanged(disk: Disk, keys: CFArray) {
        updateDisks()
    }
    
    func diskDisappeared(disk: Disk) {
        updateDisks()
    }
    
    func diskPeeked(disk: Disk) {
        updateDisks()
    }
    
    func diskEject(disk: Disk, dissenter: DADissenter?) {
        updateDisks()
    }
    
    func diskUnmount(disk: Disk, dissenter: DADissenter?) {
        updateDisks()
    }
    
    func diskMount(disk: Disk, dissenter: DADissenter?) {
        var isDir: ObjCBool = false
        if let mountPath = disk.volumePath(), FileManager.default.fileExists(atPath: mountPath.path, isDirectory: &isDir), isDir.boolValue {
            NSWorkspace.shared().openFile(mountPath.path)
        }
        
        updateDisks()
    }
}

extension DiskListViewController : NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return self.disks.count
        } else if let disk = item as? Disk {
            if let children = DiskController.shared.disks(matching: [kDADiskDescriptionVolumeMountableKey as String : true], inSet: disk.children), 0 < Array(children).count {
                return Array(children).count
            } else if disk.isDiskImage(), let diskImage = disk.diskImage(), !diskImage.isPartitioned(), outlineView.level(forItem: item) == 0 {
                return 1
            }
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let disk = item as? Disk {
            if disk.isDiskImage(), let diskImage = disk.diskImage(), !diskImage.isPartitioned(), outlineView.level(forItem: item) == 0 {
                return true
            } else {
                return !disk.isMediaLeaf()
            }
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return self.disks[index]
        } else {
            if let disk = item as? Disk {
                if let children = DiskController.shared.disks(matching: [kDADiskDescriptionVolumeMountableKey as String : true], inSet: disk.children), 0 < Array(children).count {
                    return Array(children)[index]
                } else if disk.isDiskImage(), let diskImage = disk.diskImage(), !diskImage.isPartitioned(), outlineView.level(forItem: item) == 0 {
                    return disk
                }
            }
        }
        
        return self
    }
}

extension DiskListViewController : NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor viewForTableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let disk = item as? Disk {
            let identifier = "DataCell"
            let view = outlineView.make(withIdentifier: identifier, owner: self) as! NSTableCellView
            
            // Set the icon
            if disk.isMediaWhole() && disk.isDiskImage(), let imageView = view.imageView, outlineView.level(forItem: item) == 0 {
                if let diskImage = disk.diskImage(), let diskImageIcon = diskImage.icon() {
                    imageView.image = diskImageIcon
                }
            } else if let diskIcon = disk.mediaIcon(), let imageView = view.imageView {
                imageView.image = diskIcon
            }
            
            // Set the title
            if disk.isMediaWhole() && !disk.isMediaLeaf() {
                if disk.isDiskImage(), let diskImageName = disk.diskImageURL()?.lastPathComponent {
                    view.textField?.stringValue = diskImageName
                } else {
                    if let deviceName = disk.deviceModel() {
                        view.textField?.stringValue = deviceName
                    }
                }
            } else {
                if let volumeName = disk.volumeName() {
                    view.textField?.stringValue = volumeName
                }
                
                if let imageView = view.imageView {
                    if disk.isVolumeMounted() {
                        imageView.alphaValue = 1.0
                        view.textField?.textColor = NSColor.labelColor
                    } else {
                        imageView.alphaValue = 0.5
                        view.textField?.textColor = NSColor.secondaryLabelColor
                    }
                }
            }
            return view
        }
        return nil
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        
        guard let delegate = delegate else { return }
        
        guard let outlineView = notification.object as? NSOutlineView else {
            return
        }
        
        let selectedRow = outlineView.selectedRow
        
        guard let disk = outlineView.item(atRow: selectedRow) as? Disk , selectedRow >= 0 else {
            return
        }
        
        delegate.selectionDidChange(selectedDisk: disk)
    }
    
}

// MARK: -
// MARK: DiskInfoViewController
// MARK: -

class DiskInfoViewController: NSViewController, DiskListViewDelegate {
    
    @IBOutlet weak var diskImageView: NSImageView!
    @IBOutlet weak var diskLabel: NSTextField!
    @IBOutlet weak var diskDescription: NSTextField!
    @IBOutlet weak var horizontalLine: NSBox!
    @IBOutlet weak var diskTextScrollView: NSScrollView!
    @IBOutlet var diskTextView: NSTextView!
    @IBOutlet weak var buttonMount: NSButton!
    @IBOutlet weak var buttonEject: NSButton!
    
    weak var selectedDisk: Disk?
    
    @IBAction func buttonMount(_ sender: Any) {
        guard let disk = selectedDisk else {
            return
        }
        
        if disk.isVolumeMounted() {
            disk.unmount(options: nil)
        } else {
            disk.mount()
        }
    }
    
    @IBAction func buttonEject(_ sender: Any) {
        guard let disk = selectedDisk else {
            return
        }
        
        if disk.isMediaEjectable() {
            disk.eject()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.info(show: false)
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    public func info(show: Bool) {
        self.diskImageView.isHidden = !show
        self.diskLabel.isHidden = !show
        self.diskDescription.isHidden = !show
        self.horizontalLine.isHidden = !show
        self.diskTextScrollView.isHidden = !show
        
        if show, let disk = selectedDisk {
            
            if disk.isVolumeMountable(), !disk.isVolumeBooted() {
                self.buttonMount.isHidden = false
                if !disk.isVolumeMounted() {
                    self.buttonMount.title = "Mount"
                } else {
                    self.buttonMount.title = "Unmount"
                }
            } else {
                self.buttonMount.isHidden = true
            }
            
            if disk.isMediaEjectable() {
                self.buttonEject.isHidden = false
            } else {
                self.buttonEject.isHidden = true
            }
        } else {
            self.buttonMount.isHidden = true
            self.buttonEject.isHidden = true
        }
    }
    
    func selectionDidChange(selectedDisk: Disk?) {
        
        guard let disk = selectedDisk else {
            self.selectedDisk = nil
            self.info(show: false)
            return
        }
        
        self.selectedDisk = disk
        
        if disk.isMediaWhole() && disk.isDiskImage() {
            if let diskImage = disk.diskImage(), let diskImageIcon = diskImage.icon() {
                self.diskImageView.image = diskImageIcon
            }
        } else if let diskIcon = disk.mediaIcon() {
            self.diskImageView.image = diskIcon
        }
        
        if disk.isMediaWhole() && !disk.isMediaLeaf() {
            if disk.isDiskImage(), let diskImageName = disk.diskImageURL()?.lastPathComponent {
                self.diskLabel.stringValue = diskImageName
            } else {
                if let deviceName = disk.deviceModel() {
                    self.diskLabel.stringValue = deviceName
                }
            }
        } else {
            if let volumeName = disk.volumeName() {
                self.diskLabel.stringValue = volumeName
            }
        }
        
        if let diskSize = disk.mediaSize() {
            self.diskDescription.stringValue = ByteCountFormatter.string(fromByteCount: diskSize.int64Value, countStyle: .file)
        }
        
        if let diskInfoString = self.stringValues(disk: disk) {
            self.diskTextView.string = diskInfoString
        }
        
        self.info(show: true)
    }
    
    public func stringValues(disk: Disk) -> String? {
        
        var string = ""
        
        // Appearance Time
        string = string + "DAAppearanceTime: \(String(describing: disk.appearanceTime() ?? Date.init(timeIntervalSince1970: 0)))\n"
        
        // Bus
        string = string + "\(kDADiskDescriptionBusNameKey): \(String(describing: disk.busName() ?? ""))\n"
        string = string + "\(kDADiskDescriptionBusPathKey): \(String(describing: disk.busPath() ?? ""))\n"
        
        // Device
        string = string + "\(kDADiskDescriptionDeviceGUIDKey): \(String(describing: disk.deviceGUID()))\n"
        string = string + "\(kDADiskDescriptionDeviceInternalKey): \(String(describing: disk.isDeviceInternal()))\n"
        string = string + "\(kDADiskDescriptionDeviceModelKey): \(String(describing: disk.deviceModel() ?? ""))\n"
        string = string + "\(kDADiskDescriptionDevicePathKey): \(String(describing: disk.devicePath() ?? ""))\n"
        string = string + "\(kDADiskDescriptionDeviceProtocolKey): \(String(describing: disk.deviceProtocol() ?? ""))\n"
        string = string + "\(kDADiskDescriptionDeviceRevisionKey): \(String(describing: disk.deviceRevision() ?? ""))\n"
        string = string + "\(kDADiskDescriptionDeviceUnitKey): \(String(describing: disk.deviceUnit() ?? -1))\n"
        string = string + "\(kDADiskDescriptionDeviceVendorKey): \(String(describing: disk.deviceVendor() ?? ""))\n"
        
        // Media
        string = string + "\(kDADiskDescriptionMediaBlockSizeKey): \(String(describing: disk.mediaBlockSize() ?? -1))\n"
        string = string + "\(kDADiskDescriptionMediaBSDMajorKey): \(String(describing: disk.mediaBSDMajor() ?? -1))\n"
        string = string + "\(kDADiskDescriptionMediaBSDMinorKey): \(String(describing: disk.mediaBSDMinor() ?? -1))\n"
        string = string + "\(kDADiskDescriptionMediaBSDNameKey): \(String(describing: disk.mediaBSDName() ?? ""))\n"
        string = string + "\(kDADiskDescriptionMediaBSDUnitKey): \(String(describing: disk.mediaBSDUnit() ?? -1))\n"
        string = string + "\(kDADiskDescriptionMediaContentKey): \(String(describing: disk.mediaContent() ?? ""))\n"
        string = string + "\(kDADiskDescriptionMediaEjectableKey): \(String(describing: disk.isMediaEjectable()))\n"
        string = string + "\(kDADiskDescriptionMediaKindKey): \(String(describing: disk.mediaKind() ?? ""))\n"
        string = string + "\(kDADiskDescriptionMediaLeafKey): \(String(describing: disk.isMediaLeaf()))\n"
        string = string + "\(kDADiskDescriptionMediaNameKey): \(String(describing: disk.mediaName() ?? ""))\n"
        string = string + "\(kDADiskDescriptionMediaPathKey): \(String(describing: disk.mediaPath() ?? ""))\n"
        string = string + "\(kDADiskDescriptionMediaRemovableKey): \(String(describing: disk.isMediaRemovable()))\n"
        string = string + "\(kDADiskDescriptionMediaSizeKey): \(String(describing: disk.mediaSize() ?? -1))\n"
        string = string + "\(kDADiskDescriptionMediaTypeKey): \(String(describing: disk.mediaType() ?? ""))\n"
        string = string + "\(kDADiskDescriptionMediaUUIDKey): \(String(describing: disk.mediaUUID()?.uuidString ?? ""))\n"
        string = string + "\(kDADiskDescriptionMediaWholeKey): \(String(describing: disk.isMediaWhole()))\n"
        string = string + "\(kDADiskDescriptionMediaWritableKey): \(String(describing: disk.isMediaWritable()))\n"
        
        // Volume
        string = string + "\(kDADiskDescriptionVolumeKindKey): \(String(describing: disk.volumeKind() ?? ""))\n"
        string = string + "\(kDADiskDescriptionVolumeMountableKey): \(String(describing: disk.isVolumeMountable()))\n"
        string = string + "\(kDADiskDescriptionVolumeNameKey): \(String(describing: disk.volumeName() ?? ""))\n"
        string = string + "\(kDADiskDescriptionVolumeNetworkKey): \(String(describing: disk.isVolumeNetwork()))\n"
        string = string + "\(kDADiskDescriptionVolumePathKey): \(String(describing: disk.volumePath()?.absoluteString ?? ""))\n"
        string = string + "\(kDADiskDescriptionVolumeTypeKey): \(String(describing: disk.volumeType() ?? ""))\n"
        string = string + "\(kDADiskDescriptionVolumeUUIDKey): \(String(describing: disk.volumeUUID()?.uuidString ?? ""))\n"
        string = string + "Volume Mounted: \(String(describing: disk.isVolumeMounted()))\n"
        string = string + "Volume Booted: \(String(describing: disk.isVolumeBooted()))\n"
        
        // CoreStorage
        string = string + "\("CoreStorage"): \(String(describing: disk.isCoreStorage()))\n"
        if disk.isCoreStorage() {
            string = string + "\("CoreStorage Encrypted"): \(String(describing: disk.isCoreStorageEncrypted()))\n"
            string = string + "\("CoreStorage CPDK"): \(String(describing: disk.isCoreStorageCPDK()))\n"
            string = string + "\("CoreStorage LVF UUID"): \(String(describing: disk.coreStorageLVFUUID()?.uuidString ?? ""))\n"
            string = string + "\("CoreStorage LVG UUID"): \(String(describing: disk.coreStorageLVGUUID()?.uuidString ?? ""))\n"
        }
        
        // Disk Image
        if disk.isDiskImage(), let diskImage = disk.diskImage() {
            string = string + "DiskImage Path: \(String(describing: disk.diskImageURL()?.absoluteString ?? ""))\n"
            
            string = string + "DiskImage Appendable: \(String(describing: diskImage.isAppendable()))\n"
            string = string + "DiskImage Burnable: \(String(describing: diskImage.isBurnable()))\n"
            string = string + "DiskImage Block Size: \(String(describing: diskImage.blockSize() ?? -1))\n"
            string = string + "DiskImage Checksummed: \(String(describing: diskImage.isChecksummed()))\n"
            string = string + "DiskImage Checksum Type: \(String(describing: diskImage.checksumType() ?? ""))\n"
            string = string + "DiskImage Checksum Value: \(String(describing: diskImage.checksumValue() ?? ""))\n"
            string = string + "DiskImage Class Name: \(String(describing: diskImage.className() ?? ""))\n"
            string = string + "DiskImage Compressed: \(String(describing: diskImage.isCompressed()))\n"
            string = string + "DiskImage Compressed Bytes: \(String(describing: diskImage.compressedBytes() ?? -1))\n"
            string = string + "DiskImage Compressed Ratio: \(String(describing: diskImage.compressedRatio() ?? -1.0))\n"
            string = string + "DiskImage CUDIFEncoding-bytes-in-use: \(String(describing: diskImage.cudifEncodingBytesInUse() ?? -1))\n"
            string = string + "DiskImage CUDIFEncoding-bytes-total: \(String(describing: diskImage.cudifEncodingBytesTotal() ?? -1))\n"
            string = string + "DiskImage CUDIFEncoding-bytes-wasted: \(String(describing: diskImage.cudifEncodingBytesWasted() ?? -1))\n"
            string = string + "DiskImage Encrypted: \(String(describing: diskImage.isEncrypted()))\n"
            string = string + "DiskImage Format: \(String(describing: diskImage.format() ?? ""))\n"
            string = string + "DiskImage Format Description: \(String(describing: diskImage.formatDescription() ?? ""))\n"
            string = string + "DiskImage Kernel Compatible: \(String(describing: diskImage.isKernelCompatible()))\n"
            string = string + "DiskImage Partition Scheme: \(String(describing: diskImage.partitionScheme() ?? ""))\n"
            string = string + "DiskImage Partitioned: \(String(describing: diskImage.isPartitioned()))\n"
            if let partitions = diskImage.partitions() {
                for (index, partition) in partitions.enumerated() {
                    string = string + "DiskImage Partition \(index) - Filesystems: \(String(describing: partition.fileSystems ?? [String : Any]()))\n"
                    string = string + "DiskImage Partition \(index) - Hint: \(String(describing: partition.hint ?? ""))\n"
                    string = string + "DiskImage Partition \(index) - HintUUID: \(String(describing: partition.hintUUID?.uuidString ?? ""))\n"
                    string = string + "DiskImage Partition \(index) - Length: \(String(describing: partition.length ?? -1))\n"
                    string = string + "DiskImage Partition \(index) - Name: \(String(describing: partition.name ?? ""))\n"
                    string = string + "DiskImage Partition \(index) - Number: \(String(describing: partition.number ?? -1))\n"
                    string = string + "DiskImage Partition \(index) - Start: \(String(describing: partition.start ?? -1))\n"
                    string = string + "DiskImage Partition \(index) - Synthesized: \(String(describing: partition.synthesized))\n"
                    string = string + "DiskImage Partition \(index) - UUID: \(String(describing: partition.partitionUUID?.uuidString ?? ""))\n"
                }
            }
            string = string + "DiskImage Segments: \(String(describing: diskImage.segments() ?? []))\n"
            string = string + "DiskImage Sector Count: \(String(describing: diskImage.sectorCount() ?? -1))\n"
            string = string + "DiskImage Software License Agreement: \(String(describing: diskImage.hasSoftwareLicenseAgreement()))\n"
            string = string + "DiskImage Software License Agreement Text: \(String(describing: diskImage.softwareLicenseAgreementText() ?? ""))\n"
            string = string + "DiskImage Total Bytes: \(String(describing: diskImage.totalBytes() ?? -1))\n"
            string = string + "DiskImage Total Empty Bytes: \(String(describing: diskImage.totalEmptyBytes() ?? -1))\n"
            string = string + "DiskImage Total Non Empty Bytes: \(String(describing: diskImage.totalNonEmptyBytes() ?? -1))\n"
            string = string + "DiskImage UDIF Ordered Chunks: \(String(describing: diskImage.hasUDIFOrderedChunks()))\n"
        }
        
        return string
    }
}


