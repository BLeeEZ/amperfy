//
//  SupportVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.05.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import MessageUI
import AmperfyKit

class SupportVC: UITableViewController, MFMailComposeViewControllerDelegate {
    
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.settingsSupport)
    }
    
    @IBAction func issueReportPressed(_ sender: Any) {
        if let url = URL(string: "https://github.com/BLeeEZ/amperfy/issues") {
            UIApplication.shared.open(url)
        }
    }
    
    @IBAction func sendLogFilePressed(_ sender: Any) {
        if MFMailComposeViewController.canSendMail() {
            let mailComposer = MFMailComposeViewController()
            mailComposer.setSubject("Amperfy support")
            var messageBody = ""
            messageBody += "\nPlease describe your issue."
            messageBody += "\nFeedback is always welcome too."
            messageBody += "\n"
            messageBody += "\n"
            messageBody += "--- Please don't remove the attachment ---"
            mailComposer.setMessageBody(messageBody, isHTML: false)
            mailComposer.setToRecipients(["amperfy@familie-zimba.de"])
            if let attachmentData = LogData.collectInformation(amperfyData: AmperKit.shared).asJSONData() {
                mailComposer.addAttachmentData(attachmentData, mimeType: "application/json", fileName: "AmperfyLog.json")
            }
            mailComposer.mailComposeDelegate = self
            self.present(mailComposer, animated: true, completion: nil)
        } else {
            appDelegate.eventLogger.info(topic: "Email Info", statusCode: .emailError, message: "Email is not configured in settings app or Amperfy is not able to send an email.", displayPopup: true)
        }
    }
    
    //MARK:- MailcomposerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

}
