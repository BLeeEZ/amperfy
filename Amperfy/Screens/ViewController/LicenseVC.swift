import Foundation
import UIKit

class LicenseVC: UIViewController {
    
    var appDelegate: AppDelegate!
    var license = """
         <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

         <html xmlns="http://www.w3.org/1999/xhtml">
         <head>
         <meta name="viewport" content="width=device-width, initial-scale=1.0" />
         <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />

         <title>Licenses</title>

         <style type="text/css">
         body {
             font-family: Helvetica, Arial, sans-serif;
             font-size: 11px;
             margin: 0;
             padding: 8px 16px;
             line-height: 1.3em;
         }

         h1 {
             font-size: 14px;
             color: #888;
             line-height: 1.3em;
         }

         h2 {
             font-size: 13px;
             color: #888;
         }

         h3 {
             font-size: 13px;
             color: #888;
             line-height: 2.6em;
         }

         p, ul, li {
             color: #888;
         }
         </style>
         </head>

         <body>

         <h1>Copyright © 2019-2021 Maximilian Bauer<br />
         All rights reserved.</h1>
         <p>GPLv3 Licensed</p>

         <p>__________________________________</p>

         <p>This software contains additional third party software.
         All the third party software included or linked is redistributed under the terms and conditions of their original licenses.</p>

         <p>__________________________________</p>

         <h3>LNPopupController</h3>
         <p>The MIT License (MIT)</p>
         <p>Copyright (c) 2015 Leo Natan</p>

         <p>Permission is hereby granted, free of charge, to any person obtaining a copy
         of this software and associated documentation files (the "Software"), to deal
         in the Software without restriction, including without limitation the rights
         to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
         copies of the Software, and to permit persons to whom the Software is
         furnished to do so, subject to the following conditions:</p>

         <p>The above copyright notice and this permission notice shall be included in all
         copies or substantial portions of the Software.</p>

         <p>THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
         IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
         FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
         AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
         LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
         OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
         SOFTWARE.</p>

         <p>__________________________________</p>

         <h3>MarqueeLabel</h3>
         <p>The MIT License (MIT)</p>
         <p>Copyright (c) 2011-2017 Charles Powell</p>
             
         <p>Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
         documentation files (the "Software"), to deal in the Software without restriction, including without limitation
         the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
         to permit persons to whom the Software is furnished to do so, subject to the following conditions:</p>

         <p>The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.</p>

         <p>THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
         TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
         THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
         CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
         IN THE SOFTWARE.</p>

         <p>__________________________________</p>

         <h3>NotificationBanner</h3>
         <p>The MIT License (MIT)</p>
         <p>Copyright (c) 2017-2018 Daltron &lt;daltonhint4@gmail.com&gt;</p>

         <p>Permission is hereby granted, free of charge, to any person obtaining a copy
         of this software and associated documentation files (the "Software"), to deal
         in the Software without restriction, including without limitation the rights
         to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
         copies of the Software, and to permit persons to whom the Software is
         furnished to do so, subject to the following conditions:</p>

         <p>The above copyright notice and this permission notice shall be included in
         all copies or substantial portions of the Software.</p>

         <p>THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
         IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
         FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
         AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
         LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
         OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
         THE SOFTWARE.</p>

         <p>__________________________________</p>

         <h3>CoreDataMigrationRevised-Example</h3>
         <p>MIT License</p>
         <p>Copyright (c) 2017 William Boles</p>

         <p>Permission is hereby granted, free of charge, to any person obtaining a copy
         of this software and associated documentation files (the "Software"), to deal
         in the Software without restriction, including without limitation the rights
         to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
         copies of the Software, and to permit persons to whom the Software is
         furnished to do so, subject to the following conditions:</p>

         <p>The above copyright notice and this permission notice shall be included in all
         copies or substantial portions of the Software.</p>

         <p>THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
         IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
         FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
         AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
         LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
         OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
         SOFTWARE.</p>

         <p>__________________________________</p>

         <h3>Font Awesome</h3>
         <p>Copyright (c) Font Awesome (https://fontawesome.com)</p>

         <p>Font Awesome Free License</p>

         <p>Font Awesome Free is free, open source, and GPL friendly. You can use it for
         commercial projects, open source projects, or really almost whatever you want.
         Full Font Awesome Free license: https://fontawesome.com/license/free.</p>

         <p><strong>Icons: CC BY 4.0 License (https://creativecommons.org/licenses/by/4.0/)</strong></br>
         In the Font Awesome Free download, the CC BY 4.0 license applies to all icons
         packaged as SVG and JS file types.</p>

         <p><strong>Fonts: SIL OFL 1.1 License (https://scripts.sil.org/OFL)</strong></br>
         In the Font Awesome Free download, the SIL OFL license applies to all icons
         packaged as web and desktop font files.</p>

         <p><strong>Code: MIT License (https://opensource.org/licenses/MIT)</strong></br>
         In the Font Awesome Free download, the MIT license applies to all non-font and
         non-icon files.</p>

         <p><strong>Attribution</strong></br>
         Attribution is required by MIT, SIL OFL, and CC BY licenses. Downloaded Font
         Awesome Free files already contain embedded comments with sufficient
         attribution, so you shouldn't need to do anything additional when using these
         files normally.</p>

         <p>We've kept attribution comments terse, so we ask that you do not actively work
         to remove them from files, especially code. They're a great way for folks to
         learn about Font Awesome.</p>

         <p><strong>Brand Icons</strong></br>
         All brand icons are trademarks of their respective owners. The use of these
         trademarks does not indicate endorsement of the trademark holder by Font
         Awesome, nor vice versa. **Please do not use brand logos for any purpose except
         to represent the company, product, or service to which they refer.**</p>

         <p>__________________________________</p>
         
         <h3>iOS 11 Glyphs</h3>
         <p>Copyright (c) Icons8 (https://icons8.com)</p>

         <p>Good Boy License (https://icons8.com/good-boy-license)</p>

         <p>Good Boy License We’ve released the icon pack under either MIT or the Good Boy License. We invented it. Please do whatever your mom would approve of:</p>

         <p><strong>Permitted Use</strong></p>

         <ul>
             <li>Download in any format</li>
             <li>Change</li>
             <li>Fork</li>
         </ul>

         <p><strong>Prohibited Use</strong></p>

         <ul>
             <li>No tattoos</li>
             <li>No touching with unwashed hands</li>
             <li>No exchanging for drugs.</li>
         </ul>



         </body>

         </html>
        """

    @IBOutlet weak var licenseTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.license)
        
        let licenseHtml = NSString(string: license).data(using: String.Encoding.utf8.rawValue)
        let options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html]
        let licendeAttributedString = try! NSAttributedString(data: licenseHtml!, options: options, documentAttributes: nil)
        licenseTextView.attributedText = licendeAttributedString
    }
    
}
