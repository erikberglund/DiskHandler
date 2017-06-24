//
//  KextManager.h
//  DATester
//
//  Created by Erik Berglund on 2017-06-23.
//  Copyright © 2017 Erik Berglund. All rights reserved.
//

#ifndef KextManager_h
#define KextManager_h

#import <Foundation/Foundation.h>
#import <IOKit/kext/KextManager.h>

@interface KextManager : NSObject

+ (nullable NSBundle *)bundleForIdentifier:(nonnull NSString *)identifier;

@end

#endif /* KextManager_h */
