//
//  WDZLocationManager.h
//  Background Location
//
//  Created by Collin Thomas on 9/9/15.
//  Copyright (c) 2015 WDZ LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@import CoreLocation;

@interface WDZLocationManager : NSObject <CLLocationManagerDelegate>

+(WDZLocationManager *) sharedInstance;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *currentLocation;
@property (strong, nonatomic) NSString *regionIdentifier;
@property (strong, nonatomic) NSString *regionState;
@property (strong, nonatomic) NSNumber *regionRadius;
@property (nonatomic) NSUInteger regionCount;
@property (strong, nonatomic) CLCircularRegion *region;
@property (strong, nonatomic) NSDate *locationUpdateStartTime;
- (void)startRequestingLocationUpdates;
- (void)stopRequestingLocationUpdates;
- (BOOL)checkLocationManager;
- (void)addRegion;
- (void)removeRegion:(CLRegion *)region;
- (void)removeAllRegions;
@end
