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
    
    var delegate: RegistrationViewControllerDelegate?

    var registrationTask: NSURLSessionDataTask? = nil;
    
    var varificationCodeSent = false;
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var displayNameTextField: UITextField!
    @IBOutlet weak var varificationCodeTextField: UITextField!
    //MARK: - IBACtion
    @IBAction func cancel(sender: UIBarButtonItem){
        dismissViewControllerAnimated(true, completion: nil);
    }
    
    //MARK: - utility
    private func parseJSON(data: NSData) -> [String: AnyObject]? {
        do{
            let ret =  try NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions(rawValue: 0)) as? [String: AnyObject];
            return ret;
        
        }catch{
            print("cannot parse retrun json");
        }
        

        return nil
    }
    private func showAlert(title: String, OKButton: String,handler: ((UIAlertAction)->())?){
        let alert = UIAlertController(title: title, message: "", preferredStyle: .Alert) //i18n
        let action1 = UIAlertAction(title: OKButton, style: .Destructive, handler: handler)
        alert.addAction(action1)
        presentViewController(alert, animated: true, completion: nil);
    }
    
    //MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        varificationCodeSent = false;
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
        print("ui updated")
    }

    // MAKR: - HTTP request
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
                    let json = self.parseJSON(data!)!
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
                    let json = self.parseJSON(data!)!
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
    /*

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 0
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
