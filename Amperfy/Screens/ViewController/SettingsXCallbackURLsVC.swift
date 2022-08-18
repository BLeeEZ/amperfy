//
//  SettingsXCallbackURLsVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 12.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import AmperfyKit

class SettingsXCallbackURLsVC: UIViewController {
    
    var appDelegate: AppDelegate!
    var docuHeader = """
         <h1>Amperfy's X-Callback-URL Documentation</h1>
         <p>Amperfy's X-Callback-URL API can be used to perform actions from other Apps or via Siri Shortcuts.</p>
         <p>All available actions with their detail information can be found below:</p>
        """

    @IBOutlet weak var docuTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.license)
        updateView()
    }

    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        DispatchQueue.main.async {
            self.updateView()
        }
    }
    
    func updateView() {
        let docuRaw = Self.htmlDisplayContentStart(userInterfaceStyle: traitCollection.userInterfaceStyle) + docuHeader + appDelegate.intentManager.documentation.map( {self.createHtmlString(actionDocu: $0)}
        ).joined() + Self.htmlDisplayContentEnd
        let docuHtml = NSString(string: docuRaw).data(using: String.Encoding.utf8.rawValue)
        let options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html]
        let docuAttributedString = try! NSAttributedString(data: docuHtml!, options: options, documentAttributes: nil)
        docuTextView.attributedText = docuAttributedString
    }
    
    func createHtmlString(actionDocu: XCallbackActionDocu) -> String {
        var html = ""
        html += "<p>__________________________________</p>"
        html += "<h1>" + actionDocu.name + "</h1>"
        html += "<p>" + actionDocu.description + "</p>"
        html += "<p><b>Example URLs:</b>" + "</p>"
        for url in actionDocu.exampleURLs {
            html += "<p>- " + url + "</p>"
        }
        html += "<p><b>Action:</b> " + actionDocu.action + "</p>"
        
        if !actionDocu.parameters.isEmpty {
            html += "<p><b>Parameters:</b>" + "</p>"
        }
        for para in actionDocu.parameters {
            html += "<p></p>"
            html += "<h5>" + para.name
            if para.isMandatory {
                html += " <b>(mandatory)</b>"
            }
            html += "</h5>"
            html += "<p><b>Type:</b> " + para.type + "</p>"
            html += "<p><b>Description:</b> " + para.description + "</p>"
            if !para.isMandatory, let defaultValue = para.defaultIfNotGiven {
                html += "<p><b>Default:</b> " + defaultValue + "</p>"
            }
        }
        return html
    }
    
}
