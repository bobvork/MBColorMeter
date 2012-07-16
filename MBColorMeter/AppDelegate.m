//
//  AppDelegate.m
//  MBColorMeter
//
//  Created by Bob Vork on 15-07-12.
//  Copyright (c) 2012 Cue. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize mbController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
	mbController = [MenuBarController new];
}

@end
