import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Enable developer extras
        let preferences = WKPreferences()
        preferences.setValue(true, forKey: "developerExtrasEnabled") // this is key

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController.add(self, name: "jsHandler")

        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if #available(iOS 16.4, *) {
            webView.isInspectable=true
        } else {
            // Fallback on earlier versions
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
            // Retrieve all required values from UserDefaults
            let tcstring = UserDefaults.standard.string(forKey: "tcstring") ?? ""
            let currentstate = UserDefaults.standard.string(forKey: "currentstate") ?? ""
            let nontcfdata = UserDefaults.standard.string(forKey: "nontcfdata") ?? ""
         
            let acstring = UserDefaults.standard.string(forKey: "acstring") ?? ""
           

            // Construct JSON for postMessage
            let dict: [String: Any] = [
                "type": "cookieData",
                "tcstring": tcstring,
              
                "nontcfdata": nontcfdata,
           
                "acstring": acstring,
               
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let js = "window.postMessage(\(jsonString), \"*\");true;"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }

        case "save":
            // Save only the required fields
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

