# NJKWebViewProgress
NJKWebViewProgress is a library what tell UIWebView progress. Currently, UIWebView don't have progress interface. You can implement progress bar for your in-app browser with this module.

<img src="https://raw.github.com/ninjinkun/NJKWebViewProgress/master/DemoApp/Screenshot/screenshot1.png" alt="iOS ScreenShot 1" width="240px" style="width: 240px;" />

# Requirements
- iOS 5 or lator
- ARC

# Usage
Instance `NIJWebViewProgress` and set `UIWebViewDelegate`. If you set `webViewProxyDelegate`, `NIJWebViewProgress` suould perform as a proxy object.

```objc
NIJWebViewProgress *progressProxy = [[NIJWebViewProgress alloc] init];
webView.delegate = progressProxy;
progressProxy.webViewProxyDelegate = self;
progressProxy.progressDelegate = self;
```

When UIWebView start loading, `NIJWebViewProgress` call delegate method and block with progress.
```objc
-(void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress
{
    [progressView setProgress:progress animated:NO];
}
```

```objc
progressProxy.progressBlock = ^(float progress) {
    [progressView setProgress:progress animated:NO];
};
```

# License
[Apache]: http://www.apache.org/licenses/LICENSE-2.0
[MIT]: http://www.opensource.org/licenses/mit-license.php
[GPL]: http://www.gnu.org/licenses/gpl.html
[BSD]: http://opensource.org/licenses/bsd-license.php
[MIT license][MIT].