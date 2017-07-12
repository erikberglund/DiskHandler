//
//  KextManagerBridge.h
//  DATester
//
//  Created by Erik Berglund on 2017-06-23.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

#ifndef KextManagerBridge_h
#define KextManagerBridge_h

#import <Foundation/Foundation.h>

@interface KextManagerBridge : NSObject

+ (nullable NSBundle *)bundleForIdentifier:(nonnull NSString *)identifier;

@end

#endif /* KextManagerBridge_h */
