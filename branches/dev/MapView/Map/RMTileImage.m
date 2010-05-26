//
//  RMTileImage.m
//
// Copyright (c) 2008-2009, Route-Me Contributors
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
#import "RMGlobalConstants.h"
#import "RMTileImage.h"
#import "RMTileLoader.h"
#import "RMPixel.h"
#import <QuartzCore/QuartzCore.h>

@implementation RMTileImage

@synthesize tile, layer, image;

@synthesize marked;

- (id) initWithTile: (RMTile)_tile
{
	if (![super init])
		return nil;
	
	tile = _tile;
	layer = nil;
	screenLocation = CGRectZero;

        [self makeLayer];

	
	[[NSNotificationCenter defaultCenter] addObserver:self
						selector:@selector(tileRemovedFromScreen:)
						name:RMMapImageRemovedFromScreenNotification object:self];
		
	return self;
}
	 
-(void) tileRemovedFromScreen: (NSNotification*) notification
{
	[self cancelLoading];
}
- (void)removeFromMap;
{
#warning implement this cleaner 	
	[layer retain];
#define LAYER_CLEANUP_DELAY	0.01
	[layer performSelector:@selector(removeFromSuperlayer) withObject:nil
				afterDelay:LAYER_CLEANUP_DELAY];
	[layer performSelector:@selector(release) withObject:nil afterDelay:LAYER_CLEANUP_DELAY+1];
}

-(id) init
{
	[NSException raise:@"Invalid initialiser" format:@"Use the designated initialiser for TileImage"];
	[self release];
	return nil;
}

+ (RMTileImage*) dummyTile: (RMTile)tile
{
	return [[[self alloc] initWithTile:tile] autorelease];
}

- (void)dealloc
{
//	RMLog(@"Removing tile image %d %d %d", tile.x, tile.y, tile.zoom);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[layer release]; layer = nil;
	[key release];
	key = nil;
	
	[super dealloc];
}

-(void)draw
{
}

+ (RMTileImage*)imageForTile:(RMTile) _tile withURL: (NSString*)url
{
	return [[[RMTileImage alloc] initWithTile:_tile withURL:url] autorelease];
}


+ (RMTileImage*)imageForTile:(RMTile) tile withData: (NSData*)data
{
	RMTileImage *image = [[RMTileImage alloc] initWithTile:tile];
	[image updateImageUsingData:data];
	return [image autorelease];
}
- (NSString *)description;
{
	return [NSString stringWithFormat:@"((RMTileImage *)%p) %@: [%c%c%c] X=%d Y=%d zoom=%d",self,
			key,
			marked?'x':' ',
			isLoading?'+':' ',
			isLoaded?'*':' ',
			tile.x<<(18-tile.zoom),
			tile.y<<(18-tile.zoom),
			tile.zoom]; 
}

-(void) cancelLoading
{
	if (isLoading) {
		[RMTileFactory cancelImage:key forClient:self];
	}
}


- (void)updateImageUsingData: (NSData*) data
{
       [self updateImageUsingImage:[UIImage imageWithData:data]];

       NSDictionary *d = [NSDictionary dictionaryWithObject:data forKey:@"data"];
       [[NSNotificationCenter defaultCenter] postNotificationName:RMMapImageLoadedNotification object:self userInfo:d];
}

- (void)updateImageUsingImage: (UIImage*) rawImage
{
	layer.contents = (id)[rawImage CGImage];
}

- (void)setImage:(UIImage *)_image;
{
	if (!_image) {
		return;
	}
	isLoaded = YES;
	if (layer) {
		id delegate = [layer delegate];
		layer.delegate = nil;
		layer.contents = (id)[_image CGImage];
		layer.delegate = delegate;
		if ([delegate respondsToSelector:@selector(tileImageDidLoad:)]){
			[delegate performSelector:@selector(tileImageDidLoad:) withObject:self];
		}
	} else {
		image = [_image retain];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:RMMapImageLoadedNotification 
														object:self];
	
}

- (BOOL)isLoaded
{
	return isLoaded;
}

- (NSUInteger)hash
{
	return (NSUInteger)RMTileHash(tile);
}


- (BOOL)isEqual:(id)anObject
{
	if (![anObject isKindOfClass:[RMTileImage class]])
		return NO;

	return RMTilesEqual(tile, [(RMTileImage*)anObject tile]);
}

- (void)makeLayer
{
	if (layer == nil)
	{
		layer = [[CALayer alloc] init];
		layer.contents = nil;
		layer.anchorPoint = CGPointZero;
		layer.bounds = CGRectMake(0, 0, screenLocation.size.width, screenLocation.size.height);
		layer.position = screenLocation.origin;
		
		NSMutableDictionary *customActions=[NSMutableDictionary dictionaryWithDictionary:[layer actions]];
		
		[customActions setObject:[NSNull null] forKey:@"position"];
		[customActions setObject:[NSNull null] forKey:@"bounds"];
		[customActions setObject:[NSNull null] forKey:kCAOnOrderOut];
		
/*		CATransition *fadein = [[CATransition alloc] init];
		fadein.duration = 2.0;
		fadein.type = kCATransitionFade;
		[customActions setObject:fadein forKey:kCAOnOrderIn];
		[fadein release];
*/
		[customActions setObject:[NSNull null] forKey:kCAOnOrderIn];
		
		layer.actions=customActions;
		
		layer.edgeAntialiasingMask = 0;
		NSLog(@"layer made");
	}
	if (image != nil)
	{
		layer.contents = (id)[image CGImage];
		[image release];
		image = nil;
		//		NSLog(@"layer contents set");
	}
}

- (void)moveBy: (CGSize) delta
{
	self.screenLocation = RMTranslateCGRectBy(screenLocation, delta);
}

- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center
{
	self.screenLocation = RMScaleCGRectAboutPoint(screenLocation, zoomFactor, center);
}

- (CGRect) screenLocation
{
	return screenLocation;
}

- (void) setScreenLocation: (CGRect)newScreenLocation
{
//	RMLog(@"location moving from %f %f to %f %f", screenLocation.origin.x, screenLocation.origin.y, newScreenLocation.origin.x, newScreenLocation.origin.y);
	screenLocation = newScreenLocation;
	
	if (layer != nil)
	{
		// layer.frame = screenLocation;
		layer.position = screenLocation.origin;
		layer.bounds = CGRectMake(0, 0, screenLocation.size.width, screenLocation.size.height);
	}
	
}

- (void) displayProxy:(UIImage*) img
{
        layer.contents = (id)[img CGImage]; 
}
- (void)factoryDidLoad:(UIImage *)tileImage forRequest:(NSString *)requestedResource;
{
	isLoading = NO;
	self.image = tileImage;
}

- (id)initWithTile: (RMTile)_tile withURL:(NSString*)urlStr
{
	if (![self initWithTile:_tile])
	return nil;
	key = [urlStr retain];
	image = [RMTileFactory requestImage:key forClient:self];
	if (image) {
		[image retain];
		isLoaded = YES;
	} else {
		isLoading = YES;
	}
	return self;
}

- (void)factoryDidFail:(NSString *)request;
{
	isLoading = NO;
}

@end
