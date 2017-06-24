//
//  KextManagerBridging.m
//  DATester
//
//  Created by Erik Berglund on 2017-06-23.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

#import "KextManager.h"

@implementation KextManager

+ (nullable NSBundle *)bundleForIdentifier:(nonnull NSString *)identifier {
    NSURL *url = (__bridge NSURL *)KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, (__bridge CFStringRef)(identifier));
    if (url) {
        return [NSBundle bundleWithURL:url];
    }
    return nil;
}

@end
