import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler {

    var webView: WKWebView!
    private let clearPreferencesButton = UIButton(type: .system)
    private let openPreferencesLayer1Button = UIButton(type: .system)
    private let openPreferencesLayer2Button = UIButton(type: .system)

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
        setupClearPreferencesButton()
        setupOpenPreferencesButtons()

        loadTheUrl()
    }

    private func setupClearPreferencesButton() {
        clearPreferencesButton.setTitle("Clear Preferences", for: .normal)
        clearPreferencesButton.setTitleColor(.white, for: .normal)
        clearPreferencesButton.backgroundColor = .systemRed
        clearPreferencesButton.layer.cornerRadius = 8
        clearPreferencesButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        clearPreferencesButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        clearPreferencesButton.translatesAutoresizingMaskIntoConstraints = false
        clearPreferencesButton.addTarget(self, action: #selector(clearSharedPreferences), for: .touchUpInside)

        view.addSubview(clearPreferencesButton)

        NSLayoutConstraint.activate([
            clearPreferencesButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            clearPreferencesButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func setupOpenPreferencesButtons() {
        configurePreferencesButton(
            openPreferencesLayer1Button,
            title: "Layer 1",
            action: #selector(openPreferencesLayer1)
        )
        configurePreferencesButton(
            openPreferencesLayer2Button,
            title: "Layer 2",
            action: #selector(openPreferencesLayer2)
        )

        view.addSubview(openPreferencesLayer1Button)
        view.addSubview(openPreferencesLayer2Button)

        NSLayoutConstraint.activate([
            openPreferencesLayer1Button.leadingAnchor.constraint(equalTo: clearPreferencesButton.trailingAnchor, constant: 12),
            openPreferencesLayer1Button.centerYAnchor.constraint(equalTo: clearPreferencesButton.centerYAnchor),
            openPreferencesLayer2Button.leadingAnchor.constraint(equalTo: openPreferencesLayer1Button.trailingAnchor, constant: 12),
            openPreferencesLayer2Button.centerYAnchor.constraint(equalTo: clearPreferencesButton.centerYAnchor)
        ])
    }

    private func configurePreferencesButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func clearSharedPreferences() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        } else {
            ["tcstring", "currentstate", "nontcfdata", "acstring", "gppString", "gppstring", "googleConsents"].forEach {
                UserDefaults.standard.removeObject(forKey: $0)
            }
        }

        UserDefaults.standard.synchronize()
        if webView.superview == nil {
            view.insertSubview(webView, belowSubview: clearPreferencesButton)
        }
        loadTheUrl()
    }

    @objc private func openPreferencesLayer1() {
        openPreferences(layer: 0)
    }

    @objc private func openPreferencesLayer2() {
        openPreferences(layer: 1)
    }

    private func openPreferences(layer: Int) {
        if webView.superview == nil {
            view.insertSubview(webView, belowSubview: clearPreferencesButton)
        }
        webView.evaluateJavaScript("window.gravito.cmp.openPreferences(\(layer));", completionHandler: nil)
    }

    func loadTheUrl() {
        let urlString = "http://127.0.0.1:5502/localServer/gpp-webview.html?platform=ios&region=fi"
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    private func showConsentReceivedAlert(cmpType: String, receivedString: String) {
        let message = "bannerRequired=false\ncmpType=\(cmpType)\nreceivedString=\(receivedString)"
        DispatchQueue.main.async {
            guard self.presentedViewController == nil else { return }
            let alert = UIAlertController(title: "Consent Received", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.name == "jsHandler",
       let json = message.body as? [String: Any],
       let event = json["event"] as? String {
        switch event {
        case "start":
            let cmpType = json["cmpType"] as? String ?? "unknown"
            let payload: [String: Any]

            switch cmpType {
            case "tcf":
                let tcString = UserDefaults.standard.string(forKey: "tcstring") ?? ""
                let nontcfdata = UserDefaults.standard.object(forKey: "nontcfdata") ?? []
                let acString = UserDefaults.standard.string(forKey: "acstring") ?? ""
                let gppString = UserDefaults.standard.string(forKey: "gppstring") ?? ""
                let googleConsents = UserDefaults.standard.object(forKey: "googleConsents") ?? [:]
                payload = [
                    "type": "cookieData",
                    "cmpType": cmpType,
                    "tcstring": tcString,
                    "nontcfdata": nontcfdata,
                    "acstring": acString,
                    "gppstring": gppString,
                    "googleConsents": googleConsents
                ]
            case "usprivacy":
                let gppString = UserDefaults.standard.string(forKey: "gppstring") ?? ""
                payload = [
                    "type": "cookieData",
                    "cmpType": cmpType,
                    "gppstring": gppString
                ]
            case "standard":
                let gcString = UserDefaults.standard.string(forKey: "gcstring") ?? ""
                payload = [
                    "type": "cookieData",
                    "cmpType": cmpType,
                    "gcstring": gcString
                ]
            default:
                payload = [
                    "type": "cookieData",
                    "cmpType": cmpType
                ]
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let js = "window.postMessage(\(jsonString), \"*\");true;"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }

        case "save":
            // Save only the required fields
            let cmpType = json["cmpType"] as? String ?? "unknown"
            let bannerRequired = json["bannerRequired"] as? Bool ?? true
            if !bannerRequired {
                let receivedString =
                    (json["tcstring"] as? String) ??
                    (json["gppstring"] as? String) ??
                    (json["gcstring"] as? String) ??
                    "<empty>"
                showConsentReceivedAlert(cmpType: cmpType, receivedString: receivedString)
            }

            switch cmpType {
                case "tcf":
                    if let tcString = json["tcstring"] as? String {
                        UserDefaults.standard.set(tcString, forKey: "tcstring")
                    }
                    if let nontcfdata = json["nontcfdata"], JSONSerialization.isValidJSONObject(nontcfdata) {
                        UserDefaults.standard.set(nontcfdata, forKey: "nontcfdata")
                    }
                    if let acString = json["acstring"] as? String {
                        UserDefaults.standard.set(acString, forKey: "acstring")
                    }
                    if let gppString = json["gppstring"] as? String {
                        UserDefaults.standard.set(gppString, forKey: "gppstring")
                    }
                    if let googleConsents = json["googleConsents"], JSONSerialization.isValidJSONObject(googleConsents) {
                        UserDefaults.standard.set(googleConsents, forKey: "googleConsents")
                    }
                    break
                case "usprivacy":
                    if let gppString = json["gppstring"] as? String {
                        UserDefaults.standard.set(gppString, forKey: "gppstring")
                    }
                     if let googleConsents = json["googleConsents"], JSONSerialization.isValidJSONObject(googleConsents) {
                        UserDefaults.standard.set(googleConsents, forKey: "googleConsents")
                    }
                    break
                case "standard":
                    if let gcString = json["gcstring"] as? String {
                        UserDefaults.standard.set(gcString, forKey: "gcstring")
                    }
                     if let googleConsents = json["googleConsents"], JSONSerialization.isValidJSONObject(googleConsents) {
                        UserDefaults.standard.set(googleConsents, forKey: "googleConsents")
                    }
                    break

	                    
                default:
                    break
            }
         

        case "load":
           let cmpType = json["cmpType"] as? String ?? "unknown"
             print("Load event received for cmpType: \(cmpType)")
            // No action needed for load event in this context
             break
        case "close":
            let cmpType = json["cmpType"] as? String ?? "unknown"
            print("Close event received for cmpType: \(cmpType)")
            // No action needed for close event in this context
             break
        
        default:
            break
        }
    }
}
}
