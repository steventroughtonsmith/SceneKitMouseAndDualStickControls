//
//  MDSCGameView.h
//
//  Created by Steven Troughton-Smith on 24/12/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>

#import "Player.h"

@interface MDSCGameView : SCNView
{
	Player *player;
	
	CVDisplayLinkRef displayLinkRef;
	
	BOOL gameLoopRunning;

	NSArray *joysticks;
}

@end
