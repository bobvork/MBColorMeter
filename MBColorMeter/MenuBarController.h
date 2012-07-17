//
//  MenuBarController.h
//  MBColorMeter
//
//  Created by Bob Vork on 15-07-12.
//  Copyright (c) 2012 Cue. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	ColorDisplayModeRGB255 = 0,
	ColorDisplayModeRGBFloat,
	ColorDisplayModeHex,

	// Not a display mode, only used internally to toggle:
	ColorDisplayModeNumber		
} ColorDisplayMode;

@interface MenuBarController : NSObject {
	NSStatusItem *statusBarItem;
	int testInt;
	ColorDisplayMode colorDisplayMode;
	NSInteger lastX, lastY;
}

@property (nonatomic, retain) NSString *statusText;
@property (nonatomic, retain) NSTimer *mouseUpdateTimer;
@property (weak) IBOutlet NSView *cView;
@property (weak) IBOutlet NSColorWell *colorWell;
<<<<<<< HEAD
@property (weak) IBOutlet NSTextField *label;
=======
>>>>>>> 60452b15d9138a35d9eb81052c060c9a5feaae61

@property (nonatomic, retain) NSDictionary *titleAttributes;

@end
