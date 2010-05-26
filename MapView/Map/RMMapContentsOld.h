//
//  RMMapContents.h
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
#import <UIKit/UIKit.h>

#import "RMFoundation.h"
#import "RMLatLong.h"
#import "RMTile.h"

#import "RMTilesUpdateDelegate.h"


// constants for boundingMask
enum {
	// Map can be zoomed out past view limits
	RMMapNoMinBound			= 0,
	// Minimum map height when zooming out restricted to view height
	RMMapMinHeightBound		= 1,
	// Minimum map width when zooming out restricted to view width ( default )
	RMMapMinWidthBound		= 2
};

#define kDefaultInitialLatitude -33.858771
#define kDefaultInitialLongitude 151.201596

#define kDefaultMinimumZoomLevel 0.0
#define kDefaultMaximumZoomLevel 25.0
#define kDefaultInitialZoomLevel 13.0

@class RMMarkerManager;
@class RMProjection;
@class RMMercatorToScreenProjection;
@class RMTileImageSet;
@class RMTileLoader;
@class RMMapRenderer;
@class RMMapLayer;
@class RMLayerCollection;
@class RMMarker;
@protocol RMMercatorToTileProjection;
@protocol RMTileSource;


@protocol RMMapContentsAnimationCallback <NSObject>
@optional
- (void)animationFinishedWithZoomFactor:(float)zoomFactor near:(CGPoint)p;
@end


/*! \brief The cartographic and data components of a map. Do not retain.
 
 There is exactly one RMMapContents instance for each RMMapView instance.
 
 \warning Do not retain an RMMapContents instance. Instead, ask the RMMapView for its contents 
 when you need it. It is an error for an RMMapContents instance to exist without a view, and 
 if you retain the RMMapContents, it can't go away when the RMMapView is released.
 
 At some point, it's likely that RMMapContents and RMMapView will be merged into one class.
 
 */
@interface RMMapContents : NSObject
{
}


- (id)initWithView: (UIView*) view;
- (id)initWithView: (UIView*) view
		tilesource:(id<RMTileSource>)newTilesource;
/// designated initializer
- (id)initWithView:(UIView*)view
		tilesource:(id<RMTileSource>)tilesource
	  centerLatLon:(CLLocationCoordinate2D)initialCenter
		 zoomLevel:(float)initialZoomLevel
	  maxZoomLevel:(float)maxZoomLevel
	  minZoomLevel:(float)minZoomLevel
   backgroundImage:(UIImage *)backgroundImage;



- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center;
- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated;
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated; 
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center animated:(BOOL) animated;
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center animated:(BOOL) animated withCallback:(id<RMMapContentsAnimationCallback>)callback;

- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot;
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot; 
- (float)adjustZoomForBoundingMask:(float)zoomFactor;
- (void)adjustMapPlacementWithScale:(float)aScale;



@end

/// Appears to be the methods actually implemented by RMMapContents, but generally invoked on RMMapView, and forwarded to the contents object.
@protocol RMMapContentsFacade

@optional
- (void)moveToLatLong: (CLLocationCoordinate2D)latlong;
- (void)moveToProjectedPoint: (RMProjectedPoint)aPoint;

- (void)moveBy: (CGSize) delta;
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center;
- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated;
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated; 
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center animated:(BOOL) animated;

- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot;
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot; 
- (float)adjustZoomForBoundingMask:(float)zoomFactor;
- (void)adjustMapPlacementWithScale:(float)aScale;

- (CGPoint)latLongToPixel:(CLLocationCoordinate2D)latlong;
- (CGPoint)latLongToPixel:(CLLocationCoordinate2D)latlong withMetersPerPixel:(float)aScale;
- (CLLocationCoordinate2D)pixelToLatLong:(CGPoint)aPixel;
- (CLLocationCoordinate2D)pixelToLatLong:(CGPoint)aPixel withMetersPerPixel:(float)aScale;

- (void)zoomWithLatLngBoundsNorthEast:(CLLocationCoordinate2D)ne SouthWest:(CLLocationCoordinate2D)se;
- (void)zoomWithRMMercatorRectBounds:(RMProjectedRect)bounds;

/// \deprecated name change pending after 0.5
- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxForScreen;
/// \deprecated name change pending after 0.5
- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxFor:(CGRect) rect;

- (void) tilesUpdatedRegion:(CGRect)region;


@end

