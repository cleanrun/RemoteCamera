//
//  RoleChooserViewController.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import UIKit

final class RoleChooserViewController: UIViewController {
    
    deinit {
        //print("Role Chooser deinit")
    }

    @IBAction func hostAction(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HostViewController") as! HostViewController
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.last
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
    }
    
    @IBAction func streamerAction(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "StreamerViewController") as! StreamerViewController
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.last
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
    }
    
}
