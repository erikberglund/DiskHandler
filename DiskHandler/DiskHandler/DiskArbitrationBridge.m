//
//  DiskArbitrationBridge.m
//  DATester
//
//  Created by Erik Berglund on 2017-06-23.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

#import "DiskArbitrationBridge.h"
#import <CoreServices/CoreServices.h>

@implementation DiskArbitrationBridge

+ (void)mountDisk:(DADiskRef)disk atURL:(NSURL *)url options:(DADiskMountOptions)options arguments:(NSArray *)args callback:(DADiskMountCallback)callback {
    
    // ensure arg list is NULL terminated
    CFStringRef *argv = calloc(args.count + 1, sizeof(CFStringRef));
    CFArrayGetValues((__bridge CFArrayRef)args, CFRangeMake(0, (CFIndex)args.count), (const void **)argv);
    
    // (__bridge CFURLRef)url
    
    DADiskMountWithArguments(disk, nil, options, callback, (__bridge void *)(self), (CFStringRef *)argv);
    
    free(argv);
}

@end
