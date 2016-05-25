//
//  RegistrationViewController.swift
//  OnlyChat
//
//  Created by 工作 on 16/5/20.
//  Copyright © 2016年 ChenXuyi. All rights reserved.
//

import UIKit

class RegistrationViewController: UITableViewController {
    
    let indexPathForSendCode = NSIndexPath(forRow: 1, inSection: 0);
    let indexPathForRegister = NSIndexPath(forRow: 0, inSection: 3);
    

    var registrationTask: NSURLSessionDataTask? = nil;
    
    var varificationCodeSent = false;
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var displayNameTextField: UITextField!
    @IBOutlet weak var varificationCodeTextField: UITextField!
    //MARK: - IBACtion
    @IBAction func cancel(sender: UIBarButtonItem){
        dismissViewControllerAnimated(true, completion: nil);
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
        let cell = tableView.dataSource?.tableView(tableView, cellForRowAtIndexPath: NSIndexPath(forRow: 3, inSection: 0 ));
        if varificationCodeSent {
                cell?.textLabel?.textColor = self.view.tintColor;
        }else{
                cell?.textLabel?.textColor = UIColor.grayColor()
        }
        
    }

    // MAKR: - HTTP request
    private func askServerForVarificationCode(id:String){
        varificationCodeSent = false;
        
        let request = getPostHttpRequest();
        let param = String(format: "id=%@",id);
        let body = param.dataUsingEncoding(NSUTF8StringEncoding)
        request.HTTPBody = body;

        registrationTask = NSURLSession.sharedSession().dataTaskWithRequest(request,completionHandler: {
            data ,response, error in
            if let err = error {
                if err.code == -999 {return;}
                print("http request wrong err:\(err.localizedDescription)");
            }else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("good request: \(data!)");
                    self.varificationCodeSent = true;
                }
                
            }
        })
        registrationTask?.resume();
        
    }
    private func registerForID(id:String, displayName:String, varificationCode: String){
        let registerRequest = getPostHttpRequest();
        let param = String(format: "id=%@ ,name=%@, code=%@",id,displayName,varificationCode);
        let body = param.dataUsingEncoding(NSUTF8StringEncoding)!
        registerRequest.HTTPBody = body;
        registrationTask = NSURLSession.sharedSession().dataTaskWithRequest(registerRequest, completionHandler: {
            data, response, error in
            if let err = error {
                if err.code == -999 {return;}
                print("http request wrong err:\(err.localizedDescription)");
            }else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("good request: \(httpResponse)");
                }
            }
            
            
        })
        
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
            guard let code = varificationCodeTextField.text else {
                //show warning
                return
            }
            guard let name = displayNameTextField.text else{
                //show warning
                return
            }
            assert(emailTextField.text != nil)
            registerForID(emailTextField.text!, displayName: name, varificationCode: code)
            
        }else if indexPath == indexPathForSendCode{
            guard let id = emailTextField.text else {
                //show warning
                return;
            }
            if !id.isEmail() {
                //show warning
                return;
            }
            askServerForVarificationCode(id );
            print("ask server for code, email: \(id)");
        }
    }
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if !varificationCodeSent && indexPath.section == 3 && indexPath.row == 0 {
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
