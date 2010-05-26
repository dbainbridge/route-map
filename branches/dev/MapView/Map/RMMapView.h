//
//  RMMapView.h
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

/*! \mainpage Route-Me Map Framework 

\section intro_sec Introduction

Route-Me is an open source Objective-C framework for displaying maps on Cocoa Touch devices 
(the iPhone, and the iPod Touch). It was written in 2008 by Joseph Gentle as the basis for a transit
routing app. The transit app was not completed, because the government agencies involved chose not to release
the necessary data under reasonable licensing terms. The project was released as open source under the New BSD license (http://www.opensource.org/licenses/bsd-license.php) 
in September, 2008, and
is hosted on Google Code (http://code.google.com/p/route-me/).

 Route-Me provides a UIView subclass with a panning, zooming map. Zoom level, source of map data, map center,
 marker overlays, and path overlays are all supported.
 \section license_sec License
 Route-Me is licensed under the New BSD license.
 
 In any app that uses the Route-Me library, include the following text on your "preferences" or "about" screen: "Uses Route-Me map library, (c) 2008-2009 Route-Me Contributors". 
 
\section install_sec Installation
 
Because Route-Me is under rapid development as of early 2009, the best way to install Route-Me is use
Subversion and check out a copy of the repository:
\verbatim
svn checkout http://route-me.googlecode.com/svn/trunk/ route-me-read-only
\endverbatim

 There are numerous sample applications in the Subversion repository.
 
 To embed Route-Me maps in your Xcode project, follow the example given in samples/SampleMap or samples/ProgrammaticMap. The instructions in 
 the Embedding Guide at 
 http://code.google.com/p/route-me/wiki/EmbeddingGuide are out of date as of April 20, 2009. To create a static version of Route-Me, follow these 
 instructions instead: http://code.google.com/p/route-me/source/browse/trunk/MapView/README-library-build.rtf
 
\section maps_sec Map Data
 
 Route-Me supports map data served from many different sources:
 - the Open Street Map project's server.
 - CloudMade, which provides commercial servers delivering Open Street Map data.
 - Microsoft Virtual Earth.
 - Open Aerial Map.
 - Yahoo! Maps.
 
 Each of these data sources has different license restrictions and fees. In particular, Yahoo! Maps are 
 effectively unusable in Route-Me due to their license terms; the Yahoo! access code is provided for demonstration
 purposes only.
 
 You must contact the data vendor directly and arrange licensing if necessary, including obtaining your own
 access key. Follow their rules.
 
 If you have your own data you'd like to use with Route-Me, serving it through your own Mapnik installation
 looks like the best bet. Mapnik is an open source web-based map delivery platform. For more information on
 Mapnik, see http://www.mapnik.org/ .
 
 \section news_sec Project News and Updates
 For the most current information on Route-Me, see these sources:
 - wiki: http://code.google.com/p/route-me/w/list
 - project email reflector: http://groups.google.com/group/route-me-map
 - list of all project RSS feeds: http://code.google.com/p/route-me/feeds
 - applications using Route-Me: http://code.google.com/p/route-me/wiki/RoutemeApplications
 
 */

#import <UIKit/UIKit.h>
#import <CoreGraphics/CGGeometry.h>

#import "RMNotifications.h"
#import "RMFoundation.h"
#import "RMLatLong.h"
#import "RMMapViewDelegate.h"
#import "RMTilesUpdateDelegate.h"
#import "RMTile.h"

/*! 
 \struct RMGestureDetails
 iPhone-specific mapview stuff. Handles event handling, whatnot.
 */
typedef struct {
	CGPoint center;
	CGFloat angle;
	float averageDistanceFromCenter;
	int numTouches;
} RMGestureDetails;

@protocol RMMapContentsAnimationCallback <NSObject>
@optional
- (void)animationFinishedWithZoomFactor:(float)zoomFactor near:(CGPoint)p;
@end
@protocol RMMercatorToTileProjection;

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
@class RMMercatorToViewProjection;
@class RMTileImageSet;
@class RMTileLoader;
@class RMMapRenderer;
@class RMMapLayer;
@class RMLayerCollection;
@class RMMarker;
@class RMTileSource;

/*! 
 \brief Wrapper around RMMapContents for the iPhone.
 
 It implements event handling; but that's about it. All the interesting map
 logic is done by RMMapContents. There is exactly one RMMapView instance for each RMMapContents instance.
 
 A -forwardInvocation method exists for RMMap, and forwards all unhandled messages to the RMMapContents instance.
 
 \bug No accessors for enableDragging, enableZoom, deceleration, decelerationFactor. Changing enableDragging does not change multitouchEnabled for the view.
 */
@interface RMMapView : UIView <RMMapContentsAnimationCallback>
{
	id<RMMapViewDelegate> delegate;
	BOOL scrollEnabled;
	BOOL zoomEnabled;
	BOOL enableRotate;
	RMGestureDetails lastGesture;
	float decelerationFactor;
	BOOL deceleration;
        CGFloat rotation;
	
#pragma mark contents start
	// contents start
	
	RMMarkerManager *markerManager;
	/// subview for the image displayed while tiles are loading. Set its contents by providing your own "loading.png".
	RMMapLayer *background;
	/// subview for markers and paths
	RMLayerCollection *overlay;
	
	/// (guess) the projection object to convert from latitude/longitude to meters.
	/// Latlong is calculated dynamically from mercatorBounds.
	RMProjection *projection;
	
	id<RMMercatorToTileProjection> mercatorToTileProjection;
	
	/// (guess) converts from projected meters to screen pixel coordinates
	RMMercatorToViewProjection *mercatorToViewProjection;
	
	/// controls what images are used. Can be changed while the view is visible, but see http://code.google.com/p/route-me/issues/detail?id=12
	RMTileSource *tileSource;
	
	RMTileImageSet *imagesOnScreen;
	RMTileLoader *tileLoader;
	
	RMMapRenderer *renderer;
	NSUInteger		boundingMask;
	
	/// minimum zoom number allowed for the view. #minZoom and #maxZoom must be within the limits of #tileSource but can be stricter; they are clamped to tilesource limits if needed.
	float minZoom;
	/// maximum zoom number allowed for the view. #minZoom and #maxZoom must be within the limits of #tileSource but can be stricter; they are clamped to tilesource limits if needed.
	float maxZoom;
	
	id<RMTilesUpdateDelegate> tilesUpdateDelegate;
	
#pragma mark contents end
@private
	BOOL _delegateHasMapViewRegionWillChange;
	BOOL _delegateHasMapViewRegionDidChange;
	BOOL _delegateHasBeforeMapZoomByFactor;
	BOOL _delegateHasAfterMapZoomByFactor;
	BOOL _delegateHasBeforeMapRotate;
	BOOL _delegateHasAfterMapRotate;
	BOOL _delegateHasDoubleTapOnMap;
	BOOL _delegateHasSingleTapOnMap;
	BOOL _delegateHasTapOnMarker;
	BOOL _delegateHasTapOnLabelForMarker;
	BOOL _delegateHasAfterMapTouch;
	BOOL _delegateHasShouldDragMarker;
	BOOL _delegateHasDidDragMarker;
	BOOL _delegateHasDragMarkerPosition;
	
	NSTimer *_decelerationTimer;
	CGSize _decelerationDelta;
	
	BOOL _contentsIsSet; // "contents" must be set, but is initialized lazily to allow apps to override defaults in -awakeFromNib
}


// View properties
@property(nonatomic, getter=isScrollEnabled) BOOL scrollEnabled;
@property(nonatomic, getter=isZoomEnabled) BOOL zoomEnabled;
@property BOOL enableRotate;

@property (nonatomic, retain, readonly) RMMarkerManager *markerManager;

// do not retain the delegate so you can let the corresponding controller implement the
// delegate without circular references
@property (assign) id<RMMapViewDelegate> delegate;
@property (readwrite) float decelerationFactor;
@property (readwrite) BOOL deceleration;

@property (readonly) CGFloat rotation;




#pragma mark contents start
// contents properties
@property (nonatomic) CLLocationCoordinate2D centerCoordinate;
@property (nonatomic) RMProjectedPoint centerProjectedPoint;
@property (nonatomic) RMProjectedRect visibleMapRect;
@property (readonly)  RMTileRect tileBounds;
@property (readwrite) float metersPerPixel;
/// zoom level is clamped to range (minZoom, maxZoom)
@property (readwrite) float zoom;

@property (readwrite) float minZoom;
@property (readwrite) float maxZoom;

@property (readonly)  RMTileImageSet *imagesOnScreen;
@property (readonly)  RMTileLoader *tileLoader;

@property (readonly)  RMProjection *projection;
@property (readonly)  id<RMMercatorToTileProjection> mercatorToTileProjection;
@property (readonly)  RMMercatorToViewProjection *mercatorToViewProjection;

@property (retain, readwrite) RMTileSource *tileSource;
@property (retain, readwrite) RMMapRenderer *renderer;


@property (retain, readwrite) RMMapLayer *background;
@property (retain, readwrite) RMLayerCollection *overlay;
/// \bug probably shouldn't be retaining this delegate
@property (nonatomic, retain) id<RMTilesUpdateDelegate> tilesUpdateDelegate;
@property (readwrite) NSUInteger boundingMask;
/// The denominator in a cartographic scale like 1/24000, 1/50000, 1/2000000.
@property (readonly)double scaleDenominator;
// contents end
- (id)initWithView: (UIView*) view;
- (id)initWithView: (UIView*) view
		tilesource:(RMTileSource *)newTilesource;
/// designated initializer
- (id)initWithView:(UIView*)view
		tilesource:(RMTileSource *)tilesource
	  centerLatLon:(CLLocationCoordinate2D)initialCenter
		 zoomLevel:(float)initialZoomLevel
	  maxZoomLevel:(float)maxZoomLevel
	  minZoomLevel:(float)minZoomLevel
   backgroundImage:(UIImage *)backgroundImage;
#pragma mark contents end



- (void)moveBy: (CGSize) delta;
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) aPoint;
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) aPoint animated:(BOOL)animated;
- (float)nextNativeZoomFactor;
- (float)prevNativeZoomFactor;
- (float)adjustZoomForBoundingMask:(float)zoomFactor;

- (void)didReceiveMemoryWarning;

- (void)setRotation:(float)angle;
@property (readonly) CGRect viewBounds;



//contents start
- (CGPoint)convertCoordinateToPoint:(CLLocationCoordinate2D)aCoordinate;
- (CGPoint)convertCoordinateToPoint:(CLLocationCoordinate2D)aCoordinate withMetersPerPixel:(float)aScale;
- (RMTilePoint)convertCoordinateToTilePoint:(CLLocationCoordinate2D)aCoordinate withMetersPerPixel:(float)aScale;
- (CLLocationCoordinate2D)convertPointToCoordinate:(CGPoint)aPoint;
- (CLLocationCoordinate2D)convertPointToCoordinate:(CGPoint)aPoint withMetersPerPixel:(float)aScale;

- (void)zoomWithLatLngBoundsNorthEast:(CLLocationCoordinate2D)ne SouthWest:(CLLocationCoordinate2D)se;
- (void)zoomWithRMMercatorRectBounds:(RMProjectedRect)bounds;
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) pivot animated:(BOOL) animated withCallback:(id<RMMapContentsAnimationCallback>)callback;

/// returns the smallest bounding box containing the entire screen
- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxForScreen;
/// returns the smallest bounding box containing a rectangular region of the screen
- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxFor:(CGRect) rect;

- (void) tilesUpdatedRegion:(CGRect)region;

// During touch and move operations on the iphone its good practice to
// hold off on any particularly expensive operations so the user's 
+ (BOOL) performExpensiveOperations;
+ (void) setPerformExpensiveOperations: (BOOL)p;

@end
