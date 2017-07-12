//
//  DiskArbitrationBridge.h
//  DATester
//
//  Created by Erik Berglund on 2017-06-23.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

#ifndef DiskArbitrationBridge_h
#define DiskArbitrationBridge_h

#import <Foundation/Foundation.h>
#import <DiskArbitration/DiskArbitration.h>

@interface DiskArbitrationBridge : NSObject

+ (void)mountDisk:(DADiskRef)disk atURL:(NSURL *)url options:(DADiskMountOptions)options arguments:(NSArray *)args callback:(DADiskMountCallback)callback;

@end

#endif /* DiskArbitrationBridge_h */
