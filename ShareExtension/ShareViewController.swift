import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            cancel()
            return
        }
        
        // Check for URL
        if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
            itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] item, error in
                if let url = item as? URL {
                    // Open in HermesClient via URL scheme
                    let urlString = "hermesclient://share?url=\(url.absoluteString)"
                    if let schemeURL = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(schemeURL, options: [:], completionHandler: nil)
                        }
                    }
                }
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
        // Check for text
        else if itemProvider.hasItemConformingToTypeIdentifier("public.plain-text") {
            itemProvider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] item, error in
                if let text = item as? String {
                    let urlString = "hermesclient://share?text=\(text)"
                    if let schemeURL = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(schemeURL, options: [:], completionHandler: nil)
                        }
                    }
                }
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } else {
            cancel()
        }
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
}
