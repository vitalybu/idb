/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <FBSimulatorControl/FBSimulatorControl.h>

#import "FBSimulatorControlAssertions.h"
#import "FBSimulatorControlFixtures.h"
#import "FBSimulatorControlTestCase.h"

@interface FBSimulatorDiagnosticsTests : FBSimulatorControlTestCase

@end

@implementation FBSimulatorDiagnosticsTests

- (void)assertFindsNeedle:(NSString *)needle fromHaystackBlock:( NSString *(^)(void) )block
{
  __block NSString *haystack = nil;
  BOOL foundLog = [NSRunLoop.currentRunLoop spinRunLoopWithTimeout:FBControlCoreGlobalConfiguration.slowTimeout untilTrue:^ BOOL {
    haystack = block();
    return haystack != nil;
  }];
  if (!foundLog) {
    XCTFail(@"Failed to find haystack log");
    return;
  }

  [self assertNeedle:needle inHaystack:haystack];
}

- (void)testLaunchedApplicationLogs
{
  if (FBSimulatorControlTestCase.isRunningOnTravis) {
    return;
  }

  NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  NSString *stdErrPath = [path stringByAppendingPathComponent:@"stderr.log"];
  NSString *stdOutPath = [path stringByAppendingPathComponent:@"stdout.log"];

  FBProcessOutputConfiguration *output = [FBProcessOutputConfiguration configurationWithStdOut:stdOutPath stdErr:stdErrPath error:nil];
  FBSimulator *simulator = [self assertObtainsBootedSimulatorWithInstalledApplication:self.tableSearchApplication];

  NSString *shimulatorPath = [[NSBundle bundleForClass: self.class] pathForResource:@"libShimulator" ofType:@"dylib"];
  FBApplicationLaunchConfiguration *appLaunch = self.tableSearchAppLaunch;
  NSMutableDictionary<NSString *, NSString *> *environment = [appLaunch.environment mutableCopy];
  environment[@"DYLD_INSERT_LIBRARIES"] = shimulatorPath;
  appLaunch = [FBApplicationLaunchConfiguration
    configurationWithBundleID:appLaunch.bundleID
    bundleName:appLaunch.bundleName
    arguments:appLaunch.arguments
    environment:environment
    output:output
    launchMode:appLaunch.launchMode];

  NSError *error = nil;
  BOOL success = [[simulator launchApplication:appLaunch] await:&error] != nil;
  XCTAssertNil(error);
  XCTAssertTrue(success);

  NSFileManager *fileManager = [NSFileManager defaultManager];
  XCTAssertTrue([fileManager fileExistsAtPath:stdErrPath]);
  XCTAssertTrue([fileManager fileExistsAtPath:stdOutPath]);

  [self assertFindsNeedle:@"Shimulator" fromHaystackBlock:^ NSString * {
    NSString *stdErrContent = [NSString stringWithContentsOfFile:stdErrPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSString *stdOutContent = [NSString stringWithContentsOfFile:stdOutPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSString *combinedContent = [stdErrContent stringByAppendingString:stdOutContent];
    if (!combinedContent.length) {
      return nil;
    }
    return combinedContent;
  }];
}

@end
