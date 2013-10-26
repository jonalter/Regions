/*
     File: RegionsViewController.m
 Abstract: This controller manages the CLLocationManager for location updates and switches the interface between showing the region map and the updates table list. This controller also manages adding and removing regions to be monitored by the application.
  Version: 1.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 
 */

#import "RegionsViewController.h"
#import "RegionAnnotationView.h"
#import "RegionAnnotation.h"

#import "Cocoafish.h"
#import "SettingsViewController.h"
#import "FileLogger.h"

@implementation RegionsViewController

@synthesize regionsMapView, updatesTableView, updateEvents, locationManager, navigationBar;

#pragma mark - Memory management

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (void)dealloc {
	[updateEvents release];
	self.locationManager.delegate = nil;
	[locationManager release];
	[regionsMapView release];
	[updatesTableView release];
	[navigationBar release];
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self userLogin];
    
    regionCount = 0;
    lastSavedLocation = nil;
    smallRegionsAdded = NO;
    addingSmallRegions = NO;
    self.annotations = nil;
    self.smallRegions = nil;
    self.largeRegions = nil;
	
	// Create empty array to add region events to.
	updateEvents = [[NSMutableArray alloc] initWithCapacity:0];
	
	// Create location manager with filters set for battery efficiency.
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	locationManager.distanceFilter = kCLLocationAccuracyHundredMeters;
	locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	
	// Start updating location changes.
	[locationManager startUpdatingLocation];
}


- (void)viewDidAppear:(BOOL)animated {
	// Get all regions being monitored for this application.
	NSArray *regions = [[locationManager monitoredRegions] allObjects];
	
	// Iterate through the regions and add annotations to the map for each of them.
	for (int i = 0; i < [regions count]; i++) {
		CLRegion *region = [regions objectAtIndex:i];
		RegionAnnotation *annotation = [[RegionAnnotation alloc] initWithCLRegion:region];
//		[regionsMapView addAnnotation:annotation];
        [self addAnnotationToMap:annotation];
		[annotation release];
	}
}


- (void)viewDidUnload {
	self.updateEvents = nil;
	self.locationManager.delegate = nil;
	self.locationManager = nil;
	self.regionsMapView = nil;
	self.updatesTableView = nil;
	self.navigationBar = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [updateEvents count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
    }
    
	cell.textLabel.font = [UIFont systemFontOfSize:12.0];
	cell.textLabel.text = [updateEvents objectAtIndex:indexPath.row];
	cell.textLabel.numberOfLines = 4;
	
    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 60.0;
}


#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {	
	if([annotation isKindOfClass:[RegionAnnotation class]]) {
		RegionAnnotation *currentAnnotation = (RegionAnnotation *)annotation;
		NSString *annotationIdentifier = [currentAnnotation title];
		RegionAnnotationView *regionView = (RegionAnnotationView *)[regionsMapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];	
		
		if (!regionView) {
			regionView = [[[RegionAnnotationView alloc] initWithAnnotation:annotation] autorelease];
			regionView.map = regionsMapView;
			
			// Create a button for the left callout accessory view of each annotation to remove the annotation and region being monitored.
			UIButton *removeRegionButton = [UIButton buttonWithType:UIButtonTypeCustom];
			[removeRegionButton setFrame:CGRectMake(0., 0., 25., 25.)];
			[removeRegionButton setImage:[UIImage imageNamed:@"RemoveRegion"] forState:UIControlStateNormal];
			
			regionView.leftCalloutAccessoryView = removeRegionButton;
		} else {		
			regionView.annotation = annotation;
			regionView.theAnnotation = annotation;
		}
		
		// Update or add the overlay displaying the radius of the region around the annotation.
		[regionView updateRadiusOverlay];
        
		return regionView;		
	}	
	
	return nil;	
}


- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {
	if([overlay isKindOfClass:[MKCircle class]]) {
		// Create the view for the radius overlay.
		MKCircleView *circleView = [[[MKCircleView alloc] initWithOverlay:overlay] autorelease];
		circleView.strokeColor = [UIColor purpleColor];
		circleView.fillColor = [[UIColor purpleColor] colorWithAlphaComponent:0.4];
		
		return circleView;		
	}
	
	return nil;
}


- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
	if([annotationView isKindOfClass:[RegionAnnotationView class]]) {
		RegionAnnotationView *regionView = (RegionAnnotationView *)annotationView;
		RegionAnnotation *regionAnnotation = (RegionAnnotation *)regionView.annotation;
		
		// If the annotation view is starting to be dragged, remove the overlay and stop monitoring the region.
		if (newState == MKAnnotationViewDragStateStarting) {		
			[regionView removeRadiusOverlay];
			
			[locationManager stopMonitoringForRegion:regionAnnotation.region];
		}
		
		// Once the annotation view has been dragged and placed in a new location, update and add the overlay and begin monitoring the new region.
		if (oldState == MKAnnotationViewDragStateDragging && newState == MKAnnotationViewDragStateEnding) {
			[regionView updateRadiusOverlay];
			
			CLRegion *newRegion = [[CLRegion alloc] initCircularRegionWithCenter:regionAnnotation.coordinate radius:1000.0 identifier:[NSString stringWithFormat:@"%f, %f", regionAnnotation.coordinate.latitude, regionAnnotation.coordinate.longitude]];
			regionAnnotation.region = newRegion;
			[newRegion release];
			
			[locationManager startMonitoringForRegion:regionAnnotation.region desiredAccuracy:kCLLocationAccuracyBest];
		}		
	}	
}


- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
	RegionAnnotationView *regionView = (RegionAnnotationView *)view;
	RegionAnnotation *regionAnnotation = (RegionAnnotation *)regionView.annotation;
	
	// Stop monitoring the region, remove the radius overlay, and finally remove the annotation from the map.
	[locationManager stopMonitoringForRegion:regionAnnotation.region];
	[regionView removeRadiusOverlay];
	[regionsMapView removeAnnotation:regionAnnotation];
}


#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSLog(@"didFailWithError: %@", error);
}


- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
//	NSLog(@"didUpdateToLocation %@ from %@", newLocation, oldLocation);
	
	// Work around a bug in MapKit where user location is not initially zoomed to.
	if (oldLocation == nil) {
		// Zoom to the current user location.
		MKCoordinateRegion userLocation = MKCoordinateRegionMakeWithDistance(newLocation.coordinate, 1500.0, 1500.0);
		[regionsMapView setRegion:userLocation animated:YES];
	}
    
    NSArray *regions = [[locationManager monitoredRegions] allObjects];
	for (int i = 0; i < [regions count]; i++) {
		CLRegion *region = [regions objectAtIndex:i];
		if ([region containsCoordinate:newLocation.coordinate] && !smallRegionsAdded) {
            [self getPlacesAroundCoordinate:region.center withTag:@"small"];
        }
	}
    
    
    
    // BUGBUG remove: only for saveing new locations to ACS
//    if (lastSavedLocation == nil || [newLocation distanceFromLocation:lastSavedLocation] >= 5000.0 ) {
//        // Create new region and save to the server
//        if (lastSavedLocation) {
//            [lastSavedLocation release];
//        }
//        lastSavedLocation = [newLocation retain];
//        
//        CLRegion *newRegion = [self monitorRegionAtCoordinates:newLocation.coordinate];
//		
//        // Adding place to ACS
//        if (newRegion) {
//            [self addPlace:newRegion.identifier withCoordinate:newRegion.center];
//        }
//    }
}


- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region  {
	NSString *event = [NSString stringWithFormat:@"didEnterRegion %@ at %@", region.identifier, [NSDate date]];
	
	[self updateWithEvent:event];
    
    if ([region.identifier hasPrefix:@"L"]) {
        // LARGE
        // Pull small regions for this large region from ACS
        [self getPlacesAroundCoordinate:region.center withTag:@"small"];
    } else {
        // SMALL
        // Log to ACS
        
    }
}


- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
	NSString *event = [NSString stringWithFormat:@"didExitRegion %@ at %@", region.identifier, [NSDate date]];
	
	[self updateWithEvent:event];
    
    if ([region.identifier hasPrefix:@"L"]) {
        // LARGE
        // pull large regions closest to current location
        [self getPlacesAroundCoordinate:manager.location.coordinate withTag:@"large"];
    }
}


- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
	NSString *event = [NSString stringWithFormat:@"monitoringDidFailForRegion %@: %@", region.identifier, error];
	
	[self updateWithEvent:event];
}


#pragma mark - RegionsViewController

/*
 This method swaps the visibility of the map view and the table of region events.
 The "add region" button in the navigation bar is also altered to only be enabled when the map is shown.
 */
- (IBAction)switchViews {
	// Swap the hidden status of the map and table view so that the appropriate one is now showing.
	self.regionsMapView.hidden = !self.regionsMapView.hidden;
	self.updatesTableView.hidden = !self.updatesTableView.hidden;
	
	// Adjust the "add region" button to only be enabled when the map is shown.
	NSArray *navigationBarItems = [NSArray arrayWithArray:self.navigationBar.items];
	UIBarButtonItem *addRegionButton = [[navigationBarItems objectAtIndex:0] rightBarButtonItem];
	addRegionButton.enabled = !addRegionButton.enabled;
	
	// Reload the table data and update the icon badge number when the table view is shown.
	if (!updatesTableView.hidden) {
		[updatesTableView reloadData];
	}
}

/*
 This method creates a new region based on the center coordinate of the map view.
 A new annotation is created to represent the region and then the application starts monitoring the new region.
 */
- (IBAction)addRegion {
//	if ([CLLocationManager regionMonitoringAvailable]) {
//		// Create a new region based on the center of the map view.
//		CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(regionsMapView.centerCoordinate.latitude, regionsMapView.centerCoordinate.longitude);
//		CLRegion *newRegion = [[CLRegion alloc] initCircularRegionWithCenter:coord 
//																	  radius:1000.0
//																  identifier:[NSString stringWithFormat:@"%f, %f", regionsMapView.centerCoordinate.latitude, regionsMapView.centerCoordinate.longitude]];
//		
//		// Create an annotation to show where the region is located on the map.
//		RegionAnnotation *myRegionAnnotation = [[RegionAnnotation alloc] initWithCLRegion:newRegion];
//		myRegionAnnotation.coordinate = newRegion.center;
//		myRegionAnnotation.radius = newRegion.radius;
//		
//		[regionsMapView addAnnotation:myRegionAnnotation];
//		
//		[myRegionAnnotation release];
//		
//		// Start monitoring the newly created region.
//		[locationManager startMonitoringForRegion:newRegion desiredAccuracy:kCLLocationAccuracyBest];
        
//    CLRegion *newRegion = [self monitorRegionAtCoordinates:CLLocationCoordinate2DMake(regionsMapView.centerCoordinate.latitude, regionsMapView.centerCoordinate.longitude)];
		
        // Adding place to ACS
//    if (newRegion) {
//        [self addPlace:newRegion.identifier withCoordinate:newRegion.center];
//    }
    
        
//		[newRegion release];
//	}
//	else {
//		NSLog(@"Region monitoring is not available.");
//	}
}

//- (CLRegion*)monitorRegionAtCoordinates:(CLLocationCoordinate2D)coord {
//    if ([CLLocationManager regionMonitoringAvailable]) {
//        // Create a new region based on the center of the map view.
//        CLRegion *newRegion = [[CLRegion alloc] initCircularRegionWithCenter:coord
//                                                                      radius:2500.0
//                                                                  identifier:[NSString stringWithFormat:@"L#%d - %f, %f", regionCount, coord.latitude, coord.longitude]];
//        
//        regionCount++;
//        
//        // Create an annotation to show where the region is located on the map.
//        RegionAnnotation *myRegionAnnotation = [[RegionAnnotation alloc] initWithCLRegion:newRegion];
//        myRegionAnnotation.coordinate = newRegion.center;
//        myRegionAnnotation.radius = newRegion.radius;
//        myRegionAnnotation.title = newRegion.identifier;
//        
////        [regionsMapView addAnnotation:myRegionAnnotation];
//        [self addAnnotationToMap:myRegionAnnotation];
//        
//        if (!self.annotations) {
//            self.annotations = [NSMutableArray arrayWithCapacity:1];
//        }
//        [self.annotations addObject:myRegionAnnotation];
//
//        [myRegionAnnotation release];
//        
//        // BUGBUG: re-add this - Start monitoring the newly created region.
//        [locationManager startMonitoringForRegion:newRegion desiredAccuracy:kCLLocationAccuracyBest];
//        
//        return [newRegion autorelease];
//    }
//	else {
//		NSLog(@"Region monitoring is not available.");
//        return nil;
//	}
//}

- (CLRegion*)monitorRegionAtCoordinates:(CLLocationCoordinate2D)coord withName:(NSString*)name withTag:(NSString*)tagName {
    if ([CLLocationManager regionMonitoringAvailable]) {
        
        float radius = 0.0;
//        NSString *identifier = [NSString stringWithFormat:@"#%d - %f, %f", regionCount, coord.latitude, coord.longitude];
        
        if ([tagName isEqualToString:@"small"]) {
            radius = 125.0;
        } else if ([tagName isEqualToString:@"large"]) {
            radius = 2500;
//            identifier = [NSString stringWithFormat:@"L%@", identifier];
        }
        
        CLRegion *newRegion = [[CLRegion alloc] initCircularRegionWithCenter:coord
                                                                      radius:radius
                                                                  identifier:name];
        
        // Create an annotation to show where the region is located on the map.
        RegionAnnotation *myRegionAnnotation = [[RegionAnnotation alloc] initWithCLRegion:newRegion];
        myRegionAnnotation.coordinate = newRegion.center;
        myRegionAnnotation.radius = newRegion.radius;
        myRegionAnnotation.title = newRegion.identifier;
        
//        [regionsMapView addAnnotation:myRegionAnnotation];
        [self addAnnotationToMap:myRegionAnnotation];
        
        [myRegionAnnotation release];
        
        // BUGBUG: re-add this - Start monitoring the newly created region.
        [locationManager startMonitoringForRegion:newRegion];
        
        return [newRegion autorelease];
    }
	else {
		NSLog(@"Region monitoring is not available.");
        return nil;
	}
}

- (IBAction)testButtonClicked {
    FLog(@"Test Clicked");
    
//    [self getPlacesAroundCoordinate:CLLocationCoordinate2DMake(37.4149, -122.2065) setRegions:YES];
    
//    SettingsViewController *settingsViewController = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
//    [self presentViewController:settingsViewController animated:YES completion:nil];
    
//    [self getPlacesAroundCoordinate:CLLocationCoordinate2DMake(37.4149, -122.2065) withTag:@"small"];
    
    [self getPlacesAroundCoordinate:locationManager.location.coordinate withTag:@"large"];
//    [self stopMonitoringAllRegions];
}

#pragma mark Utils

- (void)addAnnotationToMap:(RegionAnnotation*)anno {
    if ([anno.title hasPrefix:@"L"]) {
        // Large
        if (!self.largeRegions) {
            self.largeRegions = [NSMutableArray arrayWithCapacity:1];
        }
        [self.largeRegions addObject:anno];
    } else {
        // Small
        if (!self.smallRegions) {
            self.smallRegions = [NSMutableArray arrayWithCapacity:1];
        }
        [self.smallRegions addObject:anno];
    }
    
//    if (!self.annotations) {
//        self.annotations = [NSMutableArray arrayWithCapacity:1];
//    }
//    [self.annotations addObject:anno];
    
    
    [regionsMapView addAnnotation:anno];
}

- (void)stopMonitoringAllRegions {
    // Stop all small regions first
    [self stopMonitoringSmallRegions];
    
    // Get all regions being monitored for this application.
	NSArray *regions = [[locationManager monitoredRegions] allObjects];
	
	// Iterate through the regions and add annotations to the map for each of them.
	for (int i = 0; i < [regions count]; i++) {
		CLRegion *region = [regions objectAtIndex:i];
		[locationManager stopMonitoringForRegion:region];
	}
    
    while ([self.largeRegions count] > 0) {
        
        RegionAnnotation *regionAnnotation = (RegionAnnotation *)[self.largeRegions lastObject];
        [self.largeRegions removeLastObject];
        
        RegionAnnotationView *regionView = (RegionAnnotationView *)[regionsMapView viewForAnnotation:regionAnnotation] ;
        
        [regionView removeRadiusOverlay];
        [regionsMapView removeAnnotation:regionAnnotation];
        
    }
}

- (void)stopMonitoringSmallRegions {
    // Get all regions being monitored for this application.
	NSArray *regions = [[locationManager monitoredRegions] allObjects];
	
	// Iterate through the regions and add annotations to the map for each of them.
	for (int i = 0; i < [regions count]; i++) {
		CLRegion *region = [regions objectAtIndex:i];
        if (![region.identifier hasPrefix:@"L"]) {
            // Small
            [locationManager stopMonitoringForRegion:region];
        }
	}
    
    while ([self.smallRegions count] > 0) {
        
        RegionAnnotation *regionAnnotation = (RegionAnnotation *)[self.smallRegions lastObject];
        [self.smallRegions removeLastObject];
        
        RegionAnnotationView *regionView = (RegionAnnotationView *)[regionsMapView viewForAnnotation:regionAnnotation] ;
        
        [regionView removeRadiusOverlay];
        [regionsMapView removeAnnotation:regionAnnotation];
        
    }
    
    smallRegionsAdded = NO;
}


#pragma mark ACS

- (void)userLogin {
    NSDictionary *paramDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"admin", @"login",
                               @"pass", @"password",
                               nil];
    // make a http call
    CCRequest *request = [[[CCRequest alloc] initHttpsWithDelegate:self httpMethod:@"POST" baseUrl:@"users/login.json" paramDict:paramDict] autorelease];
    [request startAsynchronous];
}

- (void)logStatus {
    
}

- (void)addPlace:(NSString*)name withCoordinate:(CLLocationCoordinate2D)coord {
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [paramDict setObject:name forKey:@"name"];
    [paramDict setObject:[NSString stringWithFormat:@"%lf", coord.latitude] forKey:@"latitude"];
    [paramDict setObject:[NSString stringWithFormat:@"%lf", coord.longitude] forKey:@"longitude"];
    [paramDict setObject:@"large" forKey:@"tags"];
    CCRequest *request = [[CCRequest alloc] initWithDelegate:self httpMethod:@"POST" baseUrl:@"places/create.json" paramDict:paramDict];
    [request startAsynchronous];
    [request release];
}

- (void)getPlacesAroundCoordinate:(CLLocationCoordinate2D)coord setRegions:(BOOL)setRegions {
    NSDictionary *paramDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSString stringWithFormat:@"%lf", coord.latitude], @"latitude",
                               [NSString stringWithFormat:@"%lf", coord.longitude], @"longitude",
                               @"15", @"per_page",
                               @"1000", @"distance",
                               nil];
    CCRequest *request = [[CCRequest alloc] initWithDelegate:self httpMethod:@"GET" baseUrl:@"places/search.json" paramDict:paramDict];
    
    if (setRegions) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"true", @"setRegions", nil];
        [request setUserInfo:userInfo];
    }
    [request startAsynchronous];
    [request release];
}

- (void)getPlacesAroundCoordinate:(CLLocationCoordinate2D)coord withTag:(NSString*)tagName {
    NSString *lat = [NSString stringWithFormat:@"%lf", coord.latitude];
    NSString *lon = [NSString stringWithFormat:@"%lf", coord.longitude];
    NSLog(@"Getting '%@' Regions around: %@, %@", tagName, lat, lon);
    
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [paramDict setObject:lat forKey:@"latitude"];
    [paramDict setObject:lon forKey:@"longitude"];

    [paramDict setObject:tagName forKey:@"q"];
    
    if ([tagName isEqualToString:@"small"]) {
        [paramDict setObject:@"15" forKey:@"per_page"];
        [paramDict setObject:@"3" forKey:@"distance"];
        addingSmallRegions = YES;
    } else if ([tagName isEqualToString:@"large"]) {
        [paramDict setObject:@"5" forKey:@"per_page"];
        [paramDict setObject:@"10" forKey:@"distance"];
    }

    
    CCRequest *request = [[CCRequest alloc] initWithDelegate:self httpMethod:@"GET" baseUrl:@"places/search.json" paramDict:paramDict];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:tagName, @"tagName", nil];
    [request setUserInfo:userInfo];
    
    [request startAsynchronous];
    [request release];
}

- (void)removePlaceWithId:(NSString*)placeId {
    NSDictionary *paramDict = [NSDictionary dictionaryWithObjectsAndKeys:placeId, @"place_id", nil];
    CCRequest *request = [[CCRequest alloc] initWithDelegate:self httpMethod:@"DELETE" baseUrl:@"places/delete.json" paramDict:paramDict];
    [request startAsynchronous];
    [request release];
}

#pragma mark -
#pragma mark CCRequest delegate methods
-(void)ccrequest:(CCRequest *)request didSucceed:(CCResponse *)response
{
    NSLog(@"###### Success for method: %@", response.meta.methodName);
    
    NSArray *regions = [[locationManager monitoredRegions] allObjects];
    
    if ([response.meta.methodName isEqualToString:@"loginUser"]) {
//        if ([regions count] == 0) {
        
//            [self getPlacesAroundCoordinate:CLLocationCoordinate2DMake(37.4149, -122.2065) setRegions:YES];
            
            [self getPlacesAroundCoordinate:locationManager.location.coordinate withTag:@"large"];
//        }
    } else if ([response.meta.methodName isEqualToString:@"searchPlaces"]) {
        NSArray *places = [response getObjectsOfType:[CCPlace class]];
        NSLog(@"Received %d places.", places.count);
        
        if ([[request.userInfo objectForKey:@"tagName"] isEqualToString:@"small"]) {
            NSLog(@"Received small region response");
            
            [self stopMonitoringSmallRegions];
            
            for (int i = 0; i < [places count]; i++) {
                CCPlace *place = [places objectAtIndex:i];
                NSLog(@"Adding Small Region: %@", place.name);
                [self monitorRegionAtCoordinates:place.location.coordinate withName:place.name withTag:@"small"];
            }
            addingSmallRegions = NO;
            smallRegionsAdded = YES;
        } else if ([[request.userInfo objectForKey:@"tagName"] isEqualToString:@"large"]) {
            NSLog(@"Received large region response");
            
            [self stopMonitoringAllRegions];
            for (int i = 0; i < [places count]; i++) {
                CCPlace *place = [places objectAtIndex:i];
                NSLog(@"Adding Large Region: %@", place.name);
                [self monitorRegionAtCoordinates:place.location.coordinate withName:place.name withTag:@"large"];
            }
        } else {
            NSLog(@"Received unknown region response");
        }
        
//        for (int i = 0; i < [places count]; i++) {
//            CCPlace *place = [places objectAtIndex:i];
//            NSLog(@"Got Region: %@", place.name);
//        }
        
        
//        if ([request.userInfo objectForKey:@"setRegions"]) {
//            NSLog(@"Setting regions on map.");
//            
//            for (int i = 0; i < [regions count]; i++) {
//                CLRegion *region = [regions objectAtIndex:i];
//                [locationManager stopMonitoringForRegion:region];
//                
//                RegionAnnotation *annotation = [[RegionAnnotation alloc] initWithCLRegion:region];
//                [regionsMapView addAnnotation:annotation];
//                [annotation release];
//            }
//            
//            
//            NSArray *places = [response getObjectsOfType:[CCPlace class]];
//            
//            for (int i = 0; i < [places count]; i++) {
//                CCPlace *place = [places objectAtIndex:i];
//                [self monitorRegionAtCoordinates:place.location.coordinate];
//            }
//        }
    }
}

-(void)ccrequest:(CCRequest *)request didFailWithError:(NSError *)error
{
    NSString *msg = [NSString stringWithFormat:@"%@",[error localizedDescription]];
	UIAlertView *alert = [[UIAlertView alloc]
						  initWithTitle:@"Failed!"
						  message:msg
						  delegate:self
						  cancelButtonTitle:@"Ok"
						  otherButtonTitles:nil];
	[alert show];
	[alert release];
    
}


/*
 This method adds the region event to the events array and updates the icon badge number.
 */
- (void)updateWithEvent:(NSString *)event {
	// Add region event to the updates array.
	[updateEvents insertObject:event atIndex:0];
	
	// Update the icon badge number.
	[UIApplication sharedApplication].applicationIconBadgeNumber++;
	
	if (!updatesTableView.hidden) {
		[updatesTableView reloadData];
	}
    
    NSLog(@"UPDATE: %@",event);
//    [self getPlacesAroundCoordinate:CLLocationCoordinate2DMake(37.4149, -122.2065) setRegions:NO];
}


@end
