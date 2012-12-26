//
//  ParticleNode.m
//  SceneKraft
//
//  Created by Tom Irving on 10/09/2012.
//  Copyright (c) 2012 Tom Irving. All rights reserved.
//

#import "Entity.h"

@implementation Entity
@synthesize velocity;
@synthesize acceleration;
@synthesize mass;
@synthesize touchingGround;

- (void)updatePositionWithRefreshPeriod:(CGFloat)refreshPeriod {
	
	velocity.x += acceleration.x * refreshPeriod;
	velocity.y += acceleration.y * refreshPeriod;
	velocity.z += acceleration.z * refreshPeriod;
	
	SCNVector3 position = self.position;
	position.x += velocity.x * refreshPeriod;
	position.y += velocity.y * refreshPeriod;
	position.z += velocity.z * refreshPeriod;
	[self setPosition:position];
}

- (void)checkCollisionWithNodes:(NSArray *)nodes {
	// TODO: Make this better.
	
	touchingGround = NO;
	__block SCNVector3 selfPosition = self.position;
	
	[nodes enumerateObjectsUsingBlock:^(SCNNode * node, NSUInteger idx, BOOL *stop)
	 {
		 if (self != node && [node.geometry isKindOfClass:[SCNBox class]])
		 {
			 if ([self collidesWithTopOfNode:node]){
				 selfPosition.z = node.position.z + ((SCNBox *)node.geometry).height;
				 velocity.z = 0;
				 touchingGround = YES;
				 *stop = YES;
			 }
		 }
	 }];
	
	
	[self setPosition:selfPosition];
}

- (BOOL)collidesWithTopOfNode:(SCNNode *)node {
	
	SCNVector3 selfPosition = self.position;
	SCNVector3 nodePosition = node.position;
	SCNBox * boxGeometry = (SCNBox *)node.geometry;
	
	if (nodePosition.x <= (selfPosition.x + boxGeometry.width / 2) && (nodePosition.x + boxGeometry.width) > (selfPosition.x + boxGeometry.width / 2))
	{
		if (nodePosition.y <= (selfPosition.y + boxGeometry.length / 2) && (nodePosition.y + boxGeometry.length) > (selfPosition.y + boxGeometry.length / 2))
		{
			if (nodePosition.z <= selfPosition.z && (nodePosition.z + boxGeometry.height) > selfPosition.z)
			{
				return YES;
			}
		}
	}
	
	return NO;
}

@end