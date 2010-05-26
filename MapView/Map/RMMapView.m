//
//  RMMapView.m
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

#import "RMMapView.h"
#import "RMMapViewDelegate.h"

#import "RMTileLoader.h"

#import "RMProjection.h"
#import "RMMercatorToViewProjection.h"
#import "RMMercatorToTileProjection.h"
#import "RMMarker.h"
#import "RMMapRenderer.h"

#import "RMMarkerManager.h"
#import "RMOpenStreetMapSource.h"
#import "RMCoreAnimationRenderer.h"
#import "RMLayerCollection.h"

@interface RMMapView (PrivateMethods)
// methods for post-touch deceleration, ala UIScrollView
- (void)startDecelerationWithDelta:(CGSize)delta;
- (void)incrementDeceleration:(NSTimer *)timer;
- (void)stopDeceleration;
- (void)animatedZoomStep:(NSTimer *)timer;
@end

@implementation RMMapView (Internal)
BOOL delegateHasRegionUpdate;
@end

@implementation RMMapView

@synthesize decelerationFactor;
@synthesize deceleration;

@synthesize rotation;

@synthesize scrollEnabled;
@synthesize zoomEnabled;
@synthesize enableRotate;


@synthesize boundingMask;
@synthesize minZoom;
@synthesize maxZoom;
@synthesize markerManager;
@synthesize overlay;

#pragma mark --- begin constants ----
#define kDefaultDecelerationFactor .88f
#define kMinDecelerationDelta 0.01f

#define kZoomAnimationStepTime 0.03f
#define kZoomAnimationAnimationTime 0.1f
#define kiPhoneMilimeteresPerPixel .1543
#define kZoomRectPixelBuffer 50

#pragma mark --- end constants ----

- (RMMarkerManager*)markerManager
{
  return markerManager;
}

- (void) performInitialSetup
{
	LogMethod();

	self.scrollEnabled = YES;
	self.zoomEnabled = YES;
	enableRotate = NO;
	decelerationFactor = kDefaultDecelerationFactor;
	deceleration = NO;
	
	//	[self recalculateImageSet];
	
	if (self.isZoomEnabled || enableRotate)
		[self setMultipleTouchEnabled:TRUE];
	
	self.backgroundColor = [UIColor redColor];
	
//	[[NSURLCache sharedURLCache] removeAllCachedResponses];
}
- (id)initWithFrame:(CGRect)frame
{
	LogMethod();
	if (self = [super initWithFrame:frame]) {
		[self performInitialSetup];
	}
	return self;
}

- (id)initWithView: (UIView*) view
{	
	LogMethod();
	CLLocationCoordinate2D here;
	here.latitude = kDefaultInitialLatitude;
	here.longitude = kDefaultInitialLongitude;
	
	return [self initWithView:view
				   tilesource:[[RMOpenStreetMapSource alloc] init]
				 centerLatLon:here
	  			    zoomLevel:kDefaultInitialZoomLevel
				 maxZoomLevel:kDefaultMaximumZoomLevel
				 minZoomLevel:kDefaultMinimumZoomLevel
			  backgroundImage:nil];
}

- (void)awakeFromNib
{
	CLLocationCoordinate2D latlong = {0, 0};
	[super awakeFromNib];
	[self performInitialSetup];
	[self initWithView:self];
}

- (id)initWithView: (UIView*) view
		tilesource:(RMTileSource *)newTilesource
{	
	LogMethod();
	CLLocationCoordinate2D here;
	here.latitude = kDefaultInitialLatitude;
	here.longitude = kDefaultInitialLongitude;
	
	return [self initWithView:view
				   tilesource:newTilesource
				 centerLatLon:here
					zoomLevel:kDefaultInitialZoomLevel
				 maxZoomLevel:kDefaultMaximumZoomLevel
				 minZoomLevel:kDefaultMinimumZoomLevel
			  backgroundImage:nil];
}

- (id)initWithView:(UIView*)newView
		tilesource:(RMTileSource *)newTilesource
	  centerLatLon:(CLLocationCoordinate2D)initialCenter
		 zoomLevel:(float)initialZoomLevel
	  maxZoomLevel:(float)maxZoomLevel
	  minZoomLevel:(float)minZoomLevel
   backgroundImage:(UIImage *)backgroundImage
{
	LogMethod();
//	if (![super init])
//		return nil;
	
	NSAssert1([newView isKindOfClass:[RMMapView class]], @"view %@ must be a subclass of RMMapView", newView);
	
	tileSource = nil;
	projection = nil;
	mercatorToTileProjection = nil;
	renderer = nil;
	imagesOnScreen = nil;
	tileLoader = nil;
	
	boundingMask = RMMapMinWidthBound;
	
	mercatorToViewProjection = [[RMMercatorToViewProjection alloc] initWithProjection:[newTilesource projection] bounds:[self bounds]];
	
	
	[self setMinZoom:minZoomLevel];
	[self setMaxZoom:maxZoomLevel];
	
	[self setTileSource:newTilesource];
	[self setRenderer: [[[RMCoreAnimationRenderer alloc] initWithMapView:self] autorelease]];
	
	imagesOnScreen = [[RMTileImageSet alloc] initWithDelegate:renderer];
	[imagesOnScreen setTileSource:tileSource];
	
	tileLoader = [[RMTileLoader alloc] initWithMapView:self];
	[tileLoader setSuppressLoading:YES];
	
	[self setZoom:initialZoomLevel];
	
	self.centerCoordinate = initialCenter;
	
	[tileLoader setSuppressLoading:NO];
	
	/// \bug TODO: Make a nice background class
	RMMapLayer *theBackground = [[RMMapLayer alloc] init];
	[self setBackground:theBackground];
	[theBackground release];
	
	RMLayerCollection *theOverlay = [[RMLayerCollection alloc] initWithMapView:self];
	[self setOverlay:theOverlay];
	[theOverlay release];
	
	markerManager = [[RMMarkerManager alloc] initWithMapView:self];
	
	[newView setNeedsDisplay];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleMemoryWarningNotification:) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
	
	
	RMLog(@"Map contents initialised. view: %@ tileSource %@ renderer %@", newView, tileSource, renderer);
	return self;
}


- (void) dealloc
{
	LogMethod();
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[imagesOnScreen cancelLoading];
	[self setRenderer:nil];
	[imagesOnScreen release];
	[tileLoader release];
	[projection release];
	[mercatorToTileProjection release];
	[mercatorToViewProjection release];
	[tileSource release];
	[self setOverlay:nil];
	[self setBackground:nil];

	[markerManager release];
	[super dealloc];
}

- (void) drawRect: (CGRect) rect
{
}

- (NSString*) description
{
	CGRect bounds = [self bounds];
	return [NSString stringWithFormat:@"MapView at %.0f,%.0f-%.0f,%.0f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height];
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	if ([super respondsToSelector:aSelector])
		return [super methodSignatureForSelector:aSelector];
	else
		return [self methodSignatureForSelector:aSelector];
}

#pragma mark Delegate 

@dynamic delegate;

- (void) setDelegate: (id<RMMapViewDelegate>) _delegate
{
	if (delegate == _delegate) return;
	delegate = _delegate;
	
	_delegateHasMapViewRegionWillChange = [(NSObject*) delegate respondsToSelector: @selector(mapViewRegionWillChange:)];
	_delegateHasMapViewRegionDidChange  = [(NSObject*) delegate respondsToSelector: @selector(mapViewRegionDidChange:)];
	
	_delegateHasBeforeMapZoomByFactor = [(NSObject*) delegate respondsToSelector: @selector(beforeMapZoom: byFactor: near:)];
	_delegateHasAfterMapZoomByFactor  = [(NSObject*) delegate respondsToSelector: @selector(afterMapZoom: byFactor: near:)];

	_delegateHasBeforeMapRotate  = [(NSObject*) delegate respondsToSelector: @selector(beforeMapRotate: fromAngle:)];
	_delegateHasAfterMapRotate  = [(NSObject*) delegate respondsToSelector: @selector(afterMapRotate: toAngle:)];

	_delegateHasDoubleTapOnMap = [(NSObject*) delegate respondsToSelector: @selector(doubleTapOnMap:At:)];
	_delegateHasSingleTapOnMap = [(NSObject*) delegate respondsToSelector: @selector(singleTapOnMap:At:)];
	
	_delegateHasTapOnMarker = [(NSObject*) delegate respondsToSelector:@selector(tapOnMarker:onMap:)];
	_delegateHasTapOnLabelForMarker = [(NSObject*) delegate respondsToSelector:@selector(tapOnLabelForMarker:onMap:)];
	
	_delegateHasAfterMapTouch  = [(NSObject*) delegate respondsToSelector: @selector(afterMapTouch:)];
   
   	_delegateHasShouldDragMarker = [(NSObject*) delegate respondsToSelector: @selector(mapView: shouldDragMarker: withEvent:)];
   	_delegateHasDidDragMarker = [(NSObject*) delegate respondsToSelector: @selector(mapView: didDragMarker: withEvent:)];
	
	_delegateHasDragMarkerPosition = [(NSObject*) delegate respondsToSelector: @selector(dragMarkerPosition: onMap: position:)];
}

- (id<RMMapViewDelegate>) delegate
{
	return delegate;
}

#pragma mark Movement


- (void)moveBy: (CGSize) delta
{
	if (_delegateHasMapViewRegionWillChange) [delegate mapViewRegionWillChange: self];
	[mercatorToViewProjection offsetView:delta];
	[imagesOnScreen moveBy:delta];
	[tileLoader moveBy:delta];
	[overlay moveBy:delta];
	[overlay correctPositionOfAllSublayers];
	if (_delegateHasMapViewRegionDidChange) [delegate mapViewRegionDidChange: self];
}


/// \bug magic strings embedded in code
- (void)animatedZoomStep:(NSTimer *)timer
{
	float zoomIncr = [[[timer userInfo] objectForKey:@"zoomIncr"] floatValue];
	float targetZoom = [[[timer userInfo] objectForKey:@"targetZoom"] floatValue];
	
	if ((zoomIncr > 0 && [self zoom] >= targetZoom) || (zoomIncr < 0 && [self zoom] <= targetZoom))
	{
		NSDictionary * userInfo = [[timer userInfo] retain];
		[timer invalidate];	// ASAP
		id<RMMapContentsAnimationCallback> callback = [userInfo objectForKey:@"callback"];
		if (callback && [callback respondsToSelector:@selector(animationFinishedWithZoomFactor:near:)]) {
			CGPoint pivot;
			CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)[userInfo objectForKey:@"pivot"], &pivot);
			[callback animationFinishedWithZoomFactor:targetZoom near:pivot];
		}
		[userInfo release];
	}
	else
	{
		float zoomFactorStep = exp2f(zoomIncr);
		
		CGPoint pivot;
		CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)[[timer userInfo] objectForKey:@"pivot"], &pivot);
		
		[self zoomByFactor:zoomFactorStep near:pivot animated:NO];
	}
}


- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center
{
	[self zoomByFactor:zoomFactor near:center animated:NO];
}
- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) center animated:(BOOL)animated
{
	if (_delegateHasBeforeMapZoomByFactor) [delegate beforeMapZoom: self byFactor: zoomFactor near: center];
	[self zoomByFactor:zoomFactor near:center animated:animated withCallback:(animated && _delegateHasAfterMapZoomByFactor)?self:nil];
	if (!animated)
		if (_delegateHasAfterMapZoomByFactor) [delegate afterMapZoom: self byFactor: zoomFactor near: center];
}

- (void)zoomByFactor: (double) zoomFactor near:(CGPoint) pivot animated:(BOOL) animated withCallback:(id<RMMapContentsAnimationCallback>)callback
{
	zoomFactor = [self adjustZoomForBoundingMask:zoomFactor];
	float zoomDelta = log2f(zoomFactor);
	float clampedZoom = [self zoom];
	float targetZoom = zoomDelta + clampedZoom;
	
	if (animated)
	{
		// goal is to complete the animation in animTime seconds
		static const float stepTime = kZoomAnimationStepTime;
		static const float animTime = kZoomAnimationAnimationTime;
		float nSteps = animTime / stepTime;
		float zoomIncr = zoomDelta / nSteps;
		
		CFDictionaryRef pivotDictionary = CGPointCreateDictionaryRepresentation(pivot);
		/// \bug magic string literals
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSNumber numberWithFloat:zoomIncr], @"zoomIncr", 
								  [NSNumber numberWithFloat:targetZoom], @"targetZoom", 
								  pivotDictionary, @"pivot", 
								  callback, @"callback", nil];
		CFRelease(pivotDictionary);
		[NSTimer scheduledTimerWithTimeInterval:stepTime
										 target:self 
									   selector:@selector(animatedZoomStep:) 
									   userInfo:userInfo
										repeats:YES];
	}
	else
	{
		if (targetZoom == [self zoom]){
			return;
		}
		// clamp zoom to remain below or equal to maxZoom after zoomAfter will be applied
		if(targetZoom > [self maxZoom]){
			zoomFactor = exp2f([self maxZoom] - clampedZoom);
		}
		
		//bools for syntactical sugar to understand the logic in the if statement below
		BOOL zoomAtMax = (clampedZoom == [self maxZoom]);
		BOOL zoomAtMin = (clampedZoom == [self minZoom]);
		BOOL zoomGreaterMin = (clampedZoom > [self minZoom]);
		BOOL zoomLessMax = (clampedZoom < [self maxZoom]);
		
		//zooming in zoomFactor > 1
		//zooming out zoomFactor < 1
		
		if ((zoomGreaterMin && zoomLessMax) || (zoomAtMax && zoomFactor<1) || (zoomAtMin && zoomFactor>1))
		{
			[mercatorToViewProjection zoomScreenByFactor:zoomFactor near:pivot];
			[imagesOnScreen zoomByFactor:zoomFactor near:pivot];
			[tileLoader zoomByFactor:zoomFactor near:pivot];
			[overlay zoomByFactor:zoomFactor near:pivot];
		}
		else
		{
			if(clampedZoom > [self maxZoom])
				[self setZoom:[self maxZoom]];
			if(clampedZoom < [self minZoom])
				[self setZoom:[self minZoom]];
		}
	}
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
		double viewBoundsWidth = [self viewBounds].size.width;
		double mapContentWidth;
		
		if ( newMapContentsWidth < viewBoundsWidth )
		{
			// Calculate new zoom facter so that it does not shrink the map any further. 
			mapContentWidth = mercatorBounds.size.width / self.metersPerPixel;
			zoomFactor = viewBoundsWidth / mapContentWidth;
			
			//newMPP = self.metersPerPixel / zoomFactor;
			//newMapContentsWidth = mercatorBounds.size.width / newMPP;
		}
		
	}
	
	// Check for MinHeightBound	
	if ( boundingMask & RMMapMinHeightBound )
	{
		double newMapContentsHeight = mercatorBounds.size.height / newMPP;
		double viewBoundsHeight = [self viewBounds].size.height;
		double mapContentHeight;
		
		if ( newMapContentsHeight < viewBoundsHeight )
		{
			// Calculate new zoom facter so that it does not shrink the map any further. 
			mapContentHeight = mercatorBounds.size.height / self.metersPerPixel;
			zoomFactor = viewBoundsHeight / mapContentHeight;
			
			//newMPP = self.metersPerPixel / zoomFactor;
			//newMapContentsHeight = mercatorBounds.size.height / newMPP;
		}
		
	}
	
	//[self adjustMapPlacementWithScale:newMPP];
	
	return zoomFactor;
}

#pragma mark RMMapContentsAnimationCallback methods

- (void)animationFinishedWithZoomFactor:(float)zoomFactor near:(CGPoint)p
{
	if (_delegateHasAfterMapZoomByFactor)
		[delegate afterMapZoom: self byFactor: zoomFactor near: p];
}


#pragma mark Event handling

- (RMGestureDetails) gestureDetails: (NSSet*) touches
{
	RMGestureDetails gesture;
	gesture.center.x = gesture.center.y = 0;
	gesture.averageDistanceFromCenter = 0;
	gesture.angle = 0.0;
	
	int interestingTouches = 0;
	
	for (UITouch *touch in touches)
	{
		if ([touch phase] != UITouchPhaseBegan
			&& [touch phase] != UITouchPhaseMoved
			&& [touch phase] != UITouchPhaseStationary)
			continue;
		//		RMLog(@"phase = %d", [touch phase]);
		
		interestingTouches++;
		
		CGPoint location = [touch locationInView: self];
		
		gesture.center.x += location.x;
		gesture.center.y += location.y;
	}
	
	if (interestingTouches == 0)
	{
		gesture.center = lastGesture.center;
		gesture.numTouches = 0;
		gesture.averageDistanceFromCenter = 0.0f;
		return gesture;
	}
	
	//	RMLog(@"interestingTouches = %d", interestingTouches);
	
	gesture.center.x /= interestingTouches;
	gesture.center.y /= interestingTouches;
	
	for (UITouch *touch in touches)
	{
		if ([touch phase] != UITouchPhaseBegan
			&& [touch phase] != UITouchPhaseMoved
			&& [touch phase] != UITouchPhaseStationary)
			continue;
		
		CGPoint location = [touch locationInView: self];
		
		//		RMLog(@"For touch at %.0f, %.0f:", location.x, location.y);
		float dx = location.x - gesture.center.x;
		float dy = location.y - gesture.center.y;
		//		RMLog(@"delta = %.0f, %.0f  distance = %f", dx, dy, sqrtf((dx*dx) + (dy*dy)));
		gesture.averageDistanceFromCenter += sqrtf((dx*dx) + (dy*dy));
	}

	gesture.averageDistanceFromCenter /= interestingTouches;
	
	gesture.numTouches = interestingTouches;

	if ([touches count] == 2)  
	{
		CGPoint first = [[[touches allObjects] objectAtIndex:0] locationInView:[self superview]];
		CGPoint second = [[[touches allObjects] objectAtIndex:1] locationInView:[self superview]];
		CGFloat height = second.y - first.y;
        CGFloat width = first.x - second.x;
        gesture.angle = atan2(height,width);
	}
	
	//RMLog(@"center = %.0f,%.0f dist = %f, angle = %f", gesture.center.x, gesture.center.y, gesture.averageDistanceFromCenter, gesture.angle);
	
	return gesture;
}

- (void)userPausedDragging
{
	[RMMapView setPerformExpensiveOperations:YES];
}

- (void)unRegisterPausedDraggingDispatcher
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(userPausedDragging) object:nil];
}

- (void)registerPausedDraggingDispatcher
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(userPausedDragging) object:nil];
	[self performSelector:@selector(userPausedDragging) withObject:nil afterDelay:0.3];	
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	//Check if the touch hit a RMMarker subclass and if so, forward the touch event on
	//so it can be handled there
	id furthestLayerDown = [self.overlay hitTest:[touch locationInView:self]];
	if ([[furthestLayerDown class]isSubclassOfClass: [RMMarker class]]) {
		if ([furthestLayerDown respondsToSelector:@selector(touchesBegan:withEvent:)]) {
			[furthestLayerDown performSelector:@selector(touchesBegan:withEvent:) withObject:touches withObject:event];
			return;
		}
	}
		
	if (lastGesture.numTouches == 0)
	{
		[RMMapView setPerformExpensiveOperations:NO];
	}
	
	//	RMLog(@"touchesBegan %d", [[event allTouches] count]);
	lastGesture = [self gestureDetails:[event allTouches]];

	if(deceleration)
	{
		if (_decelerationTimer != nil) {
			[self stopDeceleration];
		}
	}
	
	[self registerPausedDraggingDispatcher];
}

/// \bug touchesCancelled should clean up, not pass event to markers
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	
	//Check if the touch hit a RMMarker subclass and if so, forward the touch event on
	//so it can be handled there
	id furthestLayerDown = [self.overlay hitTest:[touch locationInView:self]];
	if ([[furthestLayerDown class]isSubclassOfClass: [RMMarker class]]) {
		if ([furthestLayerDown respondsToSelector:@selector(touchesCancelled:withEvent:)]) {
			[furthestLayerDown performSelector:@selector(touchesCancelled:withEvent:) withObject:touches withObject:event];
			return;
		}
	}

	// I don't understand what the difference between this and touchesEnded is.
	[self touchesEnded:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	
	//Check if the touch hit a RMMarker subclass and if so, forward the touch event on
	//so it can be handled there
	id furthestLayerDown = [self.overlay hitTest:[touch locationInView:self]];
	if ([[furthestLayerDown class]isSubclassOfClass: [RMMarker class]]) {
		if ([furthestLayerDown respondsToSelector:@selector(touchesEnded:withEvent:)]) {
			[furthestLayerDown performSelector:@selector(touchesEnded:withEvent:) withObject:touches withObject:event];
			return;
		}
	}
	NSInteger lastTouches = lastGesture.numTouches;
	
	// Calculate the gesture.
	lastGesture = [self gestureDetails:[event allTouches]];

	// If there are no more fingers on the screen, resume any slow operations.
	if (lastGesture.numTouches == 0)
	{
		[self unRegisterPausedDraggingDispatcher];
		// When factoring, beware these two instructions need to happen in this order.
		[RMMapView setPerformExpensiveOperations:YES];
	}

	if (touch.tapCount >= 2)
	{
		if (_delegateHasDoubleTapOnMap) {
			[delegate doubleTapOnMap: self At: lastGesture.center];
		} else {
			// Default behaviour matches built in maps.app
			float nextZoomFactor = [self nextNativeZoomFactor];
			if (nextZoomFactor != 0)
				[self zoomByFactor:nextZoomFactor near:[touch locationInView:self] animated:YES];
		}
	} else if (lastTouches == 1 && touch.tapCount != 1) {
		// deceleration
		if(deceleration && self.isScrollEnabled)
		{
			CGPoint prevLocation = [touch previousLocationInView:self];
			CGPoint currLocation = [touch locationInView:self];
			CGSize touchDelta = CGSizeMake(currLocation.x - prevLocation.x, currLocation.y - prevLocation.y);
			[self startDecelerationWithDelta:touchDelta];
		}
	}
	
	
	if (touch.tapCount == 1) 
	{
		if(lastGesture.numTouches == 0)
		{
			CALayer* hit = [self.overlay hitTest:[touch locationInView:self]];
			//		RMLog(@"LAYER of type %@",[hit description]);
			
			if (hit != nil) {
				CALayer *superlayer = [hit superlayer]; 
				
				// See if tap was on a marker or marker label and send delegate protocol method
				if ([hit isKindOfClass: [RMMarker class]]) {
					if (_delegateHasTapOnMarker) {
						[delegate tapOnMarker:(RMMarker*)hit onMap:self];
					}
				} else if (superlayer != nil && [superlayer isKindOfClass: [RMMarker class]]) {
					if (_delegateHasTapOnLabelForMarker) {
						[delegate tapOnLabelForMarker:(RMMarker*)superlayer onMap:self];
					}
				} else if ([superlayer superlayer] != nil && [[superlayer superlayer] isKindOfClass: [RMMarker class]]) {
                                        if (_delegateHasTapOnLabelForMarker) {
                                                [delegate tapOnLabelForMarker:(RMMarker*)[superlayer superlayer] onMap:self];
                                        } 
				} else if (_delegateHasSingleTapOnMap) {
					[delegate singleTapOnMap: self At: [touch locationInView:self]];
				}
			}
		}
		else if(!self.isScrollEnabled && (lastGesture.numTouches == 1))
		{
			float prevZoomFactor = [self prevNativeZoomFactor];
			if (prevZoomFactor != 0)
				[self zoomByFactor:prevZoomFactor near:[touch locationInView:self] animated:YES];
		}
	}
	
	if (_delegateHasAfterMapTouch) [delegate afterMapTouch: self];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	
	//Check if the touch hit a RMMarker subclass and if so, forward the touch event on
	//so it can be handled there
	CALayer *furthestLayerDown = [self.overlay hitTest:[touch locationInView:self]];
	if ([[furthestLayerDown class]isSubclassOfClass: [RMMarker class]]) {
		if ([furthestLayerDown respondsToSelector:@selector(touchesMoved:withEvent:)]) {
			[furthestLayerDown performSelector:@selector(touchesMoved:withEvent:) withObject:touches withObject:event];
			return;
		}
	}
		
	if (furthestLayerDown != nil) {
   
      if ([furthestLayerDown isKindOfClass: [RMMarker class]]) {
   
         if (!_delegateHasShouldDragMarker || (_delegateHasShouldDragMarker && [delegate mapView:self shouldDragMarker:(RMMarker*)furthestLayerDown withEvent:event])) {
            if (_delegateHasDidDragMarker) {
               [delegate mapView:self didDragMarker:(RMMarker*)furthestLayerDown withEvent:event];
               return;
            }
         }
      }
	}
	
	RMGestureDetails newGesture = [self gestureDetails:[event allTouches]];
	
	if(enableRotate && (newGesture.numTouches == lastGesture.numTouches))
	{
          if(newGesture.numTouches == 2)
          {
		CGFloat angleDiff = lastGesture.angle - newGesture.angle;
		CGFloat newAngle = self.rotation + angleDiff;
		
		[self setRotation:newAngle];
          }
	}
	
	if (self.isScrollEnabled && newGesture.numTouches == lastGesture.numTouches)
	{
		CGSize delta;
		delta.width = newGesture.center.x - lastGesture.center.x;
		delta.height = newGesture.center.y - lastGesture.center.y;
		
		[self moveBy:delta];
		if (self.isZoomEnabled && newGesture.numTouches > 1)
		{
			NSAssert (lastGesture.averageDistanceFromCenter > 0.0f && newGesture.averageDistanceFromCenter > 0.0f,
					  @"Distance from center is zero despite >1 touches on the screen");
			
			double zoomFactor = newGesture.averageDistanceFromCenter / lastGesture.averageDistanceFromCenter;
			
			[self zoomByFactor: zoomFactor near: newGesture.center];
		}
	}
	
	lastGesture = newGesture;
	
	[self registerPausedDraggingDispatcher];
}

#pragma mark Deceleration

- (void)startDecelerationWithDelta:(CGSize)delta {
	if (ABS(delta.width) >= 1.0f && ABS(delta.height) >= 1.0f) {
		_decelerationDelta = delta;
		_decelerationTimer = [NSTimer scheduledTimerWithTimeInterval:0.01f 
															 target:self
														   selector:@selector(incrementDeceleration:) 
														   userInfo:nil 
															repeats:YES];
	}
}

- (void)incrementDeceleration:(NSTimer *)timer {
	if (ABS(_decelerationDelta.width) < kMinDecelerationDelta && ABS(_decelerationDelta.height) < kMinDecelerationDelta) {
		[self stopDeceleration];
		return;
	}

	// avoid calling delegate methods? design call here
	[self moveBy:_decelerationDelta];

	_decelerationDelta.width *= [self decelerationFactor];
	_decelerationDelta.height *= [self decelerationFactor];
}

- (void)stopDeceleration {
	if (_decelerationTimer != nil) {
		[_decelerationTimer invalidate];
		_decelerationTimer = nil;
		_decelerationDelta = CGSizeZero;

		// call delegate methods; design call (see above)
		[self moveBy:CGSizeZero];
	}
}

- (void)handleMemoryWarningNotification:(NSNotification *)notification
{
	[self didReceiveMemoryWarning];
}

/// Must be called by higher didReceiveMemoryWarning
- (void)didReceiveMemoryWarning
{
	LogMethod();
	[tileSource didReceiveMemoryWarning];
}

- (void)setFrame:(CGRect)frame
{
  CGRect r = self.frame;
  [super setFrame:frame];
  // only change if the frame changes AND there is contents
//  if (!CGRectEqualToRect(r, frame) && contents) {
//    [contents setFrame:frame];
 // }
	if (!CGRectEqualToRect(r, frame)) {
		CGRect bounds = CGRectMake(0, 0, frame.size.width, frame.size.height);
		mercatorToViewProjection.viewBounds = bounds;
		background.frame = bounds;
		self.layer.frame = frame;
		overlay.frame = bounds;
		[tileLoader clearLoadedBounds];
		[tileLoader updateLoadedImages];
		[overlay correctPositionOfAllSublayers];
		
	}
	
}

- (void)setRotation:(float)angle
{
 	if (_delegateHasBeforeMapRotate) [delegate beforeMapRotate: self fromAngle: rotation];

	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.0f] forKey:kCATransactionAnimationDuration];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	rotation = angle;
		
	self.transform = CGAffineTransformMakeRotation(rotation);
	
	[overlay setRotationOfAllSublayers:(-angle)]; // rotate back markers and paths if theirs allowRotate=NO
	
	[CATransaction commit];

 	if (_delegateHasAfterMapRotate) [delegate afterMapRotate: self toAngle: rotation];
}



#pragma mark Contents start

#pragma mark Properties

- (void) setTileSource: (RMTileSource *)newTileSource
{
	if (tileSource == newTileSource)
		return;
	
	[tileSource release];
	tileSource = [newTileSource retain];
	
	[projection release];
	projection = [[tileSource projection] retain];
	
	[mercatorToTileProjection release];
	mercatorToTileProjection = [[tileSource mercatorToTileProjection] retain];
	
	[imagesOnScreen setTileSource:tileSource];
	
	[tileLoader reset];
	[tileLoader reload];
}

- (RMTileSource *) tileSource
{
	return [[tileSource retain] autorelease];
}

- (void) setRenderer: (RMMapRenderer*) newRenderer
{
	if (renderer == newRenderer)
		return;
	
	[imagesOnScreen setDelegate:newRenderer];
	
	[[renderer layer] removeFromSuperlayer];
	[renderer release];
	
	renderer = [newRenderer retain];
	
	if (renderer == nil)
		return;
	
	[[renderer layer] setFrame:[self viewBounds]];
	
	if (background != nil)
		[self.layer insertSublayer:[renderer layer] above:background];
	else if (overlay != nil)
		[self.layer insertSublayer:[renderer layer] below:overlay];
	else
		[self.layer insertSublayer:[renderer layer] atIndex: 0];
}

- (RMMapRenderer *)renderer
{
	return [[renderer retain] autorelease];
}

- (void) setBackground: (RMMapLayer*) aLayer
{
	if (background == aLayer) return;
	
	if (background != nil)
	{
		[background release];
		[background removeFromSuperlayer];		
	}
	
	background = [aLayer retain];
	
	if (background == nil)
		return;
	
	background.frame = [self viewBounds];
	
	if ([renderer layer] != nil)
		[self.layer insertSublayer:background below:[renderer layer]];
	else if (overlay != nil)
		[self.layer insertSublayer:background below:overlay];
	else
		[self.layer insertSublayer:[renderer layer] atIndex: 0];
}

- (RMMapLayer *)background
{
	return [[background retain] autorelease];
}

- (void) setOverlay: (RMLayerCollection*) aLayer
{
	if (overlay == aLayer) return;
	
	if (overlay != nil)
	{
		[overlay release];
		[overlay removeFromSuperlayer];		
	}
	
	overlay = [aLayer retain];
	
	if (overlay == nil)
		return;
	
	overlay.frame = [self viewBounds];
	
	if ([renderer layer] != nil)
		[self.layer insertSublayer:overlay above:[renderer layer]];
	else if (background != nil)
		[self.layer insertSublayer:overlay above:background];
	else
		[self.layer insertSublayer:[renderer layer] atIndex: 0];
	
	/* Test to make sure the overlay is working.
	 CALayer *testLayer = [[CALayer alloc] init];
	 
	 [testLayer setFrame:CGRectMake(100, 100, 200, 200)];
	 [testLayer setBackgroundColor:[[UIColor brownColor] CGColor]];
	 
	 RMLog(@"added test layer");
	 [overlay addSublayer:testLayer];*/
}



- (CLLocationCoordinate2D)centerCoordinate
{
	RMProjectedPoint aPoint = [mercatorToViewProjection projectedCenter];
	return [projection coordinateForProjectedPoint:aPoint];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)aCoordinate
{
	if (_delegateHasMapViewRegionWillChange)
		[delegate mapViewRegionWillChange: self];
	
	RMProjectedPoint aPoint = [[self projection] projectedPointForCoordinate:aCoordinate];
	self.centerProjectedPoint = aPoint;
	
	if (_delegateHasMapViewRegionDidChange)
		[delegate mapViewRegionDidChange: self];
}


- (RMProjectedPoint)centerProjectedPoint
{
	return [mercatorToViewProjection projectedCenter];
}

- (void)setCenterProjectedPoint:(RMProjectedPoint)aProjectedPoint
{
	if (_delegateHasMapViewRegionWillChange) [delegate mapViewRegionWillChange: self];
	[mercatorToViewProjection setProjectedCenter:aProjectedPoint];
	[overlay correctPositionOfAllSublayers];
	[tileLoader reload];
	[overlay setNeedsDisplay];
	if (_delegateHasMapViewRegionDidChange) [delegate mapViewRegionDidChange: self];
}



- (RMProjectedRect) visibleMapRect
{
	return [mercatorToViewProjection visibleProjectedRect];
}
- (void) setVisibleMapRect: (RMProjectedRect) aRect
{
	[mercatorToViewProjection setVisibleProjectedRect:aRect];
}

- (RMTileRect) tileBounds
{
	return [mercatorToTileProjection project: mercatorToViewProjection];
}

- (CGRect)viewBounds
{
	if (mercatorToViewProjection != nil)
		return mercatorToViewProjection.viewBounds;
	else
		return CGRectZero;
}

- (float) metersPerPixel
{
	return [mercatorToViewProjection metersPerPixel];
}

- (void) setMetersPerPixel: (float) newMPP
{
	float zoomFactor = newMPP / self.metersPerPixel;
	CGPoint pivot = CGPointZero;
	
	[mercatorToViewProjection setMetersPerPixel:newMPP];
	[imagesOnScreen zoomByFactor:zoomFactor near:pivot];
	[tileLoader zoomByFactor:zoomFactor near:pivot];
	[overlay zoomByFactor:zoomFactor near:pivot];
	[overlay correctPositionOfAllSublayers];
}

- (void)setMaxZoom:(float)newMaxZoom
{
	maxZoom = newMaxZoom;
}

- (void)setMinZoom:(float)newMinZoom
{
	minZoom = newMinZoom;
	
	NSAssert(!tileSource || (([tileSource minZoom] - minZoom) <= 1.0), @"Graphics & memory are overly taxed if [contents minZoom] is more than 1.5 smaller than [tileSource minZoom]");
}

- (float) zoom
{
	return [mercatorToTileProjection calculateZoomFromScale:[mercatorToViewProjection metersPerPixel]];
}

/// if #zoom is outside of range #minZoom to #maxZoom, zoom level is clamped to that range.
- (void) setZoom: (float) zoom
{
	zoom = (zoom > maxZoom) ? maxZoom : zoom;
	zoom = (zoom < minZoom) ? minZoom : zoom;
	
	float scale = [mercatorToTileProjection calculateScaleFromZoom:zoom];
	
	[self setMetersPerPixel:scale];
}

- (RMTileImageSet*) imagesOnScreen
{
	return [[imagesOnScreen retain] autorelease];
}

- (RMTileLoader*) tileLoader
{
	return [[tileLoader retain] autorelease];
}

- (RMProjection*) projection
{
	return [[projection retain] autorelease];
}
- (id<RMMercatorToTileProjection>) mercatorToTileProjection
{
	return [[mercatorToTileProjection retain] autorelease];
}
- (RMMercatorToViewProjection*) mercatorToViewProjection
{
	return [[mercatorToViewProjection retain] autorelease];
}


#pragma mark LatLng/Pixel translation functions

- (CGPoint)convertCoordinateToPoint:(CLLocationCoordinate2D)aCoordinate
{	
	return [mercatorToViewProjection convertProjectedPointToPoint:[projection projectedPointForCoordinate:aCoordinate]];
}

- (CGPoint)convertCoordinateToPoint:(CLLocationCoordinate2D)aCoordinate withMetersPerPixel:(float)aScale
{	
	return [mercatorToViewProjection convertProjectedPointToPoint:[projection projectedPointForCoordinate:aCoordinate] withMetersPerPixel:aScale];
}

- (RMTilePoint)convertCoordinateToTilePoint:(CLLocationCoordinate2D)aCoordinate withMetersPerPixel:(float)aScale
{
	return [mercatorToTileProjection convertProjectedPointToTilePoint:[projection projectedPointForCoordinate:aCoordinate] atZoom:aScale];
}

- (CLLocationCoordinate2D)convertPointToCoordinate:(CGPoint)aPoint
{
	return [projection coordinateForProjectedPoint:[mercatorToViewProjection convertPointToProjectedPoint:aPoint]];
}

- (CLLocationCoordinate2D)convertPointToCoordinate:(CGPoint)aPoint withMetersPerPixel:(float)aScale
{
	return [projection coordinateForProjectedPoint:[mercatorToViewProjection convertPointToProjectedPoint:aPoint withMetersPerPixel:aScale]];
}

- (double)scaleDenominator {
	double routemeMetersPerPixel = [self metersPerPixel];
	double iphoneMillimetersPerPixel = kiPhoneMilimeteresPerPixel;
	double truescaleDenominator =  routemeMetersPerPixel / (0.001 * iphoneMillimetersPerPixel) ;
	return truescaleDenominator;
}

#pragma mark Zoom With Bounds
- (void)zoomWithLatLngBoundsNorthEast:(CLLocationCoordinate2D)ne SouthWest:(CLLocationCoordinate2D)sw
{
	if(ne.latitude == sw.latitude && ne.longitude == sw.longitude)//There are no bounds, probably only one marker.
	{
		RMProjectedRect zoomRect;
		RMProjectedPoint myOrigin = [projection projectedPointForCoordinate:sw];
		//Default is with scale = 2.0 mercators/pixel
		zoomRect.size.width = [self viewBounds].size.width * 2.0;
		zoomRect.size.height = [self viewBounds].size.height * 2.0;
		myOrigin.easting = myOrigin.easting - (zoomRect.size.width / 2);
		myOrigin.northing = myOrigin.northing - (zoomRect.size.height / 2);
		zoomRect.origin = myOrigin;
		[self zoomWithRMMercatorRectBounds:zoomRect];
	}
	else
	{
		//convert ne/sw into RMMercatorRect and call zoomWithBounds
		float pixelBuffer = kZoomRectPixelBuffer;
		CLLocationCoordinate2D midpoint = {
			.latitude = (ne.latitude + sw.latitude) / 2,
			.longitude = (ne.longitude + sw.longitude) / 2
		};
		RMProjectedPoint myOrigin = [projection projectedPointForCoordinate:midpoint];
		RMProjectedPoint nePoint = [projection projectedPointForCoordinate:ne];
		RMProjectedPoint swPoint = [projection projectedPointForCoordinate:sw];
		RMProjectedPoint myPoint = {.easting = nePoint.easting - swPoint.easting, .northing = nePoint.northing - swPoint.northing};
		//Create the new zoom layout
		RMProjectedRect zoomRect;
		//Default is with scale = 2.0 mercators/pixel
		zoomRect.size.width = [self viewBounds].size.width * 2.0;
		zoomRect.size.height = [self viewBounds].size.height * 2.0;
		if((myPoint.easting / ([self viewBounds].size.width)) < (myPoint.northing / ([self viewBounds].size.height)))
		{
			if((myPoint.northing / ([self viewBounds].size.height - pixelBuffer)) > 1)
			{
				zoomRect.size.width = [self viewBounds].size.width * (myPoint.northing / ([self viewBounds].size.height - pixelBuffer));
				zoomRect.size.height = [self viewBounds].size.height * (myPoint.northing / ([self viewBounds].size.height - pixelBuffer));
			}
		}
		else
		{
			if((myPoint.easting / ([self viewBounds].size.width - pixelBuffer)) > 1)
			{
				zoomRect.size.width = [self viewBounds].size.width * (myPoint.easting / ([self viewBounds].size.width - pixelBuffer));
				zoomRect.size.height = [self viewBounds].size.height * (myPoint.easting / ([self viewBounds].size.width - pixelBuffer));
			}
		}
		myOrigin.easting = myOrigin.easting - (zoomRect.size.width / 2);
		myOrigin.northing = myOrigin.northing - (zoomRect.size.height / 2);
		RMLog(@"Origin is calculated at: %f, %f", [projection coordinateForProjectedPoint:myOrigin].latitude, [projection coordinateForProjectedPoint:myOrigin].longitude);
		/*It gets all messed up if our origin is lower than the lowest place on the map, so we check.
		 if(myOrigin.northing < -19971868.880409)
		 {
		 myOrigin.northing = -19971868.880409;
		 }*/
		zoomRect.origin = myOrigin;
		[self zoomWithRMMercatorRectBounds:zoomRect];
	}
}

- (void)zoomWithRMMercatorRectBounds:(RMProjectedRect)bounds
{
	[self setVisibleMapRect:bounds];
	[overlay correctPositionOfAllSublayers];
	[tileLoader clearLoadedBounds];
	[tileLoader updateLoadedImages];
}


#pragma mark Markers and overlays

// Move overlays stuff here - at the moment overlay stuff is above...

- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxForScreen
{
	CGRect rect = mercatorToViewProjection.viewBounds;
	
	return [self latitudeLongitudeBoundingBoxFor:rect];
}

- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxFor:(CGRect) rect
{	
	RMSphericalTrapezium boundingBox;
	CGPoint northwestScreen = rect.origin;
	
	CGPoint southeastScreen;
	southeastScreen.x = rect.origin.x + rect.size.width;
	southeastScreen.y = rect.origin.y + rect.size.height;
	
	CGPoint northeastScreen, southwestScreen;
	northeastScreen.x = southeastScreen.x;
	northeastScreen.y = northwestScreen.y;
	southwestScreen.x = northwestScreen.x;
	southwestScreen.y = southeastScreen.y;
	
	CLLocationCoordinate2D northeastLL, northwestLL, southeastLL, southwestLL;
	northeastLL = [self convertPointToCoordinate:northeastScreen];
	northwestLL = [self convertPointToCoordinate:northwestScreen];
	southeastLL = [self convertPointToCoordinate:southeastScreen];
	southwestLL = [self convertPointToCoordinate:southwestScreen];
	
	boundingBox.northeast.latitude = fmax(northeastLL.latitude, northwestLL.latitude);
	boundingBox.southwest.latitude = fmin(southeastLL.latitude, southwestLL.latitude);
	
	// westerly computations:
	// -179, -178 -> -179 (min)
	// -179, 179  -> 179 (max)
	if (fabs(northwestLL.longitude - southwestLL.longitude) <= kMaxLong)
		boundingBox.southwest.longitude = fmin(northwestLL.longitude, southwestLL.longitude);
	else
		boundingBox.southwest.longitude = fmax(northwestLL.longitude, southwestLL.longitude);
	
	if (fabs(northeastLL.longitude - southeastLL.longitude) <= kMaxLong)
		boundingBox.northeast.longitude = fmax(northeastLL.longitude, southeastLL.longitude);
	else
		boundingBox.northeast.longitude = fmin(northeastLL.longitude, southeastLL.longitude);
	
	return boundingBox;
}

- (void) tilesUpdatedRegion:(CGRect)region
{
	if(delegateHasRegionUpdate)
	{
		RMSphericalTrapezium locationBounds  = [self latitudeLongitudeBoundingBoxFor:region];
		[tilesUpdateDelegate regionUpdate:locationBounds];
	}
}

@dynamic tilesUpdateDelegate;

- (void) setTilesUpdateDelegate: (id<RMTilesUpdateDelegate>) _tilesUpdateDelegate
{
	if (tilesUpdateDelegate == _tilesUpdateDelegate) return;
	tilesUpdateDelegate= _tilesUpdateDelegate;
	//RMLog(@"Delegate type:%@",[(NSObject *) tilesUpdateDelegate description]);
	delegateHasRegionUpdate  = [(NSObject*) tilesUpdateDelegate respondsToSelector: @selector(regionUpdate:)];
}

- (id<RMTilesUpdateDelegate>) tilesUpdateDelegate
{
	return tilesUpdateDelegate;
}


- (void) printDebuggingInformation
{
	[imagesOnScreen printDebuggingInformation];
}

static BOOL _performExpensiveOperations = YES;
+ (BOOL) performExpensiveOperations
{
	return _performExpensiveOperations;
}
+ (void) setPerformExpensiveOperations: (BOOL)p
{
	if (p == _performExpensiveOperations)
		return;
	
	_performExpensiveOperations = p;
	
	if (p)
		[[NSNotificationCenter defaultCenter] postNotificationName:RMResumeExpensiveOperations object:self];
	else
		[[NSNotificationCenter defaultCenter] postNotificationName:RMSuspendExpensiveOperations object:self];
}

@end
