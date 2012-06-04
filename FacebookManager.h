//
//  FacebookManager.h
//  FacebookManager
//
//  Created by Andrei Radulescu on 5/26/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FBConnectParseWrapper.h"

typedef enum {
    FacebookCallBackModeJSON = 0,
    FacebookCallBackModeRawData = 1
} FacebookCallBackMode;

typedef void (^FacebookCallBack)(id results);

@interface FBRequestHelper : NSObject

@property (retain, nonatomic) NSString *path;
@property (assign, nonatomic) FacebookCallBackMode callBackMode;
@property (retain, nonatomic) NSMutableDictionary *params;
@property (copy, nonatomic) FacebookCallBack callbackMethod;
@property (assign, nonatomic) NSString *httpMethod;
@property (assign, nonatomic) BOOL requestSent;
@property (retain, nonatomic) FBRequest *request;

- (void)sendRequest;

@end

//

@interface FacebookManager : NSObject <FBSessionDelegate, FBDialogDelegate, FBRequestDelegate> {
    NSMutableArray *_requestQueue;
}

@property (nonatomic, retain) Facebook *facebook;

+ (FacebookManager *)sharedManager;
+ (Facebook *)facebook;

- (void)requestWithGraphPath:(NSString *)graphPath 
                      target:(id)target
                    selector:(SEL)selector;

- (void)doRequests;
- (void)_performQueue;

//
@property (nonatomic, retain) NSArray *facebookFriendsResult;

//
@property (retain, nonatomic) NSMutableArray *activeRequests;

+ (BOOL)handleOpenURL:(NSURL *)url;
+ (void)postToWallUseFacebookInterface:(NSMutableDictionary *)parameters;
+ (void)login;
+ (void)logout;
+ (BOOL)isSessionValid;

// Graph API
+ (void)sendGraphAPIRequest:(NSString *)path params:(NSMutableDictionary *)params mode:(FacebookCallBackMode)callbackMode httpMethod:(NSString *)httpMethod withCompletionBlock:(FacebookCallBack)completionHandler;

+ (void)friends:(FacebookCallBack)completionHandler;
+ (void)pictureForObject:(NSString *)objectId withCompletionHandler:(FacebookCallBack)completionHandler;
+ (void)uploadPhoto:(UIImage *)photo message:(NSString *)message withCompletionHandler:(FacebookCallBack)completionHandler;

@end