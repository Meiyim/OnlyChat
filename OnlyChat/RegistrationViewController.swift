//
//  RegistrationViewController.swift
//  OnlyChat
//
//  Created by 工作 on 16/5/20.
//  Copyright © 2016年 ChenXuyi. All rights reserved.
//

import UIKit

protocol RegistrationViewControllerDelegate{
    func registrationViewController(controller: RegistrationViewController,registerID: String, registerName: String);
}

class RegistrationViewController: UITableViewController {
    
    let indexPathForSendCode = NSIndexPath(forRow: 1, inSection: 0);
    let indexPathForRegister = NSIndexPath(forRow: 0, inSection: 3);
    let indexPathForDisplayName = NSIndexPath(forRow: 0, inSection:1);
    let indexPathForSelectPhoto = NSIndexPath(forRow: 1, inSection: 1);
    
    var delegate: RegistrationViewControllerDelegate?
    var image: UIImage?
    
    var registrationTask: NSURLSessionDataTask? = nil;
    
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

    private func showAlert(title: String, OKButton: String,handler: ((UIAlertAction)->())?){
        let alert = UIAlertController(title: title, message: "", preferredStyle: .Alert) //i18n
        let action1 = UIAlertAction(title: OKButton, style: .Destructive, handler: handler)
        alert.addAction(action1)
        presentViewController(alert, animated: true, completion: nil);
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
            imageView.hidden = false
            imageView.frame = CGRect(x: 10, y: 10, width: 160, height: 260)
            imageView.image = img
            addPhotoLabel.hidden = true;
        }
        tableView.reloadData();
        print("ui updated")
    }

    //MARK: - HTTP request
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
            if UIImagePickerController.isSourceTypeAvailable(.Camera) {
                showPhotoMenu()
            } else {
                choosePhotoFromLibrary()
            }
        }
    }
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if !varificationCodeSent && indexPath == indexPathForRegister {
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

