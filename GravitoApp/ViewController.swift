//
//  ViewController.swift
//  GravitoApp
//
//  Created by Apple on 28/04/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit
import WebKit
import SwiftyJSON
struct eventBody {
    
    var data: String
    var event: String
    
}
class ViewController: UIViewController ,UIWebViewDelegate,WKScriptMessageHandler,UITextFieldDelegate{

    @IBOutlet weak var TOKEN: UITextField!
    
    @IBOutlet weak var webview: WKWebView!
    
    @IBOutlet weak var showToken: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.webview.uiDelegate = self as? WKUIDelegate
        TOKEN.delegate = self as UITextFieldDelegate
        self.loadTheUrl()
    }
    //----- FUNCTION TO LOAD HTML
    func loadTheUrl(){
        webview.configuration.userContentController.add(self, name: "jsHandler")
        webview.load(NSURLRequest(url: NSURL(string: "https://cdn.gravito.net/webview/index.html?platform=ios")! as URL) as URLRequest)
       
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
           if message.name == "jsHandler" {
           print(message.body)
            let json = message.body as! NSDictionary
            let event = json["event"] as! String
            print(event)
            
            
            switch event {
                        case "start":
                            //get data from storage
                            guard let tcstring=UserDefaults.standard.string(forKey:"tcstring") else {
                                return
                            }
                            print(tcstring)
                             let startjs = "window.postMessage('\(tcstring)', \"*\");true;"
                             webview.evaluateJavaScript(startjs, completionHandler: nil)
                        case "save":
                            let dataToStore=json["data"] as! String
                            // save this data to presisitable storage
                            UserDefaults.standard.set(dataToStore,forKey:"tcstring")
                        default: break
            
                        }

       }
      
       
    }
    
    @IBAction func LoadData(_ sender: Any) {
        let js = "hideText();"
        webview.evaluateJavaScript(js, completionHandler: nil)
    }
    
    @IBAction func SaveData(_ sender: Any) {
        
        let js = "showText();"
        webview.evaluateJavaScript(js, completionHandler: nil);
        
        // CODE TO SE DATA IN LOCALSTORAGE
        let msg =  UserDefaults.standard.string(forKey:"tcstring")
        TOKEN.text = msg
        
    }
    
}


