//
//  FacebookManager.m
//  FacebookManager
//
//  Created by Andrei Radulescu on 5/26/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FacebookManager.h"

@implementation FBRequestHelper
@synthesize path;
@synthesize callBackMode;
@synthesize params;
@synthesize callbackMethod;
@synthesize httpMethod;
@synthesize requestSent;
@synthesize request;

- (id)init {
    if ((self = [super init])) {
        // Initialization code
        requestSent = NO;
    }
    return self;
}

- (void)sendRequest {
    if (!requestSent) {
#if DEBUG
        NSLog(@"Query Graph API Path: %@", self.path);
        if (params) {
            NSLog(@"With Parameters; %@", self.params);
        }
#endif
        
        if (params) {
            self.request = [[FacebookManager facebook] requestWithGraphPath:self.path andParams:self.params andHttpMethod:self.httpMethod andDelegate:[FacebookManager sharedManager]];
        } else {
            self.request = [[FacebookManager facebook] requestWithGraphPath:self.path andDelegate:[FacebookManager sharedManager]];
        }
    }
    requestSent = YES;
}

@end


@implementation FacebookManager

@synthesize facebook = _facebook;

@synthesize facebookFriendsResult;

static FacebookManager *_sharedManager;

@synthesize activeRequests;

// Please set Application ID of Facebook.
NSString *kFacebookAppId = @"";

+ (FacebookManager *)sharedManager {
    if (!_sharedManager) {
        _sharedManager = [[FacebookManager alloc] init];
    }
    return _sharedManager;
}

+ (Facebook *)facebook {
    return [[FacebookManager sharedManager] facebook];
}
/* or like this
+ (Facebook *)facebook {
	static Facebook *facebook = nil;
	if (facebook == nil) {
		facebook = [[Facebook alloc] initWithAppId:@"261748360599446" andDelegate:[FacebookManager sharedManager]];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"FBAccessTokenKey"] 
            && [defaults objectForKey:@"FBExpirationDateKey"]) {
            facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
            facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
        }
	}
	return facebook;
}*/

- (id)init
{
    if (self = [super init]) {
        // Initialization code here.
        _requestQueue = [[NSMutableArray alloc] init];
        
        self.activeRequests = [NSMutableArray array];
        
        NSAssert(kFacebookAppId != nil && ![kFacebookAppId isEqualToString:@""], 
                 @"Error (FacebookManager): Undefined Application ID");
        
        _facebook = [[Facebook alloc] initWithAppId:kFacebookAppId andDelegate:self];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"FBAccessTokenKey"] 
            && [defaults objectForKey:@"FBExpirationDateKey"]) {
            _facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
            _facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
        }
    }
    
    return self;
}

- (void)dealloc {
    [_requestQueue release], _requestQueue = nil;
    
    _facebook.sessionDelegate = nil;
    [_facebook release], _facebook = nil;
    
    [super dealloc];
}

- (void)requestWithGraphPath:(NSString *)graphPath 
                      target:(id)target
                    selector:(SEL)selector{
    
    NSMethodSignature *signature = 
    [target methodSignatureForSelector:selector];
    
    NSAssert(
             signature.numberOfArguments == 2+2, 
             @"Error (FacebookManager): requestWithGraphPath (Num of arguments must be 2)"
             );
    
    NSInvocation *invocation = 
    [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:target];
    [invocation setSelector:selector];
    
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:graphPath forKey:@"graphPath"];
    [request setObject:invocation forKey:@"invocation"];
    
    [_requestQueue addObject:request];
}


- (void)doRequests {
    if (![_facebook isSessionValid]) {
        // If you want to request additional permissions, set below.
        NSArray *permissions = nil;
        
        [_facebook authorize:permissions];
        
        return;
    }
    
    [self _performQueue];
}

- (void)_performQueue {
    
    for (NSMutableDictionary *queue in _requestQueue) {
        FBRequest *request =
        [[_facebook requestWithGraphPath:[queue objectForKey:@"graphPath"] 
                             andDelegate:self] 
         retain];
        
        [queue setObject:request forKey:@"request"];
    }
}

#pragma mark - FBSessionDelegate

- (void)fbDidLogin {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[_facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[_facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    
    [self _performQueue];
}

- (void)fbDidNotLogin:(BOOL)cancelled {
}

- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt {
}

- (void)fbDidLogout {
}

- (void)fbSessionInvalidated {
}

#pragma mark - FBDialogDelegate

- (void)dialogDidComplete:(FBDialog *)dialog {
}

- (void) dialogDidNotComplete:(FBDialog *)dialog {
}

- (void)dialogCompleteWithUrl:(NSURL *)url {
}

- (void) dialogDidNotCompleteWithUrl:(NSURL *)url {
}

- (void)dialog:(FBDialog*)dialog didFailWithError:(NSError *)error {
}

- (BOOL)dialog:(FBDialog*)dialog shouldOpenURLInExternalBrowser:(NSURL *)url {
    return NO;
}

#pragma mark - FBRequestDelegate
- (void)requestLoading:(FBRequest *)request {
}

- (void)request:(FBRequest *)request didReceiveResponse:(NSURLResponse *)response {
}

- (void)request:(FBRequest *)request didFailWithError:(NSError *)error {
    FBRequestHelper *matchedRequestHelper = nil;
    for (FBRequestHelper *requestHelper in [FacebookManager sharedManager].activeRequests) {
        if (requestHelper.request == request) {
            matchedRequestHelper = requestHelper;
        }
    }
    if (matchedRequestHelper && matchedRequestHelper) {
        [[FacebookManager sharedManager].activeRequests removeObject:matchedRequestHelper];
    }
    
#if DEBUG
    NSLog(@"Facebook Request Failed: %@ \n\r %@ %@ %@", [request url], [error description], [error localizedDescription], [error localizedFailureReason]);
#endif
}

- (void)request:(FBRequest *)request didLoad:(id)result {
    
    for (NSMutableDictionary *queue in _requestQueue) {
        if ([queue objectForKey:@"request"] == request) {
            NSDictionary *theQueue = queue;
            
            NSInvocation *invocation = [theQueue objectForKey:@"invocation"];
            [invocation setArgument:&request atIndex:2];
            [invocation setArgument:&result atIndex:3];
            [invocation invoke];
            
            [_requestQueue removeObject:theQueue];
            
            break; // get out
        }
    }
    
    //
    
    //    FBRequestHelper *matchedRequestHelper = nil;
    for (FBRequestHelper *requestHelper in [FacebookManager sharedManager].activeRequests) {
        if (requestHelper.request == request) {
            FBRequestHelper *matchedRequestHelper = requestHelper;
            
            if (matchedRequestHelper && matchedRequestHelper.callBackMode == FacebookCallBackModeJSON) {
                matchedRequestHelper.callbackMethod(result);
                [[FacebookManager sharedManager].activeRequests removeObject:matchedRequestHelper];
            }
            
            break;
        }
    }
}

- (void)request:(FBRequest *)request didLoadRawResponse:(NSData *)data {
    FBRequestHelper *matchedRequestHelper = nil;
    for (FBRequestHelper *requestHelper in [FacebookManager sharedManager].activeRequests) {
        if (requestHelper.request == request) {
            matchedRequestHelper = requestHelper;
        }
    }
    if (matchedRequestHelper && matchedRequestHelper.callBackMode == FacebookCallBackModeRawData) {
        matchedRequestHelper.callbackMethod(data);
        [[FacebookManager sharedManager].activeRequests removeObject:matchedRequestHelper];
    }
}

// Graph API

// The actual class send request
+ (void)sendGraphAPIRequest:(NSString *)path params:(NSMutableDictionary *)params mode:(FacebookCallBackMode)callbackMode httpMethod:(NSString *)httpMethod withCompletionBlock:(FacebookCallBack)completionHandler {
    FBRequestHelper *requestHelper = [[FBRequestHelper alloc] init];
    requestHelper.path = path;
    requestHelper.params = params;
    requestHelper.callbackMethod = completionHandler;
    requestHelper.callBackMode = callbackMode;
    requestHelper.httpMethod = httpMethod;
    [[FacebookManager sharedManager].activeRequests addObject:requestHelper];
    
    if(![[FacebookManager facebook] isSessionValid])
    {
        [FacebookManager login];
        return;
    } else {
        [requestHelper sendRequest];
    }
}

+ (void)friends:(FacebookCallBack)completionHandler {
    [FacebookManager sendGraphAPIRequest:@"me/friends" params:nil mode:FacebookCallBackModeJSON httpMethod:@"GET" withCompletionBlock:completionHandler];
}

+ (void)pictureForObject:(NSString *)objectId withCompletionHandler:(FacebookCallBack)completionHandler {
    [FacebookManager sendGraphAPIRequest:[NSString stringWithFormat:@"%@/picture", objectId] params:nil mode:FacebookCallBackModeRawData httpMethod:@"GET" withCompletionBlock:completionHandler];
}

+ (void)uploadPhoto:(UIImage *)photo message:(NSString *)message withCompletionHandler:(FacebookCallBack)completionHandler {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   photo, @"source",
                                   message, @"message", 
                                   nil];
    [FacebookManager sendGraphAPIRequest:@"me/photos" params:params mode:FacebookCallBackModeJSON httpMethod:@"POST" withCompletionBlock:completionHandler];
}

//

+ (BOOL)handleOpenURL:(NSURL *)url {
	BOOL returnValue = [[FacebookManager facebook] handleOpenURL:url];
    
    //Perform the original action of the user before they were thrown out (if they authorised us)
    if (returnValue) {
        for (FBRequestHelper *requestHelper in [FacebookManager sharedManager].activeRequests) {
            if (!requestHelper.requestSent) {
                [requestHelper sendRequest];
            }
        }
    }
    
    return returnValue;
}

+ (void)postToWallUseFacebookInterface:(NSMutableDictionary *)parameters {
    [[FacebookManager facebook] dialog:@"feed" andParams:parameters andDelegate:[FacebookManager sharedManager]];
}

+ (void)login {
	[[FacebookManager facebook] authorize:[NSArray arrayWithObjects:
                                           @"user_checkins", //read the user's checkins.
                                           @"friends_checkins", //read the user's friend's checkins.
                                           @"publish_checkins", //publish checkin on user's behavior
                                           @"publish_stream", // post to wall
                                           @"user_photos", // upload photo
                                           @"user_likes", // Create like
                                           @"read_stream", // Read post I guess
                                           nil]];
}

+ (void)logout {
	[[FacebookManager facebook] logout:[FacebookManager sharedManager]];
}

+ (BOOL)isSessionValid {
    return [[FacebookManager facebook] isSessionValid];
}

@end
