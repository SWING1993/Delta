//
//  UIAlertController+Importing.swift
//  Delta
//
//  Created by Riley Testut on 1/13/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

extension UIAlertController
{
    enum ImportType
    {
        case games
        case controllerSkins
    }
    
    class func alertController(for importType: ImportType, with errors: Set<DatabaseManager.ImportError>) -> UIAlertController
    {
        var urls = Set<URL>()
        
        for error in errors
        {
            switch error
            {
            case .doesNotExist(let url): urls.insert(url)
            case .invalid(let url): urls.insert(url)
            case .unsupported(let url): urls.insert(url)
            case .unknown(let url, _): urls.insert(url)
            case .saveFailed(let errorURLs, _): urls.formUnion(errorURLs)
            }
        }
        
        let title: String
        let message: String
        
        if let fileURL = urls.first, let error = errors.first, errors.count == 1
        {
            title = String(format: NSLocalizedString("无法导入“%@”.", comment: ""), fileURL.lastPathComponent)
            message = error.localizedDescription
        }
        else
        {
            switch importType
            {
            case .games: title = NSLocalizedString("导入游戏时出错", comment: "")
            case .controllerSkins: title = NSLocalizedString("导入控制器皮肤时出错", comment: "")
            }
            
            if urls.count > 0
            {
                var tempMessage: String
                
                switch importType
                {
                case .games: tempMessage = NSLocalizedString("无法导入以下游戏文件：", comment: "") + "\n"
                case .controllerSkins: tempMessage = NSLocalizedString("无法导入以下控制器皮肤文件：", comment: "") + "\n"
                }
                
                let filenames = urls.map { $0.lastPathComponent }.sorted()
                for filename in filenames
                {
                    tempMessage += "\n" + filename
                }
                
                message = tempMessage
            }
            else
            {
                // This branch can be executed when there are no input URLs when importing, but there is an error saving the database anyway.
                
                switch importType
                {
                case .games: message = NSLocalizedString("Delta 无法导入游戏，请稍后再试。", comment: "")
                case .controllerSkins: message = NSLocalizedString("Delta 无法导入控制器皮肤，请稍后再试。", comment: "")
                }
            }
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: RSTSystemLocalizedString("OK"), style: .cancel, handler: nil))
        return alertController
    }
}
