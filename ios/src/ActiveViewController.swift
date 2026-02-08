//
//  © 2024-present https://github.com/cengiz-pz
//

import UIKit

final class ActiveViewController {
    static func getActiveViewController() -> UIViewController? {
        // Find the foreground active window scene
        let foregroundScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        
        // Get the key window from that scene
        let keyWindow = foregroundScene?.windows.first { $0.isKeyWindow }
            ?? UIApplication.shared.windows.first
        
        guard let rootViewController = keyWindow?.rootViewController else {
            return nil
        }
        
        var activeVC: UIViewController = rootViewController
        
        // Climb presented view controllers
        while let presented = activeVC.presentedViewController {
            activeVC = presented
        }
        
        // Handle navigation & tab bar controllers
        if let nav = activeVC as? UINavigationController {
            activeVC = nav.topViewController ?? activeVC
        } else if let tab = activeVC as? UITabBarController,
                  let selected = tab.selectedViewController {
            activeVC = selected
            if let nav = selected as? UINavigationController {
                activeVC = nav.topViewController ?? activeVC
            }
        }
        
        return activeVC
    }
}
