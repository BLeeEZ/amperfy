import Foundation
import UIKit
import MessageUI

class SupportVC: UITableViewController, MFMailComposeViewControllerDelegate {
    
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
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
            if let attachmentData = LogData.collectInformation(appDelegate: appDelegate).asJSONData() {
                mailComposer.addAttachmentData(attachmentData, mimeType: "application/json", fileName: "AmperfyLog.json")
            }
            mailComposer.mailComposeDelegate = self
            self.present(mailComposer, animated: true, completion: nil)
        } else {
            appDelegate.eventLogger.info(message: "Email is not configured in settings app or Amperfy is not able to send an email")
        }
    }
    
    //MARK:- MailcomposerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

}
