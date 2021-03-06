//
//  WDZLocationManager.m
//  Background Location
//
//  Created by Collin Thomas on 9/9/15.
//  Copyright (c) 2015 WDZ LLC. All rights reserved.
//

#import "WDZLocationManager.h"

#import <Parse/Parse.h>

@import UIKit;

@implementation WDZLocationManager

@synthesize locationManager;

+(WDZLocationManager *) sharedInstance
{
    static WDZLocationManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WDZLocationManager alloc]init];
    });
    return instance;
}

-(id) init
{
    self = [super init];
    //if(self != nil) {
    if(self)
    {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        // new for ios 9
        self.locationManager.allowsBackgroundLocationUpdates = YES;
        
        // 100 is probably the lowest you can go, 65 seems to be iphone 5 limit.
        // previously 130
        self.locationManager.desiredAccuracy = 250.00;
        
        // radius should be larger than the desiredAccuracy
        self.regionRadius = [NSNumber numberWithDouble:300.00];
        
        // if the radius is too big then set it to the max
        if (self.regionRadius > [NSNumber numberWithDouble:self.locationManager.maximumRegionMonitoringDistance]) {
            self.regionRadius = [NSNumber numberWithDouble:self.locationManager.maximumRegionMonitoringDistance];
        }
        
        // if you don't have one of these then likes to fire off a couple extra
        // location updates even though you've got one you like already and said stop.
        // we set it to 65 is the hardware limit it will give us best
        // possible without it firing extra updates.
        self.locationManager.distanceFilter = 65.00;
        //self.locationManager.distanceFilter = kCLDistanceFilterNone;
        
        [self.locationManager requestAlwaysAuthorization];
    }
    return self;
}

- (void)newRegionIdentifier {
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"hh:mm:ss.SSS"];
    dateString = [formatter stringFromDate:[NSDate date]];
    NSString *name = [NSString stringWithFormat:@"wdz-"];
    self.regionIdentifier = [name stringByAppendingString:dateString];
}

- (BOOL)checkLocationManager
{
    if(![CLLocationManager locationServicesEnabled])
    {
        [self showMessage:@"You need to enable Location Services"];
        return NO;
    }
    if(![CLLocationManager isMonitoringAvailableForClass:[CLRegion class]])
    {
        [self showMessage:@"Region monitoring is not available for this Class"];
        return NO;
    }
    if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied ||
       [CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted  )
    {
        [self showMessage:@"You need to authorize Location Services for the APP"];
        return NO;
    }
    return YES;
}

// 6.
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    NSLog(@"*** Exited Region - %@", region.identifier);
    [self saveLog:[NSString stringWithFormat:@"*** Exited Region - %@", region.identifier]];
    // 7.
    [self removeRegion:region];
    
    // 8.
    [self startRequestingLocationUpdates];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {

    NSLog(@"*** Region Failure - %@", [error localizedDescription]);
    [self saveLog:[NSString stringWithFormat:@"*** Region Failure - %@", [error localizedDescription]]];
    
    [self saveError:error];
    
    [self showMessage:@"Failure to monitor region"];
    
    // you could retry here
    //[self removeAllRegions];
    //[self startRequestingLocationUpdates];
}


- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"*** Location Failure - %@", [error localizedDescription]);
    [self saveLog:[NSString stringWithFormat:@"*** Location Failure - %@", [error localizedDescription]]];
    
    [self saveError:error];
    
    [self showMessage:@"We could not determine your location"];
}


// delegate method that gets called if a new region is being monitored.
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    NSLog(@"*** Now Monitoring Region - %@", region.identifier);
    [self saveLog:[NSString stringWithFormat:@"*** Now Monitoring Region - %@", region.identifier]];
    
    // Ask for state of currently monitored region
    // caused error. idk stackoverflow someone said they saw it too
    // 
    // kCLErrorDomain error 5.
    /*
    if (region) {
        [[[WDZLocationManager sharedInstance] locationManager] requestStateForRegion:region];
    }
    */
    [WDZLocationManager sharedInstance].regionCount = [[WDZLocationManager sharedInstance] locationManager].monitoredRegions.count;
    
    // save to parse
    [self saveRegion];
}

// delegate method that responds to requestStateForRegion
- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLCircularRegion *)region
{
    if (state == CLRegionStateInside)
    {
        self.regionState = @"inside";
    }
    else if (state == CLRegionStateOutside)
    {
        self.regionState = @"outside";
    }
    else if (state == CLRegionStateUnknown)
    {
        self.regionState = @"unknown";
    }
}

- (void)stopRequestingLocationUpdates
{
    NSLog(@"Stopping location updates");
    [self.locationManager stopUpdatingLocation];
}

- (void)startRequestingLocationUpdates
{
    NSLog(@"*** Starting location updates");
    if ([self checkLocationManager]) {
        
        self.locationUpdateStartTime = [NSDate date];
        
        [self.locationManager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray*)locations
{
    NSLog(@"-------- New Location Update --------");
    
    // location count
    NSLog(@"locations count %lu", (unsigned long)[locations count]);
    
    // how long did it take?
    NSTimeInterval secondsSince = [self.locationUpdateStartTime timeIntervalSinceNow] * -1;
    [self saveMsg:[NSString stringWithFormat:@"Seconds since update started %f", secondsSince]];
    NSLog(@"Seconds since update started %f", secondsSince);
    
    // did not return location
    if ([locations count] > 1) {
        return;
    }
    
    // get location
    CLLocation *location = [locations lastObject];
    
    // apple code
    // test horizontal accuracy for invalid measurement
    if (location.horizontalAccuracy < 0) {
        NSLog(@"horizontalAccuracy less than 0 - %f", location.horizontalAccuracy);
        return;
    }
    
    // print location coords
    NSLog(@"Latitude %+.6f, Longitude %+.6f\n",
          location.coordinate.latitude,
          location.coordinate.longitude);
    
    // accuracy
    NSLog(@"horizontalAccuracy - %f", location.horizontalAccuracy);
    
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    
    NSLog(@"*** App State: %ld", (long)appState);
    
    // UIApplicationStateActive = 0
    // UIApplicationStateInactive = 1
    // UIApplicationStateBackground = 2
    
    // not background
    if (appState != UIApplicationStateBackground) {

        NSLog(@"Not in Background");
        
        // compare last location wiht the newest if theres two
        if (locations.count > 1) {
            CLLocation *secondToLastLocation = [locations objectAtIndex:[locations count] - 1];
            
            CLLocationDistance distance = [secondToLastLocation distanceFromLocation:location];
            
            NSLog(@"Distance - %f", distance);
            
            NSLog(@"LLLatitude %+.6f, LLLLongitude %+.6f\n",
                  secondToLastLocation.coordinate.latitude,
                  secondToLastLocation.coordinate.longitude);
            
            // region radius
            // had this set at 200, but didn't know about this cool doubleValue method
            // to be honest this doesn't seem like a great idea to do while in the background.
            // we're saying they haven't traveled outside the region go again
            if (distance <= 200) {
                //if (distance <= [self.regionRadius doubleValue]) {
                NSLog(@"the distance between the last two location is not great enough");
                return;
            }
        }
        
        // apple code
        // test age to make sure it is not cached
        // locationAge is measured in seconds
        // was using 10, but everyone seems to use 5
        NSTimeInterval locationAge = -[location.timestamp timeIntervalSinceNow];
        NSLog(@"locationAge - %f", locationAge);
        if (locationAge > 5.0) {
            NSLog(@"location was too old");
            return;
        }
        
        // true if the new location's accuracy is closer in meters than what we've defined
        if (location.horizontalAccuracy >= self.locationManager.desiredAccuracy) {
            return;
        }
    } else {
        [self saveMsg:@"In Background"];
    }
    
    NSLog(@"*** New location obtained - %f, %f", location.coordinate.latitude, location.coordinate.longitude);
    
    [self saveLog:[NSString stringWithFormat:@"*** New location obtained - %f, %f", location.coordinate.latitude, location.coordinate.longitude]];
    
    // set locationmanager property
    self.currentLocation = location;
    
    // 2.
    [self stopRequestingLocationUpdates];
    
    // 3.
    [self addRegion];
    
}

- (CLCircularRegion*)dictToRegion:(NSDictionary*)dictionary
{
    NSString *identifier = [dictionary valueForKey:@"identifier"];
    CLLocationDegrees latitude = [[dictionary valueForKey:@"latitude"] doubleValue];
    CLLocationDegrees longitude =[[dictionary valueForKey:@"longitude"] doubleValue];
    CLLocationDistance regionRadius = [[dictionary valueForKey:@"radius"] doubleValue];
    
    CLLocationCoordinate2D centerCoordinate = CLLocationCoordinate2DMake(latitude, longitude);
    
    if(regionRadius > self.locationManager.maximumRegionMonitoringDistance)
    {
        regionRadius = self.locationManager.maximumRegionMonitoringDistance;
    }
    
    CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:centerCoordinate
                                                                radius:regionRadius
                                                            identifier:identifier];
    
    return region;
}

-(void) showMessage:(NSString *) message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Geofence"
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:Nil, nil];
    
    alertView.alertViewStyle = UIAlertViewStyleDefault;
    
    [alertView show];
}

- (void)addRegion
{
    // 4.
    
    // make sure there isn't a region already being monitored by us
    // safe gaurd from multiple location updates creating multiple regions
    // things like mapkit regions/user tracking can fire off a lot of location updates
    if ([self.locationManager.monitoredRegions allObjects].count != 0) {
        NSLog(@"Region is already being montiored - %@ ", self.regionIdentifier);
        return;
    }
    
    CLLocationCoordinate2D coordiate = self.currentLocation.coordinate;
    
    [self newRegionIdentifier];
    
    NSDictionary *regionDictionary = @{
        @"identifier" : self.regionIdentifier,
        @"latitude" : [NSNumber numberWithDouble:(double)coordiate.latitude],
        @"longitude" : [NSNumber numberWithDouble:(double)coordiate.longitude],
        @"radius" : self.regionRadius};
    
    CLCircularRegion *region = [self dictToRegion:regionDictionary];
    
    self.region = region;
    
    region.notifyOnEntry = NO;
    region.notifyOnExit = YES;
    
    
    // 5.
    [self.locationManager startMonitoringForRegion:region];
    
    NSLog(@"Started Monitoing Region - %@", region.identifier);
}

- (void)removeRegion:(CLRegion *)region
{
    // stop monitoring
    [self.locationManager stopMonitoringForRegion:region];
    
    [WDZLocationManager sharedInstance].regionCount = [[WDZLocationManager sharedInstance] locationManager].monitoredRegions.count;
    
    NSLog(@"*** Stopped Monitoing Region - %@", region.identifier);
    [self saveLog:[NSString stringWithFormat:@"*** Stopped Monitoing Region - %@", region.identifier]];
}

- (void)removeAllRegions
{
    NSArray * monitoredRegions = [self.locationManager.monitoredRegions allObjects];
    
    for(CLRegion *region in monitoredRegions) {
        [self.locationManager stopMonitoringForRegion:region];
        NSLog(@"Stopped Monitoing Region - %@", region.identifier);
    }
    
    [WDZLocationManager sharedInstance].regionCount = [[WDZLocationManager sharedInstance] locationManager].monitoredRegions.count;
}

- (void)testNetworking
{
    // NSURL
    NSURL *url = [NSURL URLWithString:@"http://jsonplaceholder.typicode.com/posts/1"];
    
    // URLRequest
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];

    // Queue
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:queue completionHandler:^(NSURLResponse *response,NSData *data, NSError *error) {
        
        if ([data length] >0 && error == nil) {
            NSString* newStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"%@", newStr);
        } else if ([data length] == 0 && error == nil) {
            NSLog(@"Nothing was downloaded.");
        } else if (error != nil) {
            NSLog(@"Error = %@", error);
        }
    }];
}

- (void)saveRegion
{
    
    NSString *lat = [NSString stringWithFormat:@"%+.6f", self.locationManager.location.coordinate.latitude];
    NSString *lng = [NSString stringWithFormat:@"%+.6f", self.locationManager.location.coordinate.longitude];
    
    PFObject *region = [PFObject objectWithClassName:@"Regions"];
    region[@"lat"] = lat;
    region[@"lng"] = lng;
    region[@"region"] = self.regionIdentifier;
    region[@"info"] = @"myIphone";
    
    [region saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"succcess saving to parse");
        } else {
            NSLog(@"parse error - %@", error.description);
        }
    }];
    
}

- (void)saveLog:(NSString *)message
{
    
    PFObject *logObj = [PFObject objectWithClassName:@"Log"];
    logObj[@"message"] = message;
    logObj[@"info"] = @"myIphone";
    //[logObj saveInBackground];
    
}

- (void)saveError:(NSError *)error
{
    
    if ([error localizedDescription] != nil) {
        PFObject *err = [PFObject objectWithClassName:@"Errors"];
        err[@"desc"] = [error localizedDescription];
        [err saveInBackground];
    }
    
}

- (void)saveMsg:(NSString *)message
{
    
    PFObject *msg = [PFObject objectWithClassName:@"Msg"];
    msg[@"message"] = message;
    msg[@"info"] = @"myIphone";
    [msg saveInBackground];
    
}

@end
