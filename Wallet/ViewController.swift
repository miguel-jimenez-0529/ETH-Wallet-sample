//
//  ViewController.swift
//  Wallet
//
//  Created by Macbook Pro on 15/05/18.
//  Copyright © 2018 Macbook Pro. All rights reserved.
//

import UIKit
import web3swift

class ViewController: UIViewController {

    @IBOutlet weak var txtImportAccount: UITextField!
    @IBOutlet weak var txtAmount: UITextField!
    @IBOutlet weak var txtReceiverAccount: UITextField!
    @IBOutlet weak var txtPassword: UITextField!
    @IBOutlet weak var txtConfirmPassword: UITextField!
    
    @IBOutlet weak var lblBalanceBBI: UILabel!
    @IBOutlet weak var lblBalance: UILabel!
    @IBOutlet weak var lblAddress: UILabel!
    
    @IBOutlet weak var cryptoSegmentedControl : UISegmentedControl!
    
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
            if self.cryptoSegmentedControl.selectedSegmentIndex == 0 {
                let txhash = manager.sendETH(to: txtReceiverAccount.text!, amount: txtAmount.text!, password: txtConfirmPassword.text!)
                showTransactionAlert(message: "TxHash: \( txhash ?? "No hash returned")")
            }
            else {
                do {
                    let txhash = try manager.sendTransactionToSmartContract(passphrase: txtConfirmPassword.text!, type: .BBI, method: .transfer(to: txtReceiverAccount.text!, value: txtAmount.text!))
                    showTransactionAlert(message: "TxHash: \(txhash)")
                }
                catch {
                    showTransactionAlert(message: error.localizedDescription)
                }
               
            }
        }
    }
    
    func showTransactionAlert(message : String) {
        let alertVC = UIAlertController(title: "Transaction Processed", message:  message, preferredStyle: UIAlertControllerStyle.alert)
        
        let action = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { _ in
            self.handleShowAccountDetails()
        }
        alertVC.addAction(action)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    @IBAction func refresh() {
        handleShowAccountDetails()
    }
    
    func handleShowAccountDetails() {
        let manager = Web3Manager.sharedInstance
        if manager.isThereAnAccount() {
            //************ Getting ETH Balance
            if let balance = manager.getAccountBalance() {
                lblBalance.text = "\(balance) ETH"
            }
            lblAddress.text = manager.getAccountAddress().address
            
            //************* Geting BBI Balance
            do {
                if let balance = try manager.callSmartContractFunction(type: .BBI, method: .balanceOf) {
                    self.lblBalanceBBI.text = "\(balance) BBI"
                }
            }
            catch {
                self.lblBalanceBBI.text = error.localizedDescription
            }
        }
    }
}

