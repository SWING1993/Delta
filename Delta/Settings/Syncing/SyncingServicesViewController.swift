//
//  SyncingServicesViewController.swift
//  Delta
//
//  Created by Riley Testut on 6/27/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import Harmony

import Roxas

extension SyncingServicesViewController
{
    enum Section: Int, CaseIterable
    {
        case syncing
        case service
        case account
        case authenticate
    }
    
    enum AccountRow: Int, CaseIterable
    {
        case name
        case emailAddress
    }
}

class SyncingServicesViewController: UITableViewController
{
    @IBOutlet private var syncingEnabledSwitch: UISwitch!
    
    private var selectedSyncingService = Settings.syncingService
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.syncingEnabledSwitch.onTintColor = .deltaPurple
        self.syncingEnabledSwitch.isOn = (self.selectedSyncingService != nil)
    }
}

private extension SyncingServicesViewController
{
    @IBAction func toggleSyncing(_ sender: UISwitch)
    {
        if sender.isOn
        {
            self.changeService(to: SyncManager.Service.allCases.first)
        }
        else
        {
            if SyncManager.shared.coordinator?.account != nil
            {
                let alertController = UIAlertController(title: NSLocalizedString("禁用同步？", comment: ""), message: NSLocalizedString("稍后再次启用同步可能会导致必须手动解决的冲突。", comment: ""), preferredStyle: .alert)
                alertController.addAction(.cancel)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("禁用", comment: ""), style: .default) { (action) in
                    self.changeService(to: nil)
                })
                self.present(alertController, animated: true, completion: nil)
            }
            else
            {
                self.changeService(to: nil)
            }
        }
    }
    
    func changeService(to service: SyncManager.Service?)
    {
        SyncManager.shared.reset(for: service) { (result) in
            DispatchQueue.main.async {
                do
                {
                    try result.get()
                    
                    let previousService = self.selectedSyncingService
                    self.selectedSyncingService = service
                    
                    // Set to non-nil if we later authenticate.
                    Settings.syncingService = nil
                                        
                    if (previousService == nil && service != nil) || (previousService != nil && service == nil)
                    {
                        self.tableView.reloadSections(IndexSet(integersIn: Section.service.rawValue ... Section.authenticate.rawValue), with: .fade)
                    }
                    else
                    {
                        self.tableView.reloadData()
                    }
                }
                catch
                {
                    let alertController = UIAlertController(title: NSLocalizedString("无法更改同步服务", comment: ""), error: error)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
}

private extension SyncingServicesViewController
{
    func isSectionHidden(_ section: Section) -> Bool
    {
        switch section
        {
        case .service: return !self.syncingEnabledSwitch.isOn
        case .account: return !self.syncingEnabledSwitch.isOn || SyncManager.shared.coordinator?.account == nil
        case .authenticate: return !self.syncingEnabledSwitch.isOn
        default: return false
        }
    }
}

extension SyncingServicesViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .syncing:
            cell.textLabel?.text = NSLocalizedString("同步中", comment: "")
            
        case .service:
            let service = SyncManager.Service.allCases[indexPath.row]
            cell.accessoryType = (service == self.selectedSyncingService) ? .checkmark : .none
            
        case .account:
            guard let account = SyncManager.shared.coordinator?.account else { return cell }
            
            let row = AccountRow(rawValue: indexPath.row)!
            switch row
            {
            case .name: cell.textLabel?.text = account.name
            case .emailAddress: cell.textLabel?.text = account.emailAddress
            }
            
        case .authenticate:
            if SyncManager.shared.coordinator?.account != nil
            {
                cell.textLabel?.textColor = .red
                cell.textLabel?.text = NSLocalizedString("退出登录", comment: "")
            }
            else
            {
                cell.textLabel?.textColor = .deltaPurple
                cell.textLabel?.text = NSLocalizedString("登录", comment: "")
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch Section.allCases[indexPath.section]
        {
        case .syncing: break
            
        case .service:
            let syncingService = SyncManager.Service.allCases[indexPath.row]
            guard syncingService != self.selectedSyncingService else { return }
            
            if SyncManager.shared.coordinator?.account != nil
            {
                let alertController = UIAlertController(title: NSLocalizedString("您确定要更改同步服务吗？", comment: ""), message: NSLocalizedString("稍后切换回来可能会导致必须手动解决的冲突。", comment: ""), preferredStyle: .actionSheet)
                alertController.addAction(.cancel)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("更改同步服务", comment: ""), style: .destructive, handler: { (action) in
                    self.changeService(to: syncingService)
                }))
                
                self.present(alertController, animated: true, completion: nil)
            }
            else
            {
                self.changeService(to: syncingService)
            }
            
        case .account: break
            
        case .authenticate:            
            if SyncManager.shared.coordinator?.account != nil
            {
                let alertController = UIAlertController(title: NSLocalizedString("您确定要退出吗？", comment: ""), message: NSLocalizedString("稍后再次登录可能会导致必须手动解决的冲突。", comment: ""), preferredStyle: .actionSheet)
                alertController.addAction(.cancel)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("登出", comment: ""), style: .destructive) { (action) in
                    SyncManager.shared.deauthenticate { (result) in
                        DispatchQueue.main.async {
                            do
                            {
                                try result.get()
                                self.tableView.reloadData()
                                
                                Settings.syncingService = nil
                            }
                            catch
                            {
                                let alertController = UIAlertController(title: NSLocalizedString("登出失败", comment: ""), error: error)
                                self.present(alertController, animated: true, completion: nil)
                            }
                        }
                    }
                })
                
                self.present(alertController, animated: true, completion: nil)
            }
            else
            {
                SyncManager.shared.authenticate(presentingViewController: self) { (result) in
                    DispatchQueue.main.async {
                        do
                        {
                            _ = try result.get()
                            self.tableView.reloadData()
                            
                            Settings.syncingService = self.selectedSyncingService
                        }
                        catch GeneralError.cancelled.self
                        {
                            // Ignore
                        }
                        catch
                        {
                            let alertController = UIAlertController(title: NSLocalizedString("登录失败", comment: ""), error: error)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        
        switch section
        {
        case let section where self.isSectionHidden(section): return 0
        case .account where SyncManager.shared.coordinator?.account?.emailAddress == nil: return 1
        default: return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return nil
        }
        else
        {
            return super.tableView(tableView, titleForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return 1
        }
        else
        {
            return super.tableView(tableView, heightForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return 1
        }
        else
        {
            return super.tableView(tableView, heightForFooterInSection: section.rawValue)
        }
    }
}
