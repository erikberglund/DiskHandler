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

public class DiskController {
    
    
    
}

let volumeDidAppearCallback : DADiskAppearedCallback = { (diskRef, context) in
    let disk = Disk.init(diskRef: diskRef)
    if availableDisks.contains(disk) {
        availableDisks.insert(disk)
    } else {
        // FIXME: Proper logging
        print("Disk already exist in Set!")
    }
}

let volumeDidDisappearCallback : DADiskDisappearedCallback = { (diskRef, context) in
    let disk = Disk.init(diskRef: diskRef)
    if availableDisks.contains(disk) {
        availableDisks.remove(disk)
    } else {
        // FIXME: Proper logging
        print("Disk doesn't exist in Set!")
    }
}
