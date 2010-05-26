//
//  RMMapContents.m
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
#import "RMMapContents.h"

#import "RMMapView.h"

#import "RMFoundation.h"
#import "RMProjection.h"
#import "RMMercatorToViewProjection.h"
#import "RMMercatorToTileProjection.h"

#import "RMTileSource.h"
#import "RMTileLoader.h"
#import "RMTileImageSet.h"

#import "RMOpenStreetMapSource.h"
#import "RMCoreAnimationRenderer.h"

#import "RMLayerCollection.h"
#import "RMMarkerManager.h"

#import "RMMarker.h"





@implementation RMMapContents









#pragma mark Forwarded Events



/// \bug doesn't really adjust anything, just makes a computation. CLANG flags some dead assignments (write-only variables)
- (float)adjustZoomForBoundingMask:(float)zoomFactor
{
	if ( boundingMask ==  RMMapNoMinBound )
		return zoomFactor;
	
	double newMPP = self.metersPerPixel / zoomFactor;
	
	RMProjectedRect mercatorBounds = [[tileSource projection] planetBounds];
	
	// Check for MinWidthBound
	if ( boundingMask & RMMapMinWidthBound )
	{
		double newMapContentsWidth = mercatorBounds.size.width / newMPP;
		double screenBoundsWidth = [self screenBounds].size.width;
		double mapContentWidth;
		
		if ( newMapContentsWidth < screenBoundsWidth )
		{
			// Calculate new zoom facter so that it does not shrink the map any further. 
			mapContentWidth = mercatorBounds.size.width / self.metersPerPixel;
			zoomFactor = screenBoundsWidth / mapContentWidth;
			
			//newMPP = self.metersPerPixel / zoomFactor;
			//newMapContentsWidth = mercatorBounds.size.width / newMPP;
		}
		
	}
	
	// Check for MinHeightBound	
	if ( boundingMask & RMMapMinHeightBound )
	{
		double newMapContentsHeight = mercatorBounds.size.height / newMPP;
		double screenBoundsHeight = [self screenBounds].size.height;
		double mapContentHeight;
		
		if ( newMapContentsHeight < screenBoundsHeight )
		{
			// Calculate new zoom facter so that it does not shrink the map any further. 
			mapContentHeight = mercatorBounds.size.height / self.metersPerPixel;
			zoomFactor = screenBoundsHeight / mapContentHeight;
			
			//newMPP = self.metersPerPixel / zoomFactor;
			//newMapContentsHeight = mercatorBounds.size.height / newMPP;
		}
		
	}
	
	//[self adjustMapPlacementWithScale:newMPP];
	
	return zoomFactor;
}

/// This currently is not called because it does not handle the case when the map is continous or not continous.  At a certain scale
/// you can continuously move to the west or east until you get to a certain scale level that simply shows the entire world.
- (void)adjustMapPlacementWithScale:(float)aScale
{
	CGSize		adjustmentDelta = {0.0, 0.0};
	RMLatLong	rightEdgeLatLong = {0, kMaxLong};
	RMLatLong	leftEdgeLatLong = {0,- kMaxLong};
	
	CGPoint		rightEdge = [self convertCoordinateToPoint:rightEdgeLatLong withMetersPerPixel:aScale];
	CGPoint		leftEdge = [self convertCoordinateToPoint:leftEdgeLatLong withMetersPerPixel:aScale];
	//CGPoint		topEdge = [self latLongToPixel:myLatLong withMetersPerPixel:aScale];
	//CGPoint		bottomEdge = [self latLongToPixel:myLatLong withMetersPerPixel:aScale];
	
	CGRect		containerBounds = [self screenBounds];

	if ( rightEdge.x < containerBounds.size.width ) 
	{
		adjustmentDelta.width = containerBounds.size.width - rightEdge.x;
		[self moveBy:adjustmentDelta];
	}
	
	if ( leftEdge.x > containerBounds.origin.x ) 
	{
		adjustmentDelta.width = containerBounds.origin.x - leftEdge.x;
		[self moveBy:adjustmentDelta];
	}
	
	
}

/// \bug this is a no-op, not a clamp, if new zoom would be outside of minzoom/maxzoom range
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) pivot
{
	//[self zoomByFactor:zoomFactor near:pivot animated:NO];
	
	zoomFactor = [self adjustZoomForBoundingMask:zoomFactor];
	//RMLog(@"Zoom Factor: %lf for Zoom:%f", zoomFactor, [self zoom]);
	
	// pre-calculate zoom so we can tell if we want to perform it
	float newZoom = [mercatorToTileProjection  
					 calculateZoomFromScale:self.metersPerPixel/zoomFactor];
	
	if ((newZoom > minZoom) && (newZoom < maxZoom))
	{
		[mercatorToViewProjection zoomScreenByFactor:zoomFactor near:pivot];
		[imagesOnScreen zoomByFactor:zoomFactor near:pivot];
		[tileLoader zoomByFactor:zoomFactor near:pivot];
		[overlay zoomByFactor:zoomFactor near:pivot];
		[renderer setNeedsDisplay];
	} 
}


- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) pivot animated:(BOOL) animated
{
	[self zoomByFactor:zoomFactor near:pivot animated:animated withCallback:nil];
}




- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot
{
	[self zoomInToNextNativeZoomAt:pivot animated:NO];
}

- (float)nextNativeZoomFactor
{
	float newZoom = fmin(floorf([self zoom] + 1.0), [self maxZoom]);
	return exp2f(newZoom - [self zoom]);
}

- (float)prevNativeZoomFactor
{
	float newZoom = fmax(floorf([self zoom] - 1.0), [self minZoom]);
	return exp2f(newZoom - [self zoom]);
}

/// \deprecated appears to be unused
- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated
{
	// Calculate rounded zoom
	float newZoom = fmin(floorf([self zoom] + 1.0), [self maxZoom]);
	RMLog(@"[self minZoom] %f [self zoom] %f [self maxZoom] %f newzoom %f", [self minZoom], [self zoom], [self maxZoom], newZoom);
	
	float factor = exp2f(newZoom - [self zoom]);
	[self zoomByFactor:factor near:pivot animated:animated];
}

/// \deprecated appears to be unused except by zoomOutToNextNativeZoomAt:
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated {
	// Calculate rounded zoom
	float newZoom = fmax(ceilf([self zoom] - 1.0), [self minZoom]);
	RMLog(@"[self minZoom] %f [self zoom] %f [self maxZoom] %f newzoom %f", [self minZoom], [self zoom], [self maxZoom], newZoom);
	
	float factor = exp2f(newZoom - [self zoom]);
	[self zoomByFactor:factor near:pivot animated:animated];
}

/// \deprecated appears to be unused
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot {
	[self zoomOutToNextNativeZoomAt: pivot animated: FALSE];
}
 







@end
