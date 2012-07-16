//
//  MenuBarController.m
//  MBColorMeter
//
//  Created by Bob Vork on 15-07-12.
//  Copyright (c) 2012 Cue. All rights reserved.
//

#import "MenuBarController.h"

@implementation MenuBarController
@synthesize cView;
@synthesize colorWell;

@synthesize statusText, mouseUpdateTimer, titleAttributes;

- (id)init {
    self = [super init];
    if (self) {
        // Install status item into the menu bar
        statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		statusBarItem.title = @"lala";
		statusBarItem.target = self;
		statusBarItem.action = @selector(statusBarItemClicked:);
		
		NSFont *font = [NSFont fontWithName:@"Inconsolata" size:14.0];
		self.titleAttributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
		
		mouseUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateMouseInfo) userInfo:nil repeats:YES];
		
		colorDisplayMode = ColorDisplayModeHex;
		lastX = lastY = -1;
    }
    return self;
}

- (void)statusBarItemClicked:(id)sender {
	// Toggle Color display mode:
	colorDisplayMode = ((colorDisplayMode+1) % ColorDisplayModeNumber);
}

- (void)updateMouseInfo {
	NSPoint mPoint = [NSEvent mouseLocation];
	
	NSRect screenFrame = [[NSScreen mainScreen] frame];
	NSInteger x = floor(mPoint.x);
	NSInteger y = floor(screenFrame.size.height - mPoint.y);
	
	if(lastX == x && lastY == y) {
		return;
	}
	
	lastX = x;
	lastY = y;
	
	
	CGImageRef pixelImageRef = CGDisplayCreateImageForRect(CGMainDisplayID(), CGRectMake(x,y, 1, 1));
	
	unsigned char pixel[4] = {0};
	CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, 
												 CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB),
												 kCGImageAlphaPremultipliedLast);

	CGContextDrawImage(context, CGRectMake(0, 0, 1, 1),pixelImageRef); 
	
	CGContextRelease(context);

//	NSLog(@"R: %d, G: %d, B: %d", pixel[0], pixel[1], pixel[2]);
	
	CGFloat red		= pixel[0]/255.0;
	CGFloat green	= pixel[1]/255.0;
	CGFloat blue	= pixel[2]/255.0;
	
	NSString *titleString = nil;
	
	if(colorDisplayMode == ColorDisplayModeHex) {
		titleString = [NSString stringWithFormat:@"#%02X%02X%02X", pixel[0], pixel[1], pixel[2]];
	} else if(colorDisplayMode == ColorDisplayModeRGB255) {
		titleString = [NSString stringWithFormat:@"RGB(%d, %d, %d)", pixel[0], pixel[1], pixel[2]];
	} else if(colorDisplayMode == ColorDisplayModeRGBFloat) {
		titleString = [NSString stringWithFormat:@"RGB(%0.2f, %0.2f, %0.2f)", pixel[0]/255,0, pixel[1]/255.0, pixel[2]/255.0];
	}
	
	statusBarItem.attributedTitle = [[NSAttributedString alloc] initWithString:titleString attributes:self.titleAttributes];
	
	NSColor *color = [NSColor colorWithDeviceRed:red green:green blue:blue alpha:1.0];
	
	self.colorWell.color = color;
}

@end
