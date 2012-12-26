//
//  MDSCGameView.m
//
//  Created by Steven Troughton-Smith on 26/12/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//
//  Contains mouse & game logic code from Tom Irving's SceneKraft
//  https://github.com/thermogl/SceneKraft/tree/master/SceneKraft


#import "MDSCGameView.h"
#import "DDHidLib.h"

#define MCP_DEGREES_TO_RADIANS(x) (x  * 180 / M_PI)
#define RUN_IN_FULLSCREEN 1

// Standard units.
CGFloat const kGravityAcceleration = -9.80665;
CGFloat const kJumpHeight = 1.2;
CGFloat const kPlayerMovementSpeed = 1.4;

typedef struct _AISInput
{
	SCNVector3 look;
	
} AISInput;

AISInput controllerInput;

@implementation MDSCGameView

-(void)awakeFromNib
{
	SCNScene *scene = [SCNScene scene];
	self.scene = scene;
	
	[self setWantsLayer:YES];
	
#if RUN_IN_FULLSCREEN
	[self enterFullScreenMode:[NSScreen mainScreen] withOptions:nil];
#endif
	
	player = [Player node];
	player.position = SCNVector3Make(-4, -2.5, 0);
	[player rotateByAmount:CGSizeMake(-M_PI_2, M_PI_2)];
	
	[scene.rootNode addChildNode:player];
	
	[self buildScene];
	[self setupLink];
	
	/* Poll for controller connect / disconnect */
	
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(startWatchingJoysticks) userInfo:nil repeats:YES];
	
	NSTrackingArea *trackingArea =	[[NSTrackingArea alloc] initWithRect:self.bounds
																options:(NSTrackingActiveInKeyWindow | NSTrackingMouseMoved) owner:self userInfo:nil];
	[self addTrackingArea:trackingArea];
	
	[self performSelector:@selector(centerAndCaptureMouse) withObject:nil afterDelay:0.5];
	
}

-(void)buildScene
{
	SCNPlane *floor = [SCNPlane planeWithWidth:16 height:16];
	SCNNode *floorNode = [SCNNode nodeWithGeometry:floor];
	SCNMaterial *floorMaterial = [SCNMaterial material];
	floorMaterial.diffuse.contents = [NSColor lightGrayColor];
	floorNode.geometry.materials = @[floorMaterial];
	
	floorNode.rotation = SCNVector4Make(0, 0, 0, M_PI_2);
	
	[self.scene.rootNode addChildNode:floorNode];
	
	SCNBox *sky = [SCNBox boxWithWidth:1 height:1 length:1 chamferRadius:0.1];
	
	SCNNode *earthNode = [SCNNode nodeWithGeometry:sky];
	
	SCNMaterial *earthMaterial = [SCNMaterial material];
	earthMaterial.diffuse.contents = [NSImage imageNamed:@"earth-diffuse.jpg"];
	earthMaterial.normal.contents = [NSImage imageNamed:@"earth-normal.png"];
	earthMaterial.specular.contents = [NSImage imageNamed:@"earth-specular.jpg"];
	earthMaterial.reflective.contents = [NSImage imageNamed:@"earth-reflective.jpg"];
	earthMaterial.emission.contents = [NSColor colorWithCalibratedWhite:0.1 alpha:1.0];
	earthNode.geometry.materials = @[earthMaterial];
	
	earthNode.position = SCNVector3Make(0, 0, .5);
	earthNode.rotation = SCNVector4Make(1, 0, 0, M_PI_2);
	
	[self.scene.rootNode addChildNode:earthNode];
	
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
	animation.values = [NSArray arrayWithObjects:
						[NSValue valueWithCATransform3D:CATransform3DRotate(earthNode.transform, 0 * M_PI / 2, 0.f, 1.0f, 0.f)],
						[NSValue valueWithCATransform3D:CATransform3DRotate(earthNode.transform, 1 * M_PI / 2, 0.f, 1.0f, 0.f)],
						[NSValue valueWithCATransform3D:CATransform3DRotate(earthNode.transform, 2 * M_PI / 2, 0.f, 1.0f, 0.f)],
						[NSValue valueWithCATransform3D:CATransform3DRotate(earthNode.transform, 3 * M_PI / 2, 0.f, 1.0f, 0.f)],
						[NSValue valueWithCATransform3D:CATransform3DRotate(earthNode.transform, 4 * M_PI / 2, 0.f, 1.0f, 0.f)],
						nil];
	animation.duration = 30.f;
	animation.repeatCount = HUGE_VALF;
	
	[earthNode addAnimation:animation forKey:@"transform"];
}

#pragma mark - GameLoop

-(void)setupLink
{
	if (CVDisplayLinkCreateWithActiveCGDisplays(&displayLinkRef) == kCVReturnSuccess)
	{
		CVDisplayLinkSetOutputCallback(displayLinkRef, DisplayLinkCallback, (__bridge void *)(self));
		[self setRunning:YES];
	}
}

-(void)setRunning:(BOOL)running
{
	if (gameLoopRunning != running)
	{
		gameLoopRunning = running;
		
		if (gameLoopRunning){
			CVDisplayLinkStart(displayLinkRef);
		}
		else
		{
			CVDisplayLinkStop(displayLinkRef);
		}
	}
}


- (CVReturn)gameLoopAtTime:(CVTimeStamp)time
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		CGFloat refreshPeriod = CVDisplayLinkGetActualOutputVideoRefreshPeriod(displayLinkRef);
		
		[player setAcceleration:SCNVector3Make(0, 0, kGravityAcceleration)];
		[player updatePositionWithRefreshPeriod:refreshPeriod];
		[player checkCollisionWithNodes:self.scene.rootNode.childNodes];
		
		SCNVector3 playerNodePosition = player.position;
		
		if (playerNodePosition.z < 1) playerNodePosition.z = 1;
		[player setPosition:playerNodePosition];
		
		/* for Joypad Analog Sticks */
		[player rotateByAmount:CGSizeMake(MCP_DEGREES_TO_RADIANS(-controllerInput.look.x / 10000), MCP_DEGREES_TO_RADIANS(-controllerInput.look.y / 10000))];
		
	});
	
	return kCVReturnSuccess;
}

static CVReturn DisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime,
									CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext){
	return [(__bridge MDSCGameView *)displayLinkContext gameLoopAtTime:*inOutputTime];
}


#pragma mark - Input

-(void)centerAndCaptureMouse
{
	CGRect r = [self.window convertRectToScreen:CGRectMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds), 0, 0)];
	CGPoint mouse = r.origin;
	
	mouse.y = [self.window.screen frame].size.height-mouse.y;
	
	CGWarpMouseCursorPosition(mouse);
    CGAssociateMouseAndMouseCursorPosition(NO);
	
	[NSCursor hide];
}

-(void)mouseDown:(NSEvent *)theEvent
{
	[self centerAndCaptureMouse];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	[player rotateByAmount:CGSizeMake(MCP_DEGREES_TO_RADIANS(-theEvent.deltaX / 10000), MCP_DEGREES_TO_RADIANS(-theEvent.deltaY / 10000))];
}


-(void)keyDown:(NSEvent *)theEvent
{
	CGFloat delta = 4;
	
	SCNVector4 movement = player.movement;
	if (theEvent.keyCode == 126 || theEvent.keyCode == 13) movement.x = delta;
	if (theEvent.keyCode == 123 || theEvent.keyCode == 0) movement.y = delta;
	if (theEvent.keyCode == 125 || theEvent.keyCode == 1) movement.z = delta;
	if (theEvent.keyCode == 124 || theEvent.keyCode == 2) movement.w = delta;
	[player setMovement:movement];
	
	
	if (theEvent.keyCode == 49){
		
		// v^2 = u^2 + 2as
		// 0 = u^2 + 2as (v = 0 at top of jump)
		// -u^2 = 2as;
		// u^2 = -2as;
		// u = sqrt(-2 * kGravityAcceleration * kJumpHeight)
		
		[self jump];
	}
}

-(void)keyUp:(NSEvent *)theEvent
{
	SCNVector4 movement = player.movement;
	if (theEvent.keyCode == 126 || theEvent.keyCode == 13) movement.x = 0;
	if (theEvent.keyCode == 123 || theEvent.keyCode == 0) movement.y = 0;
	if (theEvent.keyCode == 125 || theEvent.keyCode == 1) movement.z = 0;
	if (theEvent.keyCode == 124 || theEvent.keyCode == 2) movement.w = 0;
	[player setMovement:movement];
}

-(void)jump
{
	SCNVector3 playerNodeVelocity = player.velocity;
	playerNodeVelocity.z = sqrtf(-2 * kGravityAcceleration * kJumpHeight);
	[player setVelocity:playerNodeVelocity];
}


#pragma mark - Joystick input

/*
 
 Xbox Controller Mapping
 
 */

#define ABUTTON  0
#define BBUTTON  1
#define XBUTTON  2
#define YBUTTON  3


- (void)startWatchingJoysticks
{
	joysticks = [DDHidJoystick allJoysticks] ;
	
	if ([joysticks count]) // assume only one joystick connected
	{
		[[joysticks lastObject] setDelegate:self];
		[[joysticks lastObject] startListening];
	}
}
- (void)ddhidJoystick:(DDHidJoystick *)joystick buttonDown:(unsigned)buttonNumber
{
	if (buttonNumber == ABUTTON)
	{
		[self jump];
	}
}

int lastStickX = 0;
int lastStickY = 0;


- (void) ddhidJoystick: (DDHidJoystick *) joystick
				 stick: (unsigned) stick
			 otherAxis: (unsigned) otherAxis
		  valueChanged: (int) value;
{
	value/=SHRT_MAX/4;
	
	if (stick == 1)
	{
		if (otherAxis == 0)
			
			controllerInput.look.x = value;
		else
			controllerInput.look.y = value;
	}
}

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
				 stick: (unsigned) stick
			  xChanged: (int) value;
{
	value/=SHRT_MAX;
	
	lastStickX = value;
	
	if (abs(lastStickY) > abs(lastStickX))
		return;
	
	SCNVector4 movement = player.movement;
	CGFloat delta = 4.;
	
	
	if (value == 0)
	{
		// left & right = NO
		movement.y = 0;
		movement.w = 0;
		
	}
	else
	{
		movement.x = 0;
		movement.z = 0;
		
		if (value > 0 )
		{
			// right = YES
			movement.w = delta;
			
		}
		else if (value < 0 )
		{
			// left = YES
			movement.y = delta;
		}
	}
	
	[player setMovement:movement];
	
}

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
				 stick: (unsigned) stick
			  yChanged: (int) value;
{
	value/=SHRT_MAX;
	
	SCNVector4 movement = player.movement;
	CGFloat delta = 4.;

	lastStickY = value;
	
	if (abs(lastStickY) < abs(lastStickX))
		return;
	
	if (value == 0)
	{
		// forward & backward = NO
		
		movement.x = 0;
		movement.z = 0;
	}
	else
	{
		// left & right = NO
		
		movement.y = 0;
		movement.w = 0;
		
		if (value > 0 )
		{
			// backward = YES
			movement.z = delta;
			
		}
		else if (value < 0 )
		{
			//	forward = YES
			movement.x = delta;
			
		}
	}
	
	[player setMovement:movement];
	
}
@end
