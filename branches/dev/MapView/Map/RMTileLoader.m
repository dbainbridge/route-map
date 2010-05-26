//
//  RMTimeImageSet.m
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
#import "RMGlobalConstants.h"w
#import "RMTileLoader.h"

#import "RMTileImage.h"
#import "RMTileSource.h"
#import "RMPixel.h"
#import "RMMercatorToViewProjection.h"
#import "RMFractalTileProjection.h"
#import "RMTileImageSet.h"


@implementation RMTileLoader

@synthesize loadedBounds, loadedZoom;

-(id) init
{
	if (![self initWithMapView: nil])
		return nil;
	
	return self;
}

-(id) initWithMapView: (RMMapView *)aMapView
{
	if (![super init])
		return nil;
	
	mapView = aMapView;
	
	[self clearLoadedBounds];
	loadedTiles.origin.tile = RMTileDummy();
	
	suppressLoading = NO;
	
	return self;
}

-(void) dealloc
{
	[super dealloc];
}

-(void) clearLoadedBounds
{
	loadedBounds = CGRectZero;
}

-(BOOL) screenIsLoaded
{
	//	RMTileRect targetRect = [content tileBounds];
	BOOL contained = CGRectContainsRect(loadedBounds, mapView.viewBounds);
	
	int targetZoom = (int)([[mapView mercatorToTileProjection] calculateNormalisedZoomFromScale:[mapView metersPerPixel]]);
	if((targetZoom > mapView.maxZoom) || (targetZoom < mapView.minZoom))
          RMLog(@"target zoom %d is outside of RMMapContents limits %f to %f",
			  targetZoom, mapView.minZoom, mapView.maxZoom);
	if (contained == NO)
	{
		//		RMLog(@"reassembling because its not contained");
	}
	
	if (targetZoom != loadedZoom)
	{
		//		RMLog(@"reassembling because target zoom = %f, loaded zoom = %d", targetZoom, loadedZoom);
	}
	
	return contained && ( targetZoom == loadedZoom );
}


-(void) updateLoadedImages
{
	if (suppressLoading)
		return;
	
	if ([mapView mercatorToTileProjection] == nil || [mapView  
													  mercatorToViewProjection] == nil)
		return;
	
	
	if ([self screenIsLoaded])
		return;
	
	//RMLog(@"updateLoadedImages initial count = %d", [[content imagesOnScreen] count]);
	
	RMTileRect newTileRect = [mapView tileBounds];
	
	RMTileImageSet *images = [mapView imagesOnScreen];
	CGRect newLoadedBounds = [images addTiles:newTileRect ToDisplayIn:
							  mapView.viewBounds];
	//RMLog(@"updateLoadedImages added count = %d", [images count]);
	
	
	if (!RMTileIsDummy(loadedTiles.origin.tile))
	{
		[images removeTilesOutsideOf:newTileRect];
	}
	
	//RMLog(@"updateLoadedImages final count = %d", [images count]);
	
	loadedBounds = newLoadedBounds;
	loadedZoom = newTileRect.origin.tile.zoom;
	loadedTiles = newTileRect;
	
	[mapView tilesUpdatedRegion:newLoadedBounds];
	
} 

/*
 -(void) updateLoadedImages
 {
 if (suppressLoading)
 return;
 
 if ([content mercatorToTileProjection] == nil || [content mercatorToViewProjection] == nil)
 return;
 
 if ([self screenIsLoaded])
 return;
 
 RMLog(@"assemble count = %d", [[content imagesOnScreen] count]);
 
 RMTileRect newTileRect = [content tileBounds];
 
 RMTileImageSet *images = [content imagesOnScreen];
 CGRect newLoadedBounds = [images addTiles:newTileRect ToDisplayIn:[content screenBounds]];
 RMLog(@"-> mid count = %d", [images count]);
 
 if (!RMTileIsDummy(loadedTiles.origin.tile))
 [images removeTiles:loadedTiles];
 
 RMLog(@"-> count = %d", [images count]);
 
 loadedBounds = newLoadedBounds;
 loadedZoom = newTileRect.origin.tile.zoom;
 loadedTiles = newTileRect;
 
 [content tilesUpdatedRegion:newLoadedBounds];
 }*/

- (void)moveBy: (CGSize) delta
{
	//	RMLog(@"loadedBounds %f %f %f %f -> ", loadedBounds.origin.x, loadedBounds.origin.y, loadedBounds.size.width, loadedBounds.size.height);
	loadedBounds = RMTranslateCGRectBy(loadedBounds, delta);
	//	RMLog(@" -> %f %f %f %f", loadedBounds.origin.x, loadedBounds.origin.y, loadedBounds.size.width, loadedBounds.size.height);
	[self updateLoadedImages];
}

- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center
{
	loadedBounds = RMScaleCGRectAboutPoint(loadedBounds, zoomFactor, center);
	[self updateLoadedImages];
}

- (BOOL) suppressLoading
{
	return suppressLoading;
}

- (void) setSuppressLoading: (BOOL) suppress
{
	suppressLoading = suppress;
	
	if (suppress == NO)
		[self updateLoadedImages];
}

- (void)reset
{
	loadedTiles.origin.tile = RMTileDummy();
}

- (void)reload
{
	[self clearLoadedBounds];
	[self updateLoadedImages];
}

//-(BOOL) containsRect: (CGRect)bounds
//{
//	return CGRectContainsRect(loadedBounds, bounds);
//}

- (void) mapImageLoaded:(NSNotification *)notification
{
	RMTileImage *image = [notification object];
	int currentZoom = mapView.tileBounds.origin.tile.zoom;
	//	int dz = abs(currentZoom - image.tile.zoom);
	RMTileImageSet *set = [mapView imagesOnScreen];
	
	[set removeCompetingTiles:image.tile usingZoom:currentZoom];
	NSLog(@"%@",[set description]);
	//	[set removeTilesWithZoomLessThan:currentZoom - dz];
	//	[set removeTilesWithZoomMoreThan:currentZoom + dz];
}

@end
