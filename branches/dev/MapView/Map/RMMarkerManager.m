//
//  RMMarkerManager.m
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

#import "RMMarkerManager.h"
#import "RMMercatorToViewProjection.h"
#import "RMProjection.h"
#import "RMLayerCollection.h"

@implementation RMMarkerManager

@synthesize mapView;

- (id)initWithMapView:(RMMapView *)aMapView;
{
	if (![super init])
		return nil;
	
	mapView = aMapView;
	
	rotationTransform = CGAffineTransformIdentity; 
	
	return self;
}

- (void)dealloc
{
	mapView = nil;
	[super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark 
#pragma mark Adding / Removing / Displaying Markers

/// place the (newly created) marker onto the map and take ownership of it
/// \bug should return the marker
- (void) addMarker: (RMMarker*)marker AtLatLong:(CLLocationCoordinate2D)point
{

	[marker setAffineTransform:rotationTransform];
	[marker setProjectedLocation:[[mapView projection]projectedPointForCoordinate:point]];
	[marker setPosition:[[mapView mercatorToViewProjection] convertProjectedPointToPoint:[[mapView projection] projectedPointForCoordinate:point]]];
	[[mapView overlay] addSublayer:marker];
}

/// \bug see http://code.google.com/p/route-me/issues/detail?id=75
/// (halmueller): I am skeptical about interactions of this code with paths
- (void) removeMarkers
{
	[[mapView overlay] setSublayers:[NSArray arrayWithObjects:nil]]; 
}

/// \bug this will hide path overlays too?
/// \deprecated syntactic sugar. Might have a place on RMMapView, but not on RMMarkerManager.
- (void) hideAllMarkers 
{
	[[mapView overlay] setHidden:YES];
}

/// \bug this will hide path overlays too?
/// \deprecated syntactic sugar. Might have a place on RMMapView, but not on RMMarkerManager.
- (void) unhideAllMarkers
{
	[[mapView overlay] setHidden:NO];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark 
#pragma mark Marker information

- (NSArray *)markers
{
	return [[mapView overlay] sublayers];
}

- (void) removeMarker:(RMMarker *)marker
{
	[[mapView overlay] removeSublayer:marker];
}

- (void) removeMarkers:(NSArray *)markers
{
	[[mapView overlay] removeSublayers:markers];
}

- (CGPoint) screenCoordinatesForMarker: (RMMarker *)marker
{
	return [[mapView mercatorToViewProjection] convertProjectedPointToPoint:[marker projectedLocation]];
}

- (CLLocationCoordinate2D) latitudeLongitudeForMarker: (RMMarker *) marker
{
	return [mapView convertPointToCoordinate:[self screenCoordinatesForMarker:marker]];
}

- (NSArray *) markersWithinScreenBounds
{
	NSMutableArray *markersInScreenBounds = [NSMutableArray array];
	CGRect rect = [[mapView mercatorToViewProjection] viewBounds];
	
	for (RMMarker *marker in [self markers]) {
		if ([self isMarker:marker withinBounds:rect]) {
			[markersInScreenBounds addObject:marker];
		}
	}
	
	return markersInScreenBounds;
}

- (BOOL) isMarkerWithinScreenBounds:(RMMarker*)marker
{
	return [self isMarker:marker withinBounds:[[mapView mercatorToViewProjection] viewBounds]];
}

/// \deprecated violates Objective-C naming rules
- (BOOL) isMarker:(RMMarker*)marker withinBounds:(CGRect)rect
{
	if (![self managingMarker:marker]) {
		return NO;
	}
	
	CGPoint markerCoord = [self screenCoordinatesForMarker:marker];
	
	if (   markerCoord.x > rect.origin.x
		&& markerCoord.x < rect.origin.x + rect.size.width
		&& markerCoord.y > rect.origin.y
		&& markerCoord.y < rect.origin.y + rect.size.height)
	{
		return YES;
	}
	return NO;
}

/// \deprecated violates Objective-C naming rules
- (BOOL) managingMarker:(RMMarker*)marker
{
	if (marker != nil && [[self markers] indexOfObject:marker] != NSNotFound) {
		return YES;
	}
	return NO;
}

- (void) moveMarker:(RMMarker *)marker AtLatLon:(RMLatLong)point
{
	[marker setProjectedLocation:[[mapView projection]projectedPointForCoordinate:point]];
	[marker setPosition:[[mapView mercatorToViewProjection] convertProjectedPointToPoint:[[mapView projection] projectedPointForCoordinate:point]]];
}

- (void) moveMarker:(RMMarker *)marker AtXY:(CGPoint)point
{
	[marker setProjectedLocation:[[mapView mercatorToViewProjection] convertPointToProjectedPoint:point]];
	[marker setPosition:point];
}

- (void)setRotation:(float)angle
{
  rotationTransform = CGAffineTransformMakeRotation(angle); // store rotation transform for subsequent markers

  for (RMMarker *marker in [self markers]) 
  {
	  [marker setAffineTransform:rotationTransform];
  }
}

@end
