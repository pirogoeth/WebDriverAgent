/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <sys/utsname.h>

#import <XCTest/XCTest.h>

#import <WebDriverAgentLib/FBDebugLogDelegateDecorator.h>
#import <WebDriverAgentLib/FBConfiguration.h>
#import <WebDriverAgentLib/FBFailureProofTestCase.h>
#import <WebDriverAgentLib/FBWebServer.h>
#import <WebDriverAgentLib/XCTestCase.h>

#import <UNIRest.h>

@interface UITestingUITests : FBFailureProofTestCase <FBWebServerDelegate>
@end

@implementation UITestingUITests

+ (void)setUp
{
  [FBDebugLogDelegateDecorator decorateXCTestLogger];
  [FBConfiguration disableRemoteQueryEvaluation];
  [super setUp];
}

/**
 Never ending test used to start WebDriverAgent
 */
- (void)testRunner
{
  FBWebServer *webServer = [[FBWebServer alloc] init];
  webServer.delegate = self;
  [webServer startServing];
}

#pragma mark - Device Capabilities

- (NSString *)getDeviceIdentifier
{
  return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

- (NSString *)getDevicePlatform
{
  struct utsname sysInfo;
  uname(&sysInfo);
  
  return [NSString stringWithCString:(sysInfo.machine) encoding:(NSUTF8StringEncoding)];
}

- (NSMutableDictionary *)getDeviceCapabilities
{
  NSMutableDictionary *capabilities = [NSMutableDictionary new];
  UIDevice *device = [UIDevice currentDevice];
  
  [capabilities setObject:([device name]) forKey:(@"deviceName")];
  [capabilities setObject:([device systemName]) forKey:(@"systemName")];
  [capabilities setObject:([device model]) forKey:(@"deviceType")];
  [capabilities setObject:([device systemVersion]) forKey:(@"systemVersion")];
  [capabilities setObject:([self getDevicePlatform]) forKey:(@"devicePlatform")];
  [capabilities setObject:([[NSNumber numberWithFloat:([device batteryLevel])] stringValue]) forKey:(@"deviceBatteryLevel")];
  
  return capabilities;
}

#pragma mark - Device Registration

- (void)registerDevice
{
  NSString *deviceId = [self getDeviceIdentifier];
  NSString *regToken = @"MIL42RrhOdUX7dwHpU";
  NSString *registratorUrl = @"http://glow.dev.maio.me:8000";

  NSDictionary *headers = @{
                            @"X-Device-Identifier": deviceId,
                            @"X-Registration-Token": regToken,
                            @"Content-Type": @"application/json",
                            };
  NSDictionary *payload = @{
                           @"capabilities": [self getDeviceCapabilities],
                           };

  NSData *payloadData = [NSJSONSerialization dataWithJSONObject:(payload) options:(0) error:(nil)];
  NSString *payloadStr = [[NSString alloc] initWithData:(payloadData) encoding:(NSUTF8StringEncoding)];
  
  UNIBodyRequestBlock request = ^(UNIBodyRequest *req) {
    [req setUrl:(registratorUrl)];
    [req setHeaders:(headers)];
    [req setBody:(payloadData)];
  };
  
  UNIHTTPStringResponse *response = [[UNIRest postEntity:(request)] asString];
  NSLog(@"Got response code %d from POST", (int) response.code);
  NSLog(@"Got response body %@ from POST", response.body);
}

- (void)deregisterDevice
{
  NSLog(@"Device registration not implemented");
}

#pragma mark - FBWebServerDelegate

- (void)webServerDidStart:(FBWebServer *)webServer
{
  [self registerDevice];
}

- (void)webServerDidRequestShutdown:(FBWebServer *)webServer
{
  [webServer stopServing];
  [self deregisterDevice];
}

@end
