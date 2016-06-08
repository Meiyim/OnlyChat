//
//  RegistrationViewController.swift
//  OnlyChat
//
//  Created by 工作 on 16/5/20.
//  Copyright © 2016年 ChenXuyi. All rights reserved.
//

import UIKit
import ImagePicker
import Alamofire

protocol RegistrationViewControllerDelegate{
    func registrationViewController(controller: RegistrationViewController,registerID: String, registerName: String);
}

class RegistrationViewController: UITableViewController {
    let indexPathForEmailTextField = NSIndexPath(forRow: 0, inSection: 0)
    let indexPathForNameTextField = NSIndexPath(forRow:0 ,inSection: 1)
    let indexPathForCodeTextField = NSIndexPath(forRow:0 ,inSection: 2)
    let indexPathForSendCode = NSIndexPath(forRow: 1, inSection: 0);
    let indexPathForRegister = NSIndexPath(forRow: 0, inSection: 3);
    let indexPathForDisplayName = NSIndexPath(forRow: 0, inSection:1);
    let indexPathForSelectPhoto = NSIndexPath(forRow: 1, inSection: 1);
    
    let portraitPath = documentDirectory() + ("/myPortrait.jpg");
    
    let REGISTRATION_SERVER_ADDRESS = "http://localhost:8888/register"
    let UPLOAD_ADDRESS = "http://localhost:8888/upload"
    
    var delegate: RegistrationViewControllerDelegate?
    var image: UIImage?
    var downUploadRequest: Alamofire.Request? = nil
    var varificationCodeSent = false;
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var displayNameTextField: UITextField!
    @IBOutlet weak var varificationCodeTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var addPhotoLabel: UILabel!
    //MARK: - IBACtion
    @IBAction func cancel(sender: UIBarButtonItem){
        dismissViewControllerAnimated(true, completion: nil);
    }
    
    //MARK: - utility

    private func showAlert(title: String, OKButton: String,handler: ((UIAlertAction)->())? = nil ){
        let alert = UIAlertController(title: title, message: "", preferredStyle: .Alert) //i18n
        let action1 = UIAlertAction(title: OKButton, style: .Destructive, handler: handler)
        alert.addAction(action1)
        presentViewController(alert, animated: true, completion: nil);
    }
    private func saveImageToLocal(){
        guard let img = image else {
            return
        }
        let localurl = portraitPath
        UIImageJPEGRepresentation(img, 1.0)?.writeToFile(localurl, atomically: true)
    }
    
    //MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Registration"
        varificationCodeSent = false;
        imageView.hidden = true
        addPhotoLabel.hidden = false

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        //updateUI();
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateUI(){
        let cell1 = tableView.dataSource!.tableView(tableView, cellForRowAtIndexPath:indexPathForRegister);
        let cell2 = tableView.dataSource!.tableView(tableView, cellForRowAtIndexPath:indexPathForSendCode);

        if varificationCodeSent {
            cell1.textLabel!.textColor = self.view.tintColor;
            cell2.textLabel!.textColor = UIColor.grayColor();
            self.emailTextField.resignFirstResponder();
            self.emailTextField.enabled = false;
            self.emailTextField.textColor = UIColor.grayColor();
            
        }else{
            cell1.textLabel!.textColor = UIColor.grayColor()
            cell2.textLabel!.textColor = self.view.tintColor;
            emailTextField.enabled = true;
            emailTextField.textColor = UIColor.blackColor();
            displayNameTextField.text = ""
            varificationCodeTextField.text = ""
        }
        //tableView.reloadRowsAtIndexPaths([indexPathForRegister], withRowAnimation: .Fade);
        if let img = image{
            imageView.image = img
            imageView.hidden = false
            //imageView.frame = CGRect(x: 10, y: 10, width: 160, height: 260)
            addPhotoLabel.hidden = true;
            imageView.layer.cornerRadius = 10
            imageView.layer.masksToBounds = true;
            //print(imageView.bounds)
        }
        tableView.reloadData();
        print("ui updated")
    }

    //MARK: - HTTP request
    private func askServerForVarificationCode(id:String){
        varificationCodeSent = false;
        Alamofire.request(.POST,REGISTRATION_SERVER_ADDRESS,parameters:["request":"code", "id":id])
            .validate()//auto validate
            .responseJSON(completionHandler: { response in
                if response.result.isFailure {
                    dispatch_async(dispatch_get_main_queue()){self.showAlert("something is wrong with the server", OKButton: "OK")}
                }
                let json = response.result.value!
                let answer = json["response"] as! String;
                dispatch_async(dispatch_get_main_queue()){
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    switch(answer){
                    case "codeSent":
                        self.varificationCodeSent = true;
                        self.updateUI();
                        return;
                    case "codeSentOldUser":
                        self.showAlert("Hello Old User, You need to varify youself again", OKButton: "OK", handler: nil)
                        self.varificationCodeSent = true;
                        let cell = self.tableView!.cellForRowAtIndexPath(self.indexPathForDisplayName)!
                        let textField = cell.contentView.viewWithTag(100) as! UITextField;
                        textField.text = json["oldUsername"] as! String
                        self.updateUI();
                        return;
                    case "emailInvalid":
                        self.showAlert("illegal email address, pls check your spelling", OKButton: "OK", handler: nil)
                    default:
                        self.showAlert("something is wrong with the server: \(answer)", OKButton: "OK", handler: nil)
                    }
                }
                
            })
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
    }
    private func registerForID(id:String, displayName:String, varificationCode: String){
        varificationCodeSent = false;
        Alamofire.request(.POST,REGISTRATION_SERVER_ADDRESS,parameters:["request":"register", "id":id, "name":displayName, "code":varificationCode])
            .validate()//auto validate
            .responseJSON(completionHandler: { response in
                if response.result.isFailure {
                    dispatch_async(dispatch_get_main_queue()){self.showAlert("something is wrong with the server", OKButton: "OK")}
                }
                let json = response.result.value!
                let answer = json["response"] as! String;
                dispatch_async(dispatch_get_main_queue()){
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    switch(answer){
                    case "registed":
                        fallthrough
                    case "oldUser":
                        let downloadID = json["oldUserMongoID"] as? String
                        //assert(oldName==displayName)
                        /*
                        self.showAlert("Registration Suceeded, Welcome: \(displayName)", OKButton: "OK",handler:{ _ in
                            self.dismissViewControllerAnimated(true, completion: {_ in
                                self.delegate?.registrationViewController(self,registerID: id, registerName:  oldName);
                            })
                        })*/
                        self.showAlert("Registration Complete, Welcome", OKButton: "OK"){ _ in
                            if answer=="oldUser" && self.image == nil{
                                self.downloadPortrait(downloadID!);
                            }else{
                                self.uploadPortrait(id);
                            }
                        }
        
                    case "codeWrong":
                        self.showAlert("Invalide Varification Code", OKButton: "OK", handler: nil)
                    case "nameWrong":
                        self.showAlert("Invalide nick name", OKButton: "OK", handler: nil)
                        
                    default:
                        self.showAlert("something is wrong with the server: \(answer)", OKButton: "OK", handler: nil)
                    }
                    self.varificationCodeSent = false;
                    self.updateUI();

                }
                
            })
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    private func downloadPortrait(id: String){
        downUploadRequest?.cancel();
        downUploadRequest = Alamofire.download(.GET, UPLOAD_ADDRESS,parameters: ["downloadID":id]){ _ in
            
            return NSURL(fileURLWithPath: self.portraitPath)
        }.response{  _,_,_,err in
            if let e = err {
                self.showAlert("download error", OKButton: "OK")
            }
        }
    }
    private func uploadPortrait(email: String){
        guard let img = image else{
            assert(false)
        }
        downUploadRequest?.cancel()
        var data: NSData! = nil
        if let _d = UIImageJPEGRepresentation(img, 1.0){
            data = _d;
        }else if let _d = UIImagePNGRepresentation(img){
            data = _d
        }
        
        downUploadRequest =  Alamofire.upload(.POST,UPLOAD_ADDRESS,headers: ["filename": email],data: data)
            .validate()
            .responseString(completionHandler: { response in
                //let json = response.result.value!
                //let answer = json["response"] as! String;
                if response.result.isFailure {
                    dispatch_async(dispatch_get_main_queue()){self.showAlert("Upload Failed", OKButton: "OK")}
                }
                dispatch_async(dispatch_get_main_queue()){
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    let answer =  response.result.value!
                    if answer == "succeed"{
                        self.showAlert("upload succeed", OKButton: "OK", handler: nil)
                        self.saveImageToLocal();
                    }else{
                        self.showAlert("something is wrong with the server: \(answer)", OKButton: "OK", handler: nil)
                    }
                }
                //debugPrint(response)
            })
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true

    }
    
    /*
    private func askServerForVarificationCode(id:String){
        varificationCodeSent = false;
        
        let request = getPostHttpRequest();
        let param = String(format: "request=%@&id=%@","code",id);
        let body = param.dataUsingEncoding(NSUTF8StringEncoding)
        request.HTTPBody = body;
        registrationTask = NSURLSession.sharedSession().dataTaskWithRequest(request,completionHandler: {
            data ,response, error in
            if let err = error {
                if err.code == -999 {return;}
                print("http request wrong err:\(err.localizedDescription)");
            }else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let json = parseJSON(data!)!
                    let answer = json["response"] as! String;
                    print(answer);
                    dispatch_async(dispatch_get_main_queue()) {//UI update code should always in the main queue
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        switch(answer){
                        case "codeSent":
                            self.varificationCodeSent = true;
                            self.updateUI();
                            return;
                        case "codeSentOldUser":
                            self.showAlert("Hello Old User, You need to varify youself again", OKButton: "OK", handler: nil)
                            self.varificationCodeSent = true;
                            let cell = self.tableView!.cellForRowAtIndexPath(self.indexPathForDisplayName)!
                            let textField = cell.contentView.viewWithTag(100) as! UITextField;
                            textField.text = json["oldUsername"] as! String
                            self.updateUI();
                            return;
                        case "emailInvalid":
                            self.showAlert("illegal email address, pls check your spelling", OKButton: "OK", handler: nil)
                        default:
                            self.showAlert("something is wrong with the server: \(answer)", OKButton: "OK", handler: nil)
                        }
                    }
                }
                
            }
        })
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        registrationTask?.resume();
        
    }
    private func registerForID(id:String, displayName:String, varificationCode: String){
        let registerRequest = getPostHttpRequest();
        let param = String(format: "request=%@&id=%@&name=%@&code=%@","register",id,displayName,varificationCode);
        let body = param.dataUsingEncoding(NSUTF8StringEncoding)!
        registerRequest.HTTPBody = body;
        registrationTask = NSURLSession.sharedSession().dataTaskWithRequest(registerRequest, completionHandler: {
            data, response, error in
            if let err = error {
                if err.code == -999 {return;}
                print("http request wrong err:\(err.localizedDescription)");
            }else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let json = parseJSON(data!)!
                    let answer = json["response"] as! String;
                    print(answer);
                    dispatch_async(dispatch_get_main_queue()) {
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        switch(answer){
                        case "registed":
                            self.showAlert("Registration Suceeded, Welcome initiate", OKButton: "OK",handler:{ _ in
                                self.dismissViewControllerAnimated(true, completion: {_ in
                                    self.delegate?.registrationViewController(self,registerID: id, registerName:  displayName);
                                })
                            })
                        case "oldUser":
                            let oldName = json["oldUsername"] as! String
                            assert(oldName==displayName)
                            self.showAlert("Welcome Back Again: \(oldName)", OKButton: "OK",handler:{ _ in
                                self.dismissViewControllerAnimated(true, completion: {_ in
                                    self.delegate?.registrationViewController(self,registerID: id, registerName:  oldName);
                                })
                            })
                        case "codeWrong":
                            self.showAlert("Invalide Varification Code", OKButton: "OK", handler: nil)
                        case "nameWrong":
                            self.showAlert("Invalide nick name", OKButton: "OK", handler: nil)

                        default:
                            self.showAlert("something is wrong with the server: \(answer)", OKButton: "OK", handler: nil)
                        }
                        self.varificationCodeSent = false;
                        self.updateUI();
                    }
                }
            }
            
            
        })
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        registrationTask?.resume();
    }

    private func getPostHttpRequest()->NSMutableURLRequest{
        let urlString = "http://localhost:8888/register".stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!;
        let url = NSURL(string: urlString)!;
        print(url);
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod="POST";
        return request;
        
    }
    */
    // MARK: - Table view data source
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        defer{
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
        if indexPath == indexPathForRegister {
            guard var code = varificationCodeTextField.text else {
                showAlert("please input varification code", OKButton: "OK", handler: nil)
                return
            }
            code = code.uppercaseString
            if code.characters.count != 6 {
                showAlert("varification code should be 6 characters", OKButton: "OK", handler: nil)
                return
            }
            guard let name = displayNameTextField.text else{
                showAlert("please input your nickname", OKButton: "OK", handler: nil)
                return
            }
            if image == nil {
                showAlert("pls upload a portrait", OKButton: "OK")
                return
            }
            assert(emailTextField.text != nil)
            registerForID(emailTextField.text!, displayName: name, varificationCode: code)
        }else if indexPath == indexPathForSendCode{
            guard let id = emailTextField.text else {
                showAlert("please enter your email", OKButton: "OK", handler: nil)
                return;
            }
            if !id.isEmail() {
                showAlert("illegal email", OKButton: "OK", handler: nil)
                return;
            }

            askServerForVarificationCode(id );

            print("ask server for code, email: \(id)");
        }else if indexPath==indexPathForSelectPhoto{
            //pickPhoto();
            let imagePickerController = ImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.imageLimit = 1;
            presentViewController(imagePickerController, animated: true, completion: nil)
        }
    }
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if  indexPath != indexPathForCodeTextField &&
            indexPath != indexPathForNameTextField &&
            indexPath != indexPathForEmailTextField {
            emailTextField.resignFirstResponder()
            displayNameTextField.resignFirstResponder()
            varificationCodeTextField.resignFirstResponder();
        }
        if !varificationCodeSent && indexPath.section != 0{
            return nil
        }else if varificationCodeSent && indexPath == indexPathForSendCode{
            return nil
        }
        return indexPath;
    }
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch indexPath{
        case indexPathForSelectPhoto:
            return imageView.hidden ? 44 : 280
        default:
            return 44
        }
    }
}
extension RegistrationViewController: ImagePickerDelegate{
    func wrapperDidPress(images: [UIImage]){
        print("wrapper called")
        dismissViewControllerAnimated(true, completion: nil)

    }
    func doneButtonDidPress(images: [UIImage]){
        print("don called")
        image = images[0];
        updateUI();
        dismissViewControllerAnimated(true, completion: nil)
    }
    func cancelButtonDidPress(){
        print("cancel called")

    }
}
/*
extension RegistrationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func takePhotoWithCamera() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .Camera
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.view.tintColor = view.tintColor
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func choosePhotoFromLibrary() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .PhotoLibrary
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.view.tintColor = view.tintColor
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        image = info[UIImagePickerControllerEditedImage] as! UIImage?
        updateUI()
        
        tableView.reloadData()
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func pickPhoto() {
        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            showPhotoMenu()
        } else {
            choosePhotoFromLibrary()
        }
    }
    
    func showPhotoMenu() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let takePhotoAction = UIAlertAction(title: "Take Photo", style: .Default, handler: { _ in self.takePhotoWithCamera() })
        alertController.addAction(takePhotoAction)
        
        let chooseFromLibraryAction = UIAlertAction(title: "Choose From Library", style: .Default, handler: { _ in self.choosePhotoFromLibrary() })
        alertController.addAction(chooseFromLibraryAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
}
*/
