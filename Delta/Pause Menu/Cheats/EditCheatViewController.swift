//
//  EditCheatViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/21/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore
import Roxas

protocol EditCheatViewControllerDelegate: class
{
    func editCheatViewController(_ editCheatViewController: EditCheatViewController, activateCheat cheat: Cheat, previousCheat: Cheat?)
    func editCheatViewController(_ editCheatViewController: EditCheatViewController, deactivateCheat cheat: Cheat)
}

private extension EditCheatViewController
{
    enum Section: Int
    {
        case name
        case type
        case code
    }
}

class EditCheatViewController: UITableViewController
{
    var game: Game! {
        didSet {
            let deltaCore = Delta.core(for: self.game.type)!
            self.supportedCheatFormats = deltaCore.supportedCheatFormats.sorted() { $0.name < $1.name }
        }
    }
    
    var cheat: Cheat?
    
    weak var delegate: EditCheatViewControllerDelegate?
    
    var isPreviewing = false
    
    private var supportedCheatFormats: [CheatFormat]!
    
    private var selectedCheatFormat: CheatFormat {
        let cheatFormat = self.supportedCheatFormats[self.typeSegmentedControl.selectedSegmentIndex]
        return cheatFormat
    }
    
    private var mutableCheat: Cheat!
    private var managedObjectContext = DatabaseManager.shared.newBackgroundContext()
    
    @IBOutlet private var nameTextField: UITextField!
    @IBOutlet private var typeSegmentedControl: UISegmentedControl!
    @IBOutlet private var codeTextView: CheatTextView!
    
    override var previewActionItems: [UIPreviewActionItem]
    {
        guard let cheat = self.cheat else { return [] }
        
        let copyCodeAction = UIPreviewAction(title: NSLocalizedString("复制代码", comment: ""), style: .default) { (action, viewController) in
            UIPasteboard.general.string = cheat.code
        }
        
        let presentingViewController = self.presentingViewController!
        
        let editCheatAction = UIPreviewAction(title: NSLocalizedString("编辑", comment: ""), style: .default) { (action, viewController) in
            // Delaying until next run loop prevents self from being dismissed immediately
            DispatchQueue.main.async {
                let editCheatViewController = viewController as! EditCheatViewController
                editCheatViewController.isPreviewing = false
                editCheatViewController.presentWithPresentingViewController(presentingViewController)
            }
        }
        
        let deleteAction = UIPreviewAction(title: NSLocalizedString("删除", comment: ""), style: .destructive) { [unowned self] (action, viewController) in
            self.delegate?.editCheatViewController(self, deactivateCheat: cheat)
            
            DatabaseManager.shared.performBackgroundTask { (context) in
                let temporaryCheat = context.object(with: cheat.objectID)
                context.delete(temporaryCheat)
                context.saveWithErrorLogging()
            }
        }
        
        let cancelDeleteAction = UIPreviewAction(title: NSLocalizedString("取消", comment: ""), style: .default) { (action, viewController) in
        }
        
        let deleteActionGroup = UIPreviewActionGroup(title: NSLocalizedString("删除", comment: ""), style: .destructive, actions: [deleteAction, cancelDeleteAction])
        
        return [copyCodeAction, editCheatAction, deleteActionGroup]
    }
}

extension EditCheatViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        var name: String!
        var type: CheatType!
        var code: String!
        
        self.managedObjectContext.performAndWait {
            
            // Main Thread context is read-only, so we either create a new cheat, or get a reference to the current cheat in a new background context
            
            if let cheat = self.cheat
            {
                self.mutableCheat = self.managedObjectContext.object(with: cheat.objectID) as? Cheat
            }
            else
            {
                self.mutableCheat = Cheat.insertIntoManagedObjectContext(self.managedObjectContext)
                self.mutableCheat.game = self.managedObjectContext.object(with: self.game.objectID) as? Game
                self.mutableCheat.type = self.supportedCheatFormats.first!.type
                self.mutableCheat.code = ""
                self.mutableCheat.name = ""
            }
            
            self.mutableCheat.isEnabled = true // After we save a cheat, it should be enabled
            
            name = self.mutableCheat.name
            type = self.mutableCheat.type
            code = self.mutableCheat.code.sanitized(with: self.selectedCheatFormat.allowedCodeCharacters)
        }

        
        // Update UI
        
        if name.count == 0
        {
            self.title = NSLocalizedString("金手指", comment: "")
        }
        else
        {
            self.title = name
        }
        
        self.nameTextField.text = name
        self.codeTextView.text = code
        
        self.typeSegmentedControl.removeAllSegments()
        
        for (index, format) in self.supportedCheatFormats.enumerated()
        {
            self.typeSegmentedControl.insertSegment(withTitle: format.name, at: index, animated: false)
        }
        
        if let index = self.supportedCheatFormats.firstIndex(where: { $0.type == type })
        {
            self.typeSegmentedControl.selectedSegmentIndex = index
        }
        else
        {
            self.typeSegmentedControl.selectedSegmentIndex = 0
        }
        
        self.updateCheatType(self.typeSegmentedControl)
        self.updateSaveButtonState()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        // This matters when going from peek -> pop
        // Otherwise, has no effect because viewDidLayoutSubviews has already been called
        if self.isAppearing && !self.isPreviewing
        {
            self.nameTextField.becomeFirstResponder()
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if let superview = self.codeTextView.superview
        {
            let layoutMargins = superview.layoutMargins
            if self.codeTextView.textContainerInset.left != layoutMargins.left
            {
                self.codeTextView.textContainerInset.left = layoutMargins.left // Don't change right inset because CheatTextView adjusts it as well.
                self.codeTextView.textContainer.lineFragmentPadding = 0
                self.codeTextView.setNeedsLayout()
            }
        }
        
        if self.isAppearing && !self.isPreviewing
        {
            self.nameTextField.becomeFirstResponder()
        }
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        self.nameTextField.resignFirstResponder()
        self.codeTextView.resignFirstResponder()
    }
}

internal extension EditCheatViewController
{
    func presentWithPresentingViewController(_ presentingViewController: UIViewController)
    {
        let navigationController = RSTNavigationController(rootViewController: self)
        navigationController.modalPresentationStyle = .overFullScreen // Keeps PausePresentationController active to ensure layout is not messed up
        navigationController.modalPresentationCapturesStatusBarAppearance = true
        
        presentingViewController.present(navigationController, animated: true, completion: nil)
    }
}

private extension EditCheatViewController
{
    @IBAction func updateCheatName(_ sender: UITextField)
    {
        var title = sender.text ?? ""
        if title.count == 0
        {
            title = NSLocalizedString("金手指", comment: "")
        }
        
        self.title = title
        
        self.updateSaveButtonState()
    }
    
    @IBAction func updateCheatType(_ sender: UISegmentedControl)
    {
        self.codeTextView.cheatFormat = self.selectedCheatFormat
        
        UIView.performWithoutAnimation {
            self.tableView.reloadSections(IndexSet(integer: Section.type.rawValue), with: .none)
            
            // Hacky-ish workaround so we can update the footer text for the code section without causing text view to resign first responder status
            self.tableView.beginUpdates()
            
            if let footerView = self.tableView.footerView(forSection: Section.code.rawValue)
            {
                footerView.textLabel!.text = self.tableView(self.tableView, titleForFooterInSection: Section.code.rawValue)
                footerView.sizeToFit()
            }
            
            self.tableView.endUpdates()
        }
        
        self.view.setNeedsLayout()
    }
    
    func updateSaveButtonState()
    {
        let isValidName = !(self.nameTextField.text ?? "").isEmpty
        let isValidCode = !self.codeTextView.text.isEmpty
        
        self.navigationItem.rightBarButtonItem?.isEnabled = isValidName && isValidCode
    }
    
    @IBAction func saveCheat(_ sender: UIBarButtonItem)
    {
        self.mutableCheat.managedObjectContext?.performAndWait {
            
            self.mutableCheat.name = self.nameTextField.text ?? ""
            self.mutableCheat.type = self.selectedCheatFormat.type
            self.mutableCheat.code = self.codeTextView.text.formatted(with: self.selectedCheatFormat)
            
            do
            {
                try self.validateCheat(self.mutableCheat)
                
                self.delegate?.editCheatViewController(self, activateCheat: self.mutableCheat, previousCheat: self.cheat)
                
                self.mutableCheat.managedObjectContext?.saveWithErrorLogging()
                self.performSegue(withIdentifier: "unwindEditCheatSegue", sender: sender)
            }
            catch CheatValidator.Error.invalidCode
            {
                self.presentErrorAlert(title: NSLocalizedString("无效代码", comment: ""), message: NSLocalizedString("请确保您正确输入了作弊码，然后重试。", comment: "")) {
                    self.codeTextView.becomeFirstResponder()
                }
            }
            catch CheatValidator.Error.invalidName
            {
                self.presentErrorAlert(title: NSLocalizedString("无效名称", comment: ""), message: NSLocalizedString("请重命名此作弊码再重试。", comment: "")) {
                    self.codeTextView.becomeFirstResponder()
                }
            }
            catch CheatValidator.Error.duplicateCode
            {
                self.presentErrorAlert(title: NSLocalizedString("重复代码", comment: ""), message: NSLocalizedString("此代码已存在，请输入其他代码再重试。", comment: "")) {
                    self.codeTextView.becomeFirstResponder()
                }
            }
            catch CheatValidator.Error.duplicateName
            {
                self.presentErrorAlert(title: NSLocalizedString("重复名称", comment: ""), message: NSLocalizedString("已存在同名代码，请重命名再重试。", comment: "")) {
                    self.nameTextField.becomeFirstResponder()
                }
            }
            catch
            {
                print(error)
                
                self.presentErrorAlert(title: NSLocalizedString("未知错误", comment: ""), message: NSLocalizedString("发生错误，请确保您正确输入了作弊码再重试。", comment: "")) {
                    self.codeTextView.becomeFirstResponder()
                }
            }
        }
    }
    
    func validateCheat(_ cheat: Cheat) throws
    {
        let validator = CheatValidator(format: self.selectedCheatFormat, managedObjectContext: self.managedObjectContext)
        try validator.validate(cheat)
    }
    
    @IBAction func textFieldDidEndEditing(_ sender: UITextField)
    {
        sender.resignFirstResponder()
    }
    
    func presentErrorAlert(title: String, message: String, handler: (() -> Void)?)
    {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { action in
                handler?()
            }))
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

extension EditCheatViewController
{
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        switch Section(rawValue: section)!
        {
        case .name: return super.tableView(tableView, titleForFooterInSection: section)
            
        case .type:
            let title = String.localizedStringWithFormat("Code format is %@.", self.selectedCheatFormat.format)
            return title
            
        case .code:
            let containsSpaces = self.selectedCheatFormat.format.contains(" ")
            let containsDashes = self.selectedCheatFormat.format.contains("-")
            
            switch (containsSpaces, containsDashes)
            {
            case (true, false): return NSLocalizedString("输入时将自动插入空格。", comment: "")
            case (false, true): return NSLocalizedString("输入时将自动插入破折号。", comment: "")
            case (true, true): return NSLocalizedString("输入时将自动插入空格和破折号。", comment: "")
            case (false, false): return NSLocalizedString("输入时自动格式化。", comment: "")
            }
        }
    }
}

extension EditCheatViewController: UITextViewDelegate
{
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    {
        defer { self.updateSaveButtonState() }
        
        guard text != "\n" else
        {
            textView.resignFirstResponder()
            return false
        }
        
        let sanitizedText = text.sanitized(with: self.selectedCheatFormat.allowedCodeCharacters)
        
        guard sanitizedText != text else { return true }
        
        // We need to manually add back the attributes when manually modifying the underlying text storage
        // Otherwise, pasting text into an empty text view will result in the wrong font being used
        let attributedString = NSAttributedString(string: sanitizedText, attributes: textView.typingAttributes)
        textView.textStorage.replaceCharacters(in: range, with: attributedString)
        
        // We must add attributedString.length, not range.length, in case the attributed string's length differs
        textView.selectedRange = NSRange(location: range.location + attributedString.length, length: 0)
        
        return false
    }
}
