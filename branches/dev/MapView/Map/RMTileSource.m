//
//  RMTileSource.m
//
// Copyright (c) 2010, Route-Me Contributors
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

#import "RMTileSource.h"
#import "RMNotifications.h"


@implementation RMTileSource
static UIImage *_errorTile = nil;
static UIImage *_loadingTile = nil;
static UIImage *_missingTile = nil;

+ (UIImage*) errorTile
{
	if (_errorTile) return _errorTile;
	
	_errorTile = [[UIImage imageNamed:@"error.png"] retain];
	return _errorTile;
}

+ (UIImage*) loadingTile
{
	if (_loadingTile) return _loadingTile;
	
	_loadingTile = [[UIImage imageNamed:@"loading.png"] retain];
	return _loadingTile;
}

+ (UIImage*) missingTile
{
	if (_missingTile) return _missingTile;
	
	_missingTile = [[UIImage imageNamed:@"missing.png"] retain];
	return _missingTile;
}


-(id) init
{
	if (![super init])
		return nil;
	
	tileProjection = [[RMFractalTileProjection alloc] initFromProjection:[self projection] tileSideLength:kDefaultTileSize maxZoom:kDefaultMaxTileZoom minZoom:kDefaultMinTileZoom];
	
	networkOperations = TRUE;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkOperationsNotification:) name:RMSuspendNetworkOperations object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkOperationsNotification:) name:RMResumeNetworkOperations object:nil];
	
	return self;
}

- (void) networkOperationsNotification: (NSNotification*) notification
{	
	if(notification.name == RMSuspendNetworkOperations)
		networkOperations = FALSE;
	else if(notification.name == RMResumeNetworkOperations)
		networkOperations = TRUE;
}

-(void) dealloc
{
	[tileProjection release];
	[super dealloc];
}

-(int)tileSideLength
{
	return tileProjection.tileSideLength;
}

- (void) setTileSideLength: (NSUInteger) aTileSideLength
{
	[tileProjection setTileSideLength:aTileSideLength];
}

-(float) minZoom
{
	return (float)tileProjection.minZoom;
}

-(float) maxZoom
{
	return (float)tileProjection.maxZoom;
}

-(void) setMinZoom:(NSUInteger)aMinZoom
{
	[tileProjection setMinZoom:aMinZoom];
}

-(void) setMaxZoom:(NSUInteger)aMaxZoom
{
	[tileProjection setMaxZoom:aMaxZoom];
}

-(RMSphericalTrapezium) latitudeLongitudeBoundingBox;
{
	return kDefaultLatLonBoundingBox;
}

/// \bug magic string literals
-(NSString*) tileURL: (RMTile) tile
{
	@throw [NSException exceptionWithName:@"RMAbstractMethodInvocation" reason:@"tileURL invoked on AbstractMercatorWebSource. Override this method when instantiating abstract class." userInfo:nil];
}

-(NSString*) tileFile: (RMTile) tile
{
	return nil;
}

-(NSString*) tilePath
{
	return nil;
}

-(RMTileImage *)tileImage:(RMTile)tile
{
	RMTileImage *image;
	
	tile = [tileProjection normaliseTile:tile];
	
	
	if(networkOperations) 
	{
		image = [RMTileImage imageForTile:tile withURL:[self tileURL:tile]];     
	}
	else
	{
		image = [RMTileImage dummyTile:tile];
	}
	
	return image;
}

-(id<RMMercatorToTileProjection>) mercatorToTileProjection
{
	return [[tileProjection retain] autorelease];
}

-(RMProjection*) projection
{
	return [RMProjection googleProjection];
}

-(void) didReceiveMemoryWarning
{
	LogMethod();		
}

-(NSString *)uniqueTilecacheKey
{
	@throw [NSException exceptionWithName:@"RMAbstractMethodInvocation" reason:@"uniqueTilecacheKey invoked on AbstractMercatorWebSource. Override this method when instantiating abstract class." userInfo:nil];
}

-(NSString *)shortName
{
	@throw [NSException exceptionWithName:@"RMAbstractMethodInvocation" reason:@"shortName invoked on AbstractMercatorWebSource. Override this method when instantiating abstract class." userInfo:nil];
}
-(NSString *)longDescription
{
	return [self shortName];
}
-(NSString *)shortAttribution
{
	@throw [NSException exceptionWithName:@"RMAbstractMethodInvocation" reason:@"shortAttribution invoked on AbstractMercatorWebSource. Override this method when instantiating abstract class." userInfo:nil];
}
-(NSString *)longAttribution
{
	return [self shortAttribution];
}

@end
