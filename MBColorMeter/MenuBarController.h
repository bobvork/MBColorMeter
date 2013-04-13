//
//  MenuBarController.h
//  MBColorMeter
//
//  Created by Bob Vork on 15-07-12.
//  Copyright (c) 2012 Cue. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	ColorDisplayModeNone = 0,
	ColorDisplayModeRGB255,
	ColorDisplayModeRGBFloat,
	ColorDisplayModeHex
} ColorDisplayMode;

@interface MenuBarController : NSObject {
	NSStatusItem *statusBarItem;
	int testInt;
	ColorDisplayMode colorDisplayMode;
}

@property (nonatomic, retain) NSTimer *mouseUpdateTimer;
@property (nonatomic, retain) NSDictionary *titleAttributes;

@end
