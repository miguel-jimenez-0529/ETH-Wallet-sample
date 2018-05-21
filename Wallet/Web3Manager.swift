import BigInt
import web3swift

final class Web3Manager {
    
    static var sharedInstance : Web3Manager {
        return Web3Manager()
    }
    
    private var web3 : web3
    
    private init() {
        web3 = Web3.InfuraMainnetWeb3()
    }
    
    private enum File: String {
        case KeyStore
    }
    private enum PrivateKeyFormat {
        case Base10
        case Base16
        case Error
    }
    
    private enum PrivateKeyError: Error {
        case InvalidPrivateKey
    }
    public enum SmartContractType {
        case BBI
        case Test
        
        var abi : String {
            switch self {
            case .BBI:
                return "bbi"
            case .Test:
                return "test"
            }
        }
        
        var contractAddress : String {
            switch self {
            case .BBI:
                return "0x37d40510a2f5bc98aa7a0f7bf4b3453bcfb90ac1"
            case .Test:
                return "0x..."
            }
        }
    }
    public enum SmartContractMethod  {
        case balanceOf
        case transfer(to: String, value : String)
        
        var functionName : String {
            switch self {
            case .balanceOf:
                return "balanceOf"
            case .transfer:
                return "transfer"
            }
        }
        
        var params : [AnyObject] {
            switch self {
            case .balanceOf:
                return [Web3Manager.sharedInstance.getAccountAddress() as AnyObject]
            case .transfer(to: let to, value: let value):
                let amount = BigUInt(value)
                let toAddress = EthereumAddress(to)
                return [toAddress as AnyObject, amount as AnyObject]
            }
        }
    }
    private enum SmartContractError: Error {
        case InvalidMethod
        case SmartContractFailure
        case TransactionSigningFailure
        case TXHashReceiveFailure
        case Web3ProviderNotFound
    }
    
    // Crear y/o obtener la ruta del directorio donde se guardará el JSON v3.
    private func getFilePath(_ type: File) -> String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = url.appendingPathComponent(type.rawValue)
        
        if !FileManager.default.fileExists(atPath: folder.path) {
            try! FileManager.default.createDirectory(atPath: folder.path, withIntermediateDirectories: true, attributes: nil)
        }
        
        switch type {
        case .KeyStore:
            return folder.path
        }
    }
    
    // Función para manejar un número en decimal y convertirlo en hexadecimal, o en caso de ya ser un hexadecimal, validar si cumple con el tamaño de una address de ETH.
    // Nota: Eliminar el "0x" del string de la private key antes de pasarlo a esta función.
    private func getPrivateKeyFormat(_ privateKey: String) -> PrivateKeyFormat {
        var isHex = false
        var token: PrivateKeyFormat!
        
        for character in privateKey.lowercased() {
            switch String(character) {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                if !isHex {
                    token = .Base10
                }
            case "a", "b", "c", "d", "e", "f":
                token = .Base16
                isHex = true
            default:
                return .Error
            }
        }
        
        return token
    }
    
    // Obtener el KeyStore Manager, el cual permite firmar las transacciones junto con el passphrase, además de ser necesario para otras funciones.
    private func getKeyStoreManager() -> KeystoreManager {
        let path = self.getFilePath(.KeyStore)
        let keystoreManager = KeystoreManager.managerForPath(path)!
        
        return keystoreManager
    }
    
    // Checar si existe ya una o más cuentas.
    public func isThereAnAccount() -> Bool {
        let keystoreManager = self.getKeyStoreManager()
        
        return keystoreManager.addresses!.count > 0
    }
    
    // Creación de la cuenta, el nombre del archivo JSON puede cualquiera.
    public func createAccount(_ passphrase: String) {
        do {
            let newAccount = try EthereumKeystoreV3(password: passphrase)
            let jsonv3 = try JSONEncoder().encode(newAccount!.keystoreParams)
            let path = self.getFilePath(.KeyStore)
            
            FileManager.default.createFile(atPath: "\(path)/Account.json", contents: jsonv3, attributes: nil)
        }
        catch {
            print("Error trying to create the account: \(error.localizedDescription)")
        }
    }
    
    // Importación de la cuenta, es obligatorio pasar una passphrase para poder crear el archivo JSON v3, en caso de omitirlo puede importarse la cuenta sólo con la private key, pero la firma deberá realizarse con la misma private key (siendo está convertida de "String" a "Data") y deberá crearse algún método para mantener esta llave protegida.
    
    public func isValid(privateKey : String) -> Bool {
        switch self.getPrivateKeyFormat(privateKey) {
        case .Base10:
            let base10 = BigUInt(stringLiteral: privateKey)
            let base16 = String(base10, radix: 16)
            
            return base16.count != 64 ? false : true
        case .Base16:
            return privateKey.count != 64 ? false : true
        case .Error:
            return false
        }
    }
    
    @discardableResult
    public func importAccount(_ mnemonics: [String], _ passphrase: String) -> Bool {
        
        let bip32keystoreManager = self.getKeyStoreManager()
        var bip32ks: BIP32Keystore?
        if bip32keystoreManager.addresses?.count == 0 {
            bip32ks = try! BIP32Keystore.init(mnemonics: mnemonics.reduce(into: "", { (res, val) in res += " \(val)" }), mnemonicsPassword: "", language: .english)
            let keydata = try! JSONEncoder().encode(bip32ks!.keystoreParams)
            
            let path = self.getFilePath(.KeyStore)
            FileManager.default.createFile(atPath: "\(path)/Account.json", contents: keydata, attributes: nil)
            return true
        }
        return false
    }

    
    @discardableResult
    public func importAccount(_ privateKey: String, _ passphrase: String) -> Bool {
        do {
            var privateKeyData = Data()
            
            switch self.getPrivateKeyFormat(privateKey) {
            case .Base10:
                let base10 = BigUInt(stringLiteral: privateKey)
                let base16 = String(base10, radix: 16)
                
                if base16.count != 64 {
                    throw PrivateKeyError.InvalidPrivateKey
                }
                
                privateKeyData = Data.fromHex(base16)!
            case .Base16:
                if privateKey.count != 64 {
                    throw PrivateKeyError.InvalidPrivateKey
                }
                
                privateKeyData = Data.fromHex(privateKey)!
            case .Error:
                throw PrivateKeyError.InvalidPrivateKey
            }
            
            let path = self.getFilePath(.KeyStore)
            let importedAccount = try EthereumKeystoreV3.init(privateKey: privateKeyData, password: passphrase)//.init(privateKey: privateKeyData)
            let jsonv3 = try JSONEncoder().encode(importedAccount!.keystoreParams)
            
            FileManager.default.createFile(atPath: "\(path)/Account.json", contents: jsonv3, attributes: nil)
            return true
        }
        catch {
            print("Error trying to import the account: \(error.localizedDescription)")
            return false
        }
    }
    
    public func deleteAccount() {
        let directory = self.getFilePath(.KeyStore)
        let path = "\(directory)/Account.json"
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
    
    public func getAccountBalance() -> String? {
        if isThereAnAccount(), let balance = web3.eth.getBalance(address: self.getAccountAddress()).value {
            return Web3.Utils.formatToEthereumUnits(balance, toUnits: .eth, decimals: 8)//balance
        }
        return nil
    }
    
    // Obtener la address de la cuenta.
    public func getAccountAddress() -> EthereumAddress {
        let keystoreManager = self.getKeyStoreManager()
        
        return keystoreManager.addresses!.first!
    }
    
    // Obtener la private key de la cuenta, siempre y cuando se haya decidido crear el archivo JSON v3 (esto en el caso de importar la cuenta).
    public func getAccountPrivateKey(_ passphrase: String) throws -> String {
        let accountAddress = self.getAccountAddress()
        let keystoreManager = self.getKeyStoreManager()
        let privateKeyData = try keystoreManager.UNSAFE_getPrivateKeyData(password: passphrase, account: accountAddress)
        
        return privateKeyData.bytes.toHexString()
    }
    
    public func getAccountSeed() -> String {
        return "Implenet this method please :)"
    }
    
    // Función para obtener el archivo JSON que contenga el ABI del smart contract y su respectiva address. Es obligatorio añadir a la app el archivo JSON con el ABI o al menos el string completo de dicho ABI resguardado en una constante de tipo String.
    private func getSmartContractParams(_ type: SmartContractType) ->  (abi : String, address: EthereumAddress) {
        let path = Bundle.main.path(forResource: type.abi, ofType: "json")!
        let abi = try! String(contentsOf: URL(fileURLWithPath: path))
        return (abi, EthereumAddress(type.contractAddress))
    }
    
    
    
    // Función que firma y manda una transacción a un smart contract.
    // Nota: Aún no se ha probado para realizar firma de transacciones cuando son transferencias entre cuentas, para eso checar el único ejemplo que tiene la librería.
    public func sendTransactionToSmartContract(passphrase: String, type: SmartContractType, method: SmartContractMethod) throws -> String {
        
        let keystoreManager = self.getKeyStoreManager()
        let smartcontractABI = self.getSmartContractParams(type).abi
        let smartcontractAddress = self.getSmartContractParams(type).address
        var options = Web3Options()
        
        web3.addKeystoreManager(keystoreManager)
        
        options.from = self.getAccountAddress()
        options.to = smartcontractAddress
        options.gasPrice = BigUInt(0x028fa6ae00) //180,000
        options.gasLimit = BigUInt(0x02bf20)//11 Gwei
        options.value = BigUInt("0")
        
        guard let smartcontract = web3.contract(smartcontractABI, at: smartcontractAddress) else {
            throw SmartContractError.SmartContractFailure
        }
        
        guard let intermediate = smartcontract.method(method.functionName, parameters: method.params , options: options) else {
            throw SmartContractError.InvalidMethod
        }
    
        intermediate.transaction.nonce = web3.eth.getTransactionCount(address: self.getAccountAddress()).value!
        
        guard web3.wallet.signTX(transaction: &intermediate.transaction, account: self.getAccountAddress(), password: passphrase).value! else {
            throw SmartContractError.TransactionSigningFailure
        }
        guard let result = intermediate.sendSigned().value else {
            throw SmartContractError.TXHashReceiveFailure
        }
        
        let resultCall =  intermediate.call(options: options)
        resultCall.analysis(ifSuccess: { (values) in
            if  let intValue = values["0"] as? BigUInt,
                let ether = Web3.Utils.formatToEthereumUnits(intValue, toUnits: Web3.Utils.Units.eth, decimals: 2) {
                print(ether)
            }
        }, ifFailure: { (error) in
            print(error)
        })
        
        return result["txhash"]!
    }
    
    public func sendETH(to address : String, amount : String, password : String) -> String? {
        let sendToAddress = EthereumAddress(address)
        web3.addKeystoreManager(self.getKeyStoreManager())
        
        let contract = web3.contract(Web3.Utils.coldWalletABI, at: sendToAddress, abiVersion: 2)
        var options = Web3Options.defaultOptions()
        options.value = Web3.Utils.parseToBigUInt(amount, units: .eth)
        options.from = self.getAccountAddress()
        let intermediate = contract?.method("fallback", options: options)
        guard let result = intermediate?.send(password: password) else {return nil }
        switch result {
        case .success(_):
                return result.value!["txhash"]
        case .failure(let error):
            guard case .unknownError = error else {return nil }
            return nil
        }
    }
    
    func testEthSendExample() {
        
        self.importAccount("YOUR_PRIVATE_KEY", "YOUR_PASS")
        guard let balance = web3.eth.getBalance(address: self.getAccountAddress()).value else {
            return
        }
        print(balance)
        
        let sendToAddress = EthereumAddress("TO_ADDRESS")
        
         web3.addKeystoreManager(self.getKeyStoreManager())
        
        let contract = web3.contract(Web3.Utils.coldWalletABI, at: sendToAddress, abiVersion: 2)
        var options = Web3Options.defaultOptions()
        options.value = Web3.Utils.parseToBigUInt("0.1", units: .eth)
        options.from = self.getAccountAddress()
        let intermediate = contract?.method("fallback", options: options)
        guard let result = intermediate?.send(password: "YOUR_PASS") else {return }
        switch result {
        case .success(_):
            return
        case .failure(let error):
            guard case .unknownError = error else {return }
        }
    }
    
    func callSmartContractFunction(type: SmartContractType, method: SmartContractMethod) throws -> BigUInt? {
        
        let keystoreManager = self.getKeyStoreManager()
        let smartcontractABI = self.getSmartContractParams(type).abi
        let smartcontractAddress = self.getSmartContractParams(type).address
        var options = Web3Options()
        
        web3.addKeystoreManager(keystoreManager)
        
        options.from = self.getAccountAddress()
        options.to = smartcontractAddress
        options.value = "0"
        
        guard let smartcontract = web3.contract(smartcontractABI, at: smartcontractAddress) else {
            throw SmartContractError.SmartContractFailure
        }
        
        guard let intermediate = smartcontract.method(method.functionName, parameters: method.params , options: options) else {
            throw SmartContractError.InvalidMethod
        }
        
        intermediate.transaction.nonce = web3.eth.getTransactionCount(address: self.getAccountAddress()).value!
        
        let resultCall =  intermediate.call(options: options)
        switch resultCall {
        case .success(let values):
            print(values)
            return values["0"] as? BigUInt
        case .failure(let error):
            throw error
        }
    }
    
    func prepareRawTransaction(from address : EthereumAddress, gasLimit : BigUInt) {
        web3.addKeystoreManager(self.getKeyStoreManager())
        
        let contract = web3.contract(Web3.Utils.coldWalletABI, at: address, abiVersion: 2)
        var options = Web3Options.defaultOptions()
        options.value = Web3.Utils.parseToBigUInt("0.1", units: .eth)
        options.gasLimit = gasLimit
        options.from = self.getAccountAddress()
        if let intermediate = contract?.method("fallback", options: options) {
            intermediate.transaction.nonce = web3.eth.getTransactionCount(address: address).value!
            intermediate.transaction.gasPrice = web3.eth.estimateGas(intermediate.transaction, options: options).value!
            web3.wallet.signTX(transaction: &intermediate.transaction, account: address)
            let result = intermediate.sendSigned().value
            print(result)
        }
    }
}
