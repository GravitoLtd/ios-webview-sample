# Gravito WebView-based CMP Integration Guide

## Section 1: General Architecture – WebView-based CMP (Platform-agnostic)

### Overview
Gravito’s WebView-based CMP is a cross-platform solution designed for use in mobile apps. It allows apps to display and interact with the CMP using an embedded web browser (WebView), regardless of the native platform (React Native, Flutter, Native Android, or Native iOS).

### High-Level Flow

1. **CMP HTML Page**
   - Gravito provides an embeddable CMP HTML containing all configuration and JavaScript logic.
   - This page must be hosted by the developer (on a CDN or local server).

2. **WebView Integration**
   - The CMP HTML is loaded into the mobile app’s WebView component.
   - The URL must include `?platform={platformName}` query param (e.g., `reactnative`, `flutter`, `android`, `ios`).
   - This tells the CMP JavaScript how to handle communication for that specific platform.

3. **Communication Mechanism**
   - Communication between the CMP (JavaScript) and the native app occurs through:
     - `window.postMessage` from the CMP
     - Native event listener or handler (e.g., `onMessage`)
     - JavaScript injection (`evaluateJavascript`, `injectJavaScript`, etc.)
   - Based on the platform, different APIs are used to facilitate this message passing.

### Configuration
- In the webview based CMP config make sure you have set below property in config object:
```json
gravito.config.cmp.tcf.core.isWebView = true,
```

#### Showing the CMP UI even if the user has already given consent
- If you want to show the CMP UI even if the user has already given consent, you can set the `gravito.config.cmp.tcf.core.showUiWhenConsented` to `true` in the config object.
```json
gravito.config.cmp.tcf.core.showUiWhenConsented = true,
```

### Core Message Events

| Event Type   | Direction   | Purpose                                                                      |
|--------------|-------------|------------------------------------------------------------------------------|
| CMP-loaded   | CMP → App | CMP is ready and requests consent data                                       |
| cookieData   | App → CMP | App sends existing consent data (if any)                                     |
| save         | CMP → App | User saved consent; app must store this data                                 |
| config       | App → CMP | App configures display properties of CMP UI (optional)                       |
| load         | CMP → App | CMP sends version info (informational)                                       |
| close        | CMP → App | CMP UI closed (informational)                                                |

### App Responsibilities

- Host the CMP HTML provided by Gravito
- Load it in a WebView with the correct platform query param
- Listen to messages from CMP (`CMP-loaded`, `save`)
- Send stored consent data to CMP if available
- Store updated consent data received from CMP
- Optionally configure CMP UI behavior using a `config` message
- Store the tcf consents and related data in a persistent storage solution (e.g., SharedPreferences, UserDefaults, etc.) in the format mentioned in the [TC Data Format](https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/master/TCFv2/IAB%20Tech%20Lab%20-%20CMP%20API%20v2.md#how-is-a-cmp-used-in-app).
- if use Google Additional Consent mode you should also store the AcString data in the same persistent storage solution against the key mentioned in the [Google Additional Consent Mode](https://support.google.com/admanager/answer/9681920?hl=en#store-ac-string:~:text=In-,%2D,-app).

Note: All the information about the CMP that needs to be stored in the app is available in the data received in the save event.

## Section 2: Platform-Specific Implementation

### iOS (Native)

#### Sample App  
You can use the following code as a reference to integrate Gravito CMP in a native iOS app using `WKWebView`.

#### Required Configuration

- Ensure `NSAppTransportSecurity` is updated in `Info.plist` to allow loading the CMP page if it’s served from HTTP or non-standard HTTPS.

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

#### Code Example

```swift
import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let preferences = WKPreferences()
        preferences.setValue(true, forKey: "developerExtrasEnabled")

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController.add(self, name: "jsHandler")

        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        view.addSubview(webView)

        loadTheUrl()
    }

    func loadTheUrl() {
        let urlString = "https://yourhost.com/gravito-cmp.html?platform=ios"
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "jsHandler",
           let json = message.body as? [String: Any],
           let event = json["event"] as? String {
            switch event {
            case "start":
                let tcstring = UserDefaults.standard.string(forKey: "tcstring") ?? ""
                let nontcfdata = UserDefaults.standard.string(forKey: "nontcfdata") ?? ""
                let acstring = UserDefaults.standard.string(forKey: "acstring") ?? ""

                let dict: [String: Any] = [
                    "type": "cookieData",
                    "tcstring": tcstring,
                    "nontcfdata": nontcfdata,
                    "acstring": acstring,
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    let js = "window.postMessage(\(jsonString), "*");true;"
                    webView.evaluateJavaScript(js, completionHandler: nil)
                }

            case "save":
                if let tcstring = json["data"] as? String {
                    UserDefaults.standard.set(tcstring, forKey: "tcstring")
                }
                if let nontcfdata = json["nontcfdata"] as? String {
                    UserDefaults.standard.set(nontcfdata, forKey: "nontcfdata")
                }
                if let acstring = json["acstring"] as? String {
                    UserDefaults.standard.set(acstring, forKey: "acstring")
                }

            default:
                break
            }
        }
    }
}
```

> ⚠️ **Important**: You must register the JavaScript adapter with the exact name used in the CMP JavaScript. For Gravito CMP, the adapter name should be `"jsHandler"`.



#### Consent Storage

```swift
UserDefaults.standard.set(tcstring, forKey: "tcstring")
UserDefaults.standard.set(nontcfdata, forKey: "nontcfdata")
UserDefaults.standard.set(acstring, forKey: "acstring")

let tcstring = UserDefaults.standard.string(forKey: "tcstring")
let nontcfdata = UserDefaults.standard.string(forKey: "nontcfdata")
let acstring = UserDefaults.standard.string(forKey: "acstring")
```
Note: The `tcstring`, `nontcfdata`, and `acstring` should be stored in the format mentioned in the [TC Data Format](https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/master/TCFv2/IAB%20Tech%20Lab%20-%20CMP%20API%20v2.md#how-is-a-cmp-used-in-app).

#### Opening Preferences UI from App

```swift
webView.evaluateJavaScript("window.gravito.cmp.openPreferences();", completionHandler: nil)
```

Note:To run this sample code, you need to have a valid Gravito CMP HTML page hosted and replace `https://yourhost.com/gravito-cmp.html` with the actual URL of your CMP page.
