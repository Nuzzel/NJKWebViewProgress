//
//  NJKWebViewProgress.m
//
//  Created by Satoshi Aasano on 4/20/13.
//  Copyright (c) 2013 Satoshi Asano. All rights reserved.
//

#import "NJKWebViewProgress.h"
#import "UIWebView+FLUIWebView.h"
#import "WKWebView+FLWKWebView.h"

NSString *completeRPCURLPath = @"/njkwebviewprogressproxy/complete";

const float NJKInitialProgressValue = 0.1f;
const float NJKInteractiveProgressValue = 0.5f;
const float NJKFinalProgressValue = 0.9f;

@implementation NJKWebViewProgress
{
    NSUInteger _loadingCount;
    NSUInteger _maxLoadCount;
    NSURL *_currentURL;
    BOOL _interactive;
}

- (id)init
{
    self = [super init];
    if (self) {
        _maxLoadCount = _loadingCount = 0;
        _interactive = NO;
    }
    return self;
}

- (void)startProgress
{
    if (_progress < NJKInitialProgressValue) {
        [self setProgress:NJKInitialProgressValue];
    }
}

- (void)incrementProgress
{
    float progress = self.progress;
    float maxProgress = _interactive ? NJKFinalProgressValue : NJKInteractiveProgressValue;
    float remainPercent = (float)_loadingCount / (float)_maxLoadCount;
    float increment = (maxProgress - progress) * remainPercent;
    progress += increment;
    progress = fmin(progress, maxProgress);
    [self setProgress:progress];
}

- (void)completeProgress
{
    [self setProgress:1.0];
}

- (void)setProgress:(float)progress
{
    // progress should be incremental only
    if (progress > _progress || progress == 0) {
        _progress = progress;
        if ([_progressDelegate respondsToSelector:@selector(webViewProgress:updateProgress:)]) {
            [_progressDelegate webViewProgress:self updateProgress:progress];
        }
        if (_progressBlock) {
            _progressBlock(progress);
        }
    }
}

- (void)reset
{
    _maxLoadCount = _loadingCount = 0;
    _interactive = NO;
    [self setProgress:0.0];
}

#pragma mark -

#pragma mark - Shared Delegate Methods

/*
 * This is called whenever the web view wants to navigate.
 */
- (BOOL)shouldStartDecidePolicy:(NSURLRequest *)request navigationType:(NSInteger)navigationType onWebView:(UIView<FLWebViewProvider> *)webView
{
    BOOL ret = YES;
    
    BOOL isFragmentJump = NO;
    if (request.URL.fragment) {
        NSString *nonFragmentURL = [request.URL.absoluteString stringByReplacingOccurrencesOfString:[@"#" stringByAppendingString:request.URL.fragment] withString:@""];
        isFragmentJump = [nonFragmentURL isEqualToString:webView.request.URL.absoluteString];
    }
    
    BOOL isTopLevelNavigation = [request.mainDocumentURL isEqual:request.URL];
    
    BOOL isHTTP = [request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"];
    if (ret && !isFragmentJump && isHTTP && isTopLevelNavigation) {
        _currentURL = request.URL;
        [self reset];
    }
    return ret;
}

/*
 * This is called whenever the web view has started navigating.
 */
- (void) didStartNavigationOnWebView:(UIView<FLWebViewProvider> *)webView
{
    _loadingCount++;
    _maxLoadCount = fmax(_maxLoadCount, _loadingCount);
    
    [self startProgress];
}

/*
 * This is called when navigation failed.
 */
- (void)failLoadOrNavigation:(NSURLRequest *)request withError:(NSError *)error onWebView:(UIView<FLWebViewProvider> *)webView
{
    _loadingCount--;
    [self incrementProgress];
    
    [webView evaluateJavaScript:@"document.readyState" completionHandler:^(NSString *readyState, NSError *error) {
        BOOL interactive = [readyState isEqualToString:@"interactive"];
        if (interactive) {
            _interactive = YES;
            NSString *waitForCompleteJS = [NSString stringWithFormat:@"window.addEventListener('load',function() { var iframe = document.createElement('iframe'); iframe.style.display = 'none'; iframe.src = '%@://%@%@'; document.body.appendChild(iframe);  }, false);", webView.request.mainDocumentURL.scheme, webView.request.mainDocumentURL.host, completeRPCURLPath];
            [webView evaluateJavaScript:waitForCompleteJS completionHandler:nil];
        }
        
        BOOL isNotRedirect = YES; //_currentURL && [_currentURL isEqual:webView.request.mainDocumentURL];
        BOOL complete = [readyState isEqualToString:@"complete"];
        if ((complete && isNotRedirect) || error) {
            [self completeProgress];
        }
    }];
}

/*
 * This is called when navigation succeeds and is complete.
 */
- (void)finishLoadOrNavigation:(NSURLRequest *)request onWebView:(UIView<FLWebViewProvider> *)webView
{
    _loadingCount--;
    [self incrementProgress];
    
    [webView evaluateJavaScript:@"document.readyState" completionHandler:^(NSString *readyState, NSError *error) {
        BOOL interactive = [readyState isEqualToString:@"interactive"];
        if (interactive) {
            _interactive = YES;
            NSString *waitForCompleteJS = [NSString stringWithFormat:@"window.addEventListener('load',function() { var iframe = document.createElement('iframe'); iframe.style.display = 'none'; iframe.src = '%@://%@%@'; document.body.appendChild(iframe);  }, false);", webView.request.mainDocumentURL.scheme, webView.request.mainDocumentURL.host, completeRPCURLPath];
            [webView evaluateJavaScript:waitForCompleteJS completionHandler:nil];
        }
        
        BOOL isNotRedirect = YES; //_currentURL && [_currentURL isEqual:webView.request.mainDocumentURL];
        BOOL complete = [readyState isEqualToString:@"complete"];
        if (complete && isNotRedirect) {
            [self completeProgress];
        }
    }];
}

#pragma mark - UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.path isEqualToString:completeRPCURLPath]) {
        [self completeProgress];
        return NO;
    }
    BOOL ret = YES;
    if ([_webViewProxyDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        ret = [_webViewProxyDelegate webView:(UIWebView *)webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    if (ret) [self shouldStartDecidePolicy:request navigationType:navigationType onWebView:webView];

    return ret;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if ([_webViewProxyDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [_webViewProxyDelegate webViewDidStartLoad:webView];
    }
    
    [self didStartNavigationOnWebView:webView];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if ([_webViewProxyDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [_webViewProxyDelegate webViewDidFinishLoad:webView];
    }
    
    [self finishLoadOrNavigation:[webView request] onWebView:webView];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([_webViewProxyDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [_webViewProxyDelegate webView:webView didFailLoadWithError:error];
    }
    
    [self failLoadOrNavigation:[webView request] withError:error onWebView:webView];
}

#pragma mark - WKWebView Delegate Methods

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    if ([_webViewUIProxyDelegate respondsToSelector:@selector(webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)]) {
        [_webViewUIProxyDelegate webView:webView createWebViewWithConfiguration:configuration forNavigationAction:navigationAction windowFeatures:windowFeatures];
    }
    
    return nil;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([navigationAction.request.URL.path isEqualToString:completeRPCURLPath]) {
        [self completeProgress];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    __block BOOL toContinue = YES;
    void (^delegateDecisionHandler)(WKNavigationActionPolicy) = ^(WKNavigationActionPolicy decision){
        toContinue = decision;
        if (toContinue) {
            decisionHandler(WKNavigationActionPolicyAllow); //[self shouldStartDecidePolicy:[navigationAction request] navigationType:navigationAction.navigationType onWebView:webView]);
        } else {
            NZLLogDebug(@"stopping webview loading on %@", navigationAction.request.URL.absoluteString);
        }
    };
    if ([_webViewNavigationProxyDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [_webViewNavigationProxyDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:delegateDecisionHandler];
    } else {
        delegateDecisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    if ([_webViewNavigationProxyDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [_webViewNavigationProxyDelegate webView:webView didStartProvisionalNavigation:navigation];
    }

    [self didStartNavigationOnWebView:webView];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if ([_webViewNavigationProxyDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [_webViewNavigationProxyDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }

    [self failLoadOrNavigation:[webView request] withError:error onWebView:webView];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    if ([_webViewNavigationProxyDelegate respondsToSelector:@selector(webView:didCommitNavigation:)]) {
        [_webViewNavigationProxyDelegate webView:webView didCommitNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if ([_webViewNavigationProxyDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [_webViewNavigationProxyDelegate webView:webView didFailNavigation:navigation withError:error];
    }
    
    [self failLoadOrNavigation:[webView request] withError:error onWebView:webView];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if ([_webViewNavigationProxyDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [_webViewNavigationProxyDelegate webView:webView didFinishNavigation:navigation];
    }
    
    [self finishLoadOrNavigation:[webView request] onWebView:webView];
}

#pragma mark - 
#pragma mark Method Forwarding
// for future UIWebViewDelegate impl

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ( [super respondsToSelector:aSelector] )
        return YES;
    
    if ([self.webViewProxyDelegate respondsToSelector:aSelector])
        return YES;
    
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if(!signature) {
        if([_webViewProxyDelegate respondsToSelector:selector]) {
            return [(NSObject *)_webViewProxyDelegate methodSignatureForSelector:selector];
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation*)invocation
{
    if ([_webViewProxyDelegate respondsToSelector:[invocation selector]]) {
        [invocation invokeWithTarget:_webViewProxyDelegate];
    }
}

@end
