//
//  MoneyStoriesPlugin.m
//  MoneyStoriesTestApp
//
//  Created by Martin Prusa on 21.08.2023.
//

#import "MoneyStoriesPlugin.h"

@interface MoneyStoriesPlugin ()

@property(nonatomic, strong) NSString *baseURL;
@property(nonatomic, strong) NSString *accessToken;
@property(nonatomic, strong) NSString *languageCode;
@property(nonatomic, strong) NSString *customerId;

@property(nonatomic, strong) id <MoneyStoriesInterface> interface;
@property(nonatomic, strong) StoryBarView *storyBar;
@property(nonatomic, strong) NSString *callbackId;

@end

@implementation MoneyStoriesPlugin

- (void)initializeSdk:(CDVInvokedUrlCommand *)command {
    NSDictionary *params = (NSDictionary *) command.arguments.firstObject;
    if (params == nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    [self setupArgumentsToInitSDK:command dict:params];

    MoneyStoriesObjcInjector *objcInjector = [[MoneyStoriesObjcInjector alloc] init];
    self.interface = [objcInjector injectedMoneyStories];

    ConfigBuilder *builder =
            [
                    [
                            [
                                    [[ConfigBuilder alloc] init]

                                    withDebugEnabled
                            ]

                            withBaseUrl:[NSURL URLWithString:self.baseURL]
                    ]

                    withLanguageCode:self.languageCode
            ];

    [self.interface setupWithConfigBuilder:builder];

    NSError *error;
    BearerToken *token = [[BearerToken alloc] initWithToken:self.accessToken error:&error];
    [self.interface authenticateWithCredential:token];

    self.callbackId = command.callbackId;
    self.storyBar = [[StoryBarView alloc] init];
    self.storyBar.delegate = self;
    [self.storyBar startLoading];

    if (error != nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }
}

- (void)openStories:(CDVInvokedUrlCommand *)command {
    NSDictionary *params = (NSDictionary *) command.arguments.firstObject;

    NSString *period;
    if ([params[@"period"] isKindOfClass:[NSString class]]) {
        period = params[@"period"];
    } else {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    NSString *date;
    if ([params[@"date"] isKindOfClass:[NSString class]]) {
        date = params[@"date"];
    } else {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    BOOL isRead = NO;
    if (params[@"read"] != nil) {
        isRead = params[@"read"];
    } else {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    NSLog(@"params more %@", params);
    NSLog(@"period more %@", period);
    NSLog(@"date more %@", date);
    NSLog(@"isRead more %s", isRead ? "YES" : "NO");


    [self.interface handleNotificationWithDate:date period:period isRead:isRead];
}

- (void)refreshToken:(CDVInvokedUrlCommand *)command {
    NSString *token = (NSString *) command.arguments.firstObject;

    if (token == nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    NSError *error;
    BearerToken *bearerToken = [[BearerToken alloc] initWithToken:token error:&error];
    [self.interface authenticateWithCredential:bearerToken];

    if (error != nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }
}

- (void)setupArgumentsToInitSDK:(CDVInvokedUrlCommand *)command dict:(NSDictionary *)dict {
    if ([dict[@"baseUrl"] isKindOfClass:[NSString class]]) {
        NSString *baseURLString = dict[@"baseUrl"];

        if ([[baseURLString substringFromIndex:[baseURLString length] - 1] isEqualToString:@"/"]) {
            baseURLString = [baseURLString substringToIndex:[baseURLString length] - 1];
        }

        self.baseURL = baseURLString;
        NSLog(@"baseURL is: %@", dict[@"baseUrl"]);
    } else {
        NSLog(@"baseURL is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }

    if ([dict[@"languageCode"] isKindOfClass:[NSString class]]) {
        self.languageCode = dict[@"languageCode"];
        NSLog(@"languageCode is: %@", dict[@"languageCode"]);
    } else {
        NSLog(@"languageCode is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }

    if ([dict[@"accessToken"] isKindOfClass:[NSString class]]) {
        self.accessToken = dict[@"accessToken"];
        NSLog(@"accessToken is: %@", dict[@"accessToken"]);
    } else {
        NSLog(@"accessToken is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }

    if ([dict[@"customerId"] isKindOfClass:[NSString class]]) {
        NSLog(@"customerId is: %@", dict[@"customerId"]);
        self.customerId = dict[@"customerId"];
    } else {
        NSLog(@"customerId is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }
}

- (void)sendPluginResult:(CDVInvokedUrlCommand *)command status:(CDVCommandStatus)status message:(NSString *)message {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:status messageAsString:message];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)storiesDidLoadWithStories:(NSArray

<MoneyStoriesStoryLine *> * _Nonnull)stories {
    NSMutableArray *storiesArr = @[].mutableCopy;
    NSDateFormatter *dateformatter = [[NSDateFormatter alloc] init];

    dateformatter.dateFormat = @"yyyy-MM-dd";
    for (MoneyStoriesStoryLine *storyline in stories) {
        [storiesArr addObject:@{
                @"startDate": [dateformatter stringFromDate:storyline.getStartDate],
                @"read": [NSNumber numberWithBool:storyline.isRead],
                @"period": storyline.getPeriodString
        }];
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:storiesArr options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"NSJSONSerialization error: %@", [error localizedDescription]);
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
    NSString *commandDelegateClassName = NSStringFromClass([self.commandDelegate class]);

    NSLog(@"sending data about storybar className: %@", commandDelegateClassName);
    NSLog(@"callbackId: %@", self.callbackId);
    NSLog(@"sending data raw %@", storiesArr);

    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

@end
