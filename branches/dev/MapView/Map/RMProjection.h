//
//  RMProjection.h
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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "RMFoundation.h"
#import "RMLatLong.h"

/// Objective-C wrapper for PROJ4 map projection definitions.
@interface RMProjection : NSObject
{
	/// This is actually a PROJ4 projPJ, but it is typed as void* so the proj_api doesn't have to be included
	void*		internalProjection;
	
	/// the size of the earth, in projected units (meters, most often)
	RMProjectedRect	planetBounds;
	
	/// hardcoded to YES in #initWithString:InBounds:
	BOOL		projectionWrapsHorizontally;
}

@property (readonly) void* internalProjection;
@property (readonly) RMProjectedRect planetBounds;
@property (readwrite) BOOL projectionWrapsHorizontally;

- (id)initWithString:(NSString *)projectionArguments bounds:(RMProjectedRect)projectionBounds;

/// If #projectionWrapsHorizontally, returns #aPoint with its easting adjusted modulo Earth's diameter to be within projection's planetBounds. if !#projectionWrapsHorizontally, returns #aPoint unchanged.
- (RMProjectedPoint)wrapPointHorizontally:(RMProjectedPoint)aPoint;

/// applies #wrapPointHorizontally to aPoint, and then clamps northing (Y coordinate) to projection's planetBounds
- (RMProjectedPoint)constrainPointToBounds:(RMProjectedPoint)aPoint;

+ (RMProjection *)googleProjection;
+ (RMProjection *)EPSGLatLong;
+ (RMProjection *)OSGB;


- (RMLatLong)coordinateForProjectedPoint:(RMProjectedPoint)aPoint;
- (RMProjectedPoint)projectedPointForCoordinate:(RMLatLong)aLatLong;

@end
