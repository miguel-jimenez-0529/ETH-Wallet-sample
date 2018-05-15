//
//  ViewController.swift
//  Wallet
//
//  Created by Macbook Pro on 15/05/18.
//  Copyright © 2018 Macbook Pro. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var txtImportAccount: UITextField!
    @IBOutlet weak var txtAmount: UITextField!
    @IBOutlet weak var txtReceiverAccount: UITextField!
    @IBOutlet weak var txtPassword: UITextField!
    @IBOutlet weak var txtConfirmPassword: UITextField!
    
    @IBOutlet weak var lblBalance: UILabel!
    @IBOutlet weak var lblAddress: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if Web3Manager.sharedInstance.isThereAnAccount() {
            handleShowAccountDetails()
        }
    }

    @IBAction func handleImportAccount() {
        if txtPassword.text!.isEmpty || txtImportAccount.text!.isEmpty {
            return
        }
        Web3Manager.sharedInstance.importAccount(txtImportAccount.text!, txtPassword.text!)
        handleShowAccountDetails()
    }
    
    @IBAction func handleSendETH() {
        if txtAmount.text!.isEmpty || txtReceiverAccount.text!.isEmpty || txtConfirmPassword.text!.isEmpty {
            return
        }
        let manager = Web3Manager.sharedInstance
        if manager.isThereAnAccount() {
            let txhash = manager.sendETH(to: txtReceiverAccount.text!, amount: txtAmount.text!, password: txtConfirmPassword.text!)
            let alertVC = UIAlertController(title: "Transaction Processed", message: "TxHash: \( txhash ?? "No hash returned")", preferredStyle: UIAlertControllerStyle.alert)
            
            let action = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { _ in
                self.handleShowAccountDetails()
            }
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    func handleShowAccountDetails() {
        let manager = Web3Manager.sharedInstance
        if manager.isThereAnAccount() {
            if let balance = manager.getAccountBalance() {
                lblBalance.text = "\(balance) ETH"
            }
            lblAddress.text = manager.getAccountAddress().address
        }
    }
}

