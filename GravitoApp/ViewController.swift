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
            ["tcstring", "currentstate", "nontcfdata", "acstring", "gppString", "gppstring", "gppData", "googleConsents"].forEach {
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
        let urlString = "http://127.0.0.1:5502/localServer/gpp-webview.html?platform=ios&region=usca"
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

    private func saveJSONObject(_ object: Any, forKey key: String) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadJSONObject(forKey key: String) -> Any? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// Persists a GPP PingReturn using the IAB GPP in-app key convention.
    private func saveGPPData(_ gppData: [String: Any]) {
        let defaults = UserDefaults.standard

        // A section can disappear after the user changes their choices. Remove the
        // previous snapshot first so vendors never read vestigial IABGPP values.
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("IABGPP_") }
            .forEach { defaults.removeObject(forKey: $0) }

        if let version = gppData["gppVersion"] as? String {
            defaults.set(version, forKey: "IABGPP_HDR_Version")
        }

        let sectionIDs = integerArray(from: gppData["sectionList"])
        defaults.set(sectionIDs.map(String.init).joined(separator: "_"),
                     forKey: "IABGPP_HDR_Sections")

        if let gppString = gppData["gppString"] as? String {
            defaults.set(gppString, forKey: "IABGPP_HDR_GppString")

            // The encoded string is header~section~section, in sectionList order.
            let encodedSections = gppString.split(separator: "~", omittingEmptySubsequences: false).dropFirst()
            for (sectionID, encodedSection) in zip(sectionIDs, encodedSections) {
                defaults.set(String(encodedSection), forKey: "IABGPP_\(sectionID)_String")
            }

            // Keep the sample's existing web-to-native round trip working even
            // when gppString is supplied only inside gppData.
            defaults.set(gppString, forKey: "gppstring")
        }

        let applicableSections = integerArray(from: gppData["applicableSections"])
        defaults.set(applicableSections.map(String.init).joined(separator: "_"),
                     forKey: "IABGPP_GppSID")

        if let parsedSections = gppData["parsedSections"] as? [String: Any] {
            for (apiPrefix, section) in parsedSections {
                guard let inAppPrefix = inAppSectionPrefix(for: apiPrefix) else { continue }
                let segments = (section as? [[String: Any]]) ?? ((section as? [String: Any]).map { [$0] } ?? [])

                for segment in segments {
                    for (fieldName, value) in segment {
                        if let storedValue = inAppValue(value, fieldName: fieldName) {
                            defaults.set(storedValue, forKey: "IABGPP_\(inAppPrefix)_\(fieldName)")
                        }
                    }
                }
            }
        }

        // Retain the original object for the sample app's own use/debugging.
        saveJSONObject(gppData, forKey: "gppData")
    }

    /// Persists getInAppTCData using the IAB TCF v2 in-app key convention.
    private func saveInAppTCData(_ tcData: [String: Any]) {
        let defaults = UserDefaults.standard

        // Replace the complete TCF snapshot so removed restrictions or consent
        // fields cannot survive from an earlier user choice.
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("IABTCF_") }
            .forEach { defaults.removeObject(forKey: $0) }

        setTCFValue(tcData["cmpId"], forKey: "IABTCF_CmpSdkID")
        setTCFValue(tcData["cmpVersion"], forKey: "IABTCF_CmpSdkVersion")
        setTCFValue(tcData["tcfPolicyVersion"], forKey: "IABTCF_PolicyVersion")
        setTCFValue(tcData["gdprApplies"], forKey: "IABTCF_gdprApplies")
        setTCFValue(tcData["publisherCC"], forKey: "IABTCF_PublisherCC")
        setTCFValue(tcData["purposeOneTreatment"], forKey: "IABTCF_PurposeOneTreatment")
        setTCFValue(tcData["useNonStandardTexts"], forKey: "IABTCF_UseNonStandardTexts")
        setTCFValue(tcData["tcString"], forKey: "IABTCF_TCString")
        setTCFValue(tcData["specialFeatureOptins"] ?? tcData["specialFeatureOptIns"],
                    forKey: "IABTCF_SpecialFeaturesOptIns")

        if let purpose = tcData["purpose"] as? [String: Any] {
            setTCFValue(purpose["consents"], forKey: "IABTCF_PurposeConsents")
            setTCFValue(purpose["legitimateInterests"], forKey: "IABTCF_PurposeLegitimateInterests")
        }

        if let vendor = tcData["vendor"] as? [String: Any] {
            setTCFValue(vendor["consents"], forKey: "IABTCF_VendorConsents")
            setTCFValue(vendor["legitimateInterests"], forKey: "IABTCF_VendorLegitimateInterests")
            setTCFValue(vendor["disclosedVendors"] ?? vendor["disclosed"] ?? tcData["disclosedVendors"],
                        forKey: "IABTCF_DisclosedVendors")
        }

        if let publisher = tcData["publisher"] as? [String: Any] {
            setTCFValue(publisher["consents"], forKey: "IABTCF_PublisherConsent")
            setTCFValue(publisher["legitimateInterests"],
                        forKey: "IABTCF_PublisherLegitimateInterests")

            if let customPurpose = publisher["customPurpose"] as? [String: Any] {
                setTCFValue(customPurpose["consents"],
                            forKey: "IABTCF_PublisherCustomPurposesConsents")
                setTCFValue(customPurpose["legitimateInterests"],
                            forKey: "IABTCF_PublisherCustomPurposesLegitimateInterests")
            }

            if let restrictions = publisher["restrictions"] as? [String: Any] {
                for (purposeID, restriction) in restrictions {
                    setTCFValue(restriction, forKey: "IABTCF_PublisherRestrictions\(purposeID)")
                }
            }
        }

        // Retain the source object for inspection without making vendors decode it.
        saveJSONObject(tcData, forKey: "InAppTcData")
    }

    private func setTCFValue(_ value: Any?, forKey key: String) {
        guard let value else { return }

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                UserDefaults.standard.set(number.boolValue ? 1 : 0, forKey: key)
            } else {
                UserDefaults.standard.set(number, forKey: key)
            }
        } else if let string = value as? String {
            UserDefaults.standard.set(string, forKey: key)
        }
    }

    private func integerArray(from value: Any?) -> [Int] {
        (value as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? []
    }

    private func inAppSectionPrefix(for apiPrefix: String) -> String? {
        switch apiPrefix.lowercased() {
        case "tcfeuv2": return "TCFEU2"
        case "tcfcav1": return "TCFCA1"
        case "uspv1": return "USP1"
        case "usnat": return "USNAT"
        case "usca": return "USCA"
        case "usva": return "USVA"
        case "usco": return "USCO"
        case "usut": return "USUT"
        case "usct": return "USCT"
        case "usfl": return "USFL"
        case "usmt": return "USMT"
        case "usor": return "USOR"
        case "ustx": return "USTX"
        case "usde": return "USDE"
        case "usia": return "USIA"
        case "usne": return "USNE"
        case "usnh": return "USNH"
        case "usnj": return "USNJ"
        case "ustn": return "USTN"
        case "usmn": return "USMN"
        case "usmd": return "USMD"
        case "usin": return "USIN"
        case "usky": return "USKY"
        case "usri": return "USRI"
        default: return nil
        }
    }

    private func inAppValue(_ value: Any, fieldName: String) -> Any? {
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? 1 : 0
            }
            return number
        }

        if let string = value as? String {
            if fieldName == "Created" || fieldName == "LastUpdated",
               let date = ISO8601DateFormatter().date(from: string) {
                return Int(date.timeIntervalSince1970 * 1_000)
            }
            return string
        }

        if let values = value as? [Any] {
            let records = values.compactMap { item -> String? in
                guard let record = item as? [String: Any],
                      let id = record["id"] as? NSNumber,
                      let type = record["type"] as? NSNumber else { return nil }
                return "\(id.intValue):\(type.intValue)"
            }
            if records.count == values.count { return records.joined(separator: "_") }

            let scalars = values.compactMap { item -> String? in
                if let number = item as? NSNumber {
                    if CFGetTypeID(number) == CFBooleanGetTypeID() {
                        return number.boolValue ? "1" : "0"
                    }
                    return number.stringValue
                }
                return item as? String
            }
            if scalars.count == values.count { return scalars.joined(separator: "_") }
        }

        return nil
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
              

                payload = [
                    "type": "cookieData",
                    "cmpType": cmpType,
                    "tcstring": tcString,
                    "nontcfdata": nontcfdata,
                    "acstring": acString,
                    "gppstring": gppString,
                
                ]
            case "usprivacy":
                let gppString = UserDefaults.standard.string(forKey: "gppstring") ?? ""
             
                payload = [
                    "type": "cookieData",
                    "cmpType": cmpType,
                    "gppstring": gppString,
               
                ]
            case "standard":
                let gcString = UserDefaults.standard.string(forKey: "gcstring") ?? ""
     
                payload = [
                    "type": "cookieData",
                    "cmpType": cmpType,
                    "gcstring": gcString,
  
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

            // Every CMP type sends the PingReturn object in gppData.
            if let gppData = json["gppData"] as? [String: Any] {
                saveGPPData(gppData)
            }

            if cmpType == "tcf",
               let inAppTCData = (json["InAppTcData"] ?? json["inAppTCData"] ?? json["inAppTcData"])
                    as? [String: Any] {
                saveInAppTCData(inAppTCData)
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
