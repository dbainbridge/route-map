//
//  RMCoreAnimationRenderer.m
//
// Copyright (c) 2008, Route-Me Contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "RMCoreAnimationRenderer.h"
#import <QuartzCore/QuartzCore.h>
#import "RMTile.h"
#import "RMTileLoader.h"
#import "RMPixel.h"
#import "RMTileImage.h"
#import "RMTileImageSet.h"
#import "RMMapView.h"

@implementation RMCoreAnimationRenderer


- (id) initWithMapView: (RMMapView *)aMapView
{
	if (![super initWithMapView:aMapView])
		return nil;
	// NOTE: RMMapContents may still be initialising when this function
	//       is called. Be careful using any of methods - they might return
	//       strange data.
	layer = [[CAScrollLayer layer] retain];
	layer.anchorPoint = CGPointMake(0.0f, 0.0f);
	layer.masksToBounds = YES;
	// If the frame is set incorrectly here, it will be fixed when setRenderer is called in RMMapContents
	layer.frame = mapView.viewBounds;
	layer.delegate = self;
		
	
	return self;
}

-(void) dealloc
{
	[fadein release];
	[layer release];
	[super dealloc];
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)flag;
{
	animating = NO;
}

- (void)animationDidStart:(CAAnimation *)animation;
{
	animating = YES;
}

// this method is consulted first ahead of everything
- (id<CAAction>)actionForLayer:(CALayer *)theLayer
                        forKey:(NSString *)key
{
	if (!animating && animate && inserting) {
		if ([key isEqualToString:@"sublayers"] || 
			//	[key isEqualToString:kCAOnOrderIn] || 
			//	[key isEqualToString:kCAOnOrderOut] || 
			//	([key isEqualToString:@"onLayout"] && theLayer == layer) ||
			0
			)
		{
		//	NSLog(@"allowed key: %@ for: %@",key,[theLayer description]);
			if (!fadein) {
				// this is copied anyway when we hand it in, so a
				// bit more memory overhead but probably better
				fadein = [[CATransition alloc] init];
				fadein.duration = 0.4;
				fadein.delegate = self;
				fadein.type = kCATransitionFade;
			}
			return fadein;
		}
	}
	// this kills the ongoing search for an animation, we don't want anything
	return (id)[NSNull null];
}

- (void)tileImageDidLoad:(RMTileImage *)image;
{
	inserting = YES;
	[layer insertSublayer:image.layer atIndex:0];
	inserting = NO;
}

- (void)tileAdded: (RMTile) tile WithImage: (RMTileImage*) image
{
//	NSLog(@"tileAdded: %d %d %d at %f %f %f %f", tile.x, tile.y, tile.zoom, image.screenLocation.origin.x, image.screenLocation.origin.y,
//		  image.screenLocation.size.width, image.screenLocation.size.height);
	
//	NSLog(@"tileAdded");
	[image makeLayer];
	CALayer *sublayer = [image layer];
	sublayer.delegate = self;
	if ([image isLoaded]){
		inserting = YES;
		[layer insertSublayer:sublayer atIndex:0];
		inserting = NO;
	}
}


-(NSString*) description
{
	return @"CoreAnimation map renderer";
}

- (void)setFrame:(CGRect)frame
{
	layer.frame = mapView.viewBounds;
}

- (CALayer*) layer
{
	return layer;
}


@end
