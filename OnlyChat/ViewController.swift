//
//  ViewController.swift
//  OnlyChat
//
//  Created by 工作 on 16/5/19.
//  Copyright © 2016年 ChenXuyi. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import Starscream
import Alamofire

enum MainViewControllerStatus{
    case Unregistered
    //case below means registered
    case Unpaired
    case Disconnected  //ws disconnected
    case Good
}



class ViewController: JSQMessagesViewController {
    var messages = [JSQMessage]()
    weak var conversation : Conversation! = nil;
    var status = MainViewControllerStatus.Unregistered;
    var downUploadRequest:Alamofire.Request?
    weak var imageView: UIImageView!

    //var shouldUseTempBubble = false;
    
    let incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
    let outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImageWithColor(UIColor.lightGrayColor())
    
    let fakeBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImageWithColor(UIColor.clearColor())
    let PAIR_SERVER_ADDRESS = "http://localhost:8888/info";
    let UPLOAD_ADDRESS = "http://localhost:8888/upload"
    
    //MARK: - IBoutlet
    
    //MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //check if user exits
        //check if
        
        //JSQMessage configuration
        self.inputToolbar?.contentView?.leftBarButtonItem = nil
        
        // This is how you remove Avatars from the messagesView
        collectionView?.collectionViewLayout.incomingAvatarViewSize = .zero
        collectionView?.collectionViewLayout.outgoingAvatarViewSize = .zero
        
        // This is a beta feature that mostly works but to make things more stable I have diabled it.
        collectionView?.collectionViewLayout.springinessEnabled = false
        
        //Set the SenderId  to the current User
        // For this Demo we will use Woz's ID
        // Anywhere that AvatarIDWoz is used you should replace with you currentUserVariable
        automaticallyScrollsToMostRecentMessage = true
        
        let background = UIImageView(frame: self.view.bounds)
        self.collectionView.backgroundView = background;
        imageView = background;

        self.view.insertSubview(imageView, atIndex: 0)
        

        if let local = conversation.local {
            senderId = local.id;
            senderDisplayName = local.displayName;
            guard let remote = conversation.remote else{
                status = .Unpaired
                return;
            }
            status = .Disconnected
            //update remote status
            performUpdateRemote(remote.id);

            self.navigationItem.title = remote.displayName
            //websocket connect
            overseer.socket.connect();
            if !overseer.socket.isConnected {
                status = .Disconnected
                return
            }
            
            //test
            self.messages = makeConversation()
            self.collectionView?.reloadData()
            self.collectionView?.layoutIfNeeded()
            return
        }else{
            //show registration page
            status = .Unregistered;
            senderId = "None";
            senderDisplayName = "";
            return;
        }
    
    }
    override func viewWillAppear(animated: Bool) {
        doAfterDelay(0.5, closure: {
            self.updateStatus();
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        if segue.identifier == "showRegister" {
            let dest = (segue.destinationViewController as! UINavigationController).viewControllers[0] as! RegistrationViewController
            dest.delegate = self
        }else if segue.identifier == "showPair" {
            let dest = (segue.destinationViewController as! UINavigationController).viewControllers[0] as! PairViewController
            dest.myEmail = senderId
            dest.delegate = self;
        }
        // Pass the selected object to the new view controller.
    }
    
    private func showAlert(title: String, OKButton: String,handler: ((UIAlertAction)->())? = nil){
        let alert = UIAlertController(title: title, message: "", preferredStyle: .Alert) //i18n
        let action1 = UIAlertAction(title: OKButton, style: .Destructive, handler: handler)
        alert.addAction(action1)
        presentViewController(alert, animated: true, completion: nil);
    }
    func updateRemoteUI(){
        navigationItem.title = conversation.remote?.displayName
        //update last login time
        //uodate last login location...
        //etc
    }
    
    func updateStatus(){
        print("update status")
        switch status {
        case .Unregistered:
            //show a registration guide
            showAlert("please register first", OKButton: "OK", handler: {
                _ in
                self.performSegueWithIdentifier("showRegister", sender: self)
            })
            break;
        case .Unpaired:
            //show reconnection guide
            showAlert("invite a frient to pair!", OKButton: "OK", handler: {
                _ in
                self.performSegueWithIdentifier("showPair", sender: self)
            })
            break;
        case .Disconnected:
            showBadNetworkIndicator();
            break;
        case .Good:
            //connected to WebSocket
            break;
        }
    }
    //MARK: - JSQMessage method
    override func didPressSendButton(button: UIButton?, withMessageText text: String?, senderId: String?, senderDisplayName: String?, date: NSDate?) {
        
        // This is where you would impliment your method for saving the message to your backend.
        //
        // For this Demo I will just add it to the messages list localy
        //
        //self.messages.append(JSQMessage(senderId: AvatarIdWoz, displayName: DisplayNameWoz, text: text))
        
        //check if server recv the message
        self.messages.append(JSQMessage(senderId: conversation?.local.id, displayName: conversation.local.displayName, text: text))
        //shouldUseTempBubble = true;
        self.finishSendingMessageAnimated(true)
        /*
        doAfterDelay(1){
            self.messages.removeLast();
            self.messages.append(JSQMessage(senderId: AvatarIdWoz, displayName: DisplayNameWoz, text: text))
            self.collectionView?.reloadData()
            self.shouldUseTempBubble = false;
        }
        */
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData? {
        return messages[indexPath.item]
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource? {
        //if(indexPath.item == messages.count - 1 && shouldUseTempBubble) {return fakeBubble;}
        return messages[indexPath.item].senderId == conversation.local.id ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource? {
        return nil
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, attributedTextForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        let message = messages[indexPath.item]
        switch message.senderId {
        case conversation.local.id:
            return nil
        default:
            guard let senderDisplayName = message.senderDisplayName else {
                assertionFailure()
                return nil
            }
            return NSAttributedString(string: senderDisplayName)
            
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout?, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        return messages[indexPath.item].senderId == conversation.local.id ? 0 : kJSQMessagesCollectionViewCellLabelHeightDefault
    }
    //MARK: NetWork utility
    private func downloadPortrait(id: String){
        print("posting download rquest")
        downUploadRequest?.cancel();
        downUploadRequest = Alamofire.download(.GET, UPLOAD_ADDRESS,parameters: ["downloadID":id]){ _ in
            self.clearTemp();
            return NSURL(fileURLWithPath: backGroundPath())
            }.response{  _,_,_,err in
                if let e = err {
                    self.showAlert("download error:\(e)", OKButton: "OK")
                }
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                let image = UIImage(contentsOfFile: backGroundPath())
                self.blurImage(image!, radious: 3, completion: { img in
                    //main queue closure
                    self.saveBackground(UIImage(CGImage:img))
                    self.loadBackGround();
    
                })
        }
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    
    func performUpdateRemote(remoteid:String){
        Alamofire.request(.POST,PAIR_SERVER_ADDRESS,parameters: ["request":"search","id":remoteid])
            .validate()
            .responseJSON{ response in
                if response.result.isFailure{
                    self.showAlert("something's wrong with the server", OKButton: "OK")
                }
                if let json = response.result.value{
                    let id = json["downloadID"] as! String
                    let name = json["user_name"] as! String
                    let hash = json["hash"] as! String
                    self.conversation.remote?.displayName = name
                    //update last login time, location, .etc
                    
                    assert(self.conversation.remote?.id == remoteid)
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    self.updateRemoteUI()
                    if self.conversation.remoteHash == hash{
                        //do nothing
                        self.loadBackGround()
                    }else{
                        //download new background
                        self.downloadPortrait(id)
                    }
                    self.status = .Good
                }
        }
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    func showBadNetworkIndicator(){
        showAlert("No Network Connection!", OKButton: "retry")
    }
    //MARK: - utility
    func loadBackGround(){
        let path  = backGroundPath();
        if NSFileManager.defaultManager().fileExistsAtPath(path){
            let image = UIImage(contentsOfFile: path)
            imageView.image = image
        }
    }
    func clearTemp(){
        let filemanager = NSFileManager.defaultManager();
        let savepath = backGroundPath();
        if filemanager.fileExistsAtPath(savepath){
            do{
                try filemanager.removeItemAtPath(savepath)
            }catch let e as NSError{
                print(e)
            }
        }
    }
    func saveBackground(image: UIImage){
        clearTemp()
        let data = UIImageJPEGRepresentation(image, 1.0)!
        do{
            try data.writeToFile(backGroundPath(), options: NSDataWritingOptions.DataWritingAtomic)
        }catch let e as NSError{
            print(e)
        }
        
    }
    private func blurImage(img: UIImage,radious: Double,completion:(CGImage)->()) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)){
            let imageToProcess = CIImage(CGImage: img.CGImage!)
            let filter = CIFilter(name: "CIGaussianBlur", withInputParameters: ["inputImage":imageToProcess, "inputRadius":radious])!
            let result = filter.outputImage!
            let context = CIContext(options: nil)
            let cgresult = context.createCGImage(result, fromRect: imageToProcess.extent)
            dispatch_async(dispatch_get_main_queue(), {
                completion(cgresult)
            })
        }
    }
}


extension ViewController :WebSocketDelegate {

    //MARK: WebSocket Delegate
    func websocketDidConnect(ws: WebSocket) {
        print("websocket is connected")
        assert(conversation != nil);
        //check if registered
        
        //check if paired
        
        //check if remote update status;
    }
    
    func websocketDidDisconnect(ws: WebSocket, error: NSError?) {
        if let e = error {
            print("websocket is disconnected: \(e.localizedDescription)")
        } else {
            print("websocket disconnected")
        }
    }
    
    func websocketDidReceiveMessage(ws: WebSocket, text: String) {
        print("message received \(text)")
    }
    
    func websocketDidReceiveData(ws: WebSocket, data: NSData) {
        
    }
}


extension ViewController: RegistrationViewControllerDelegate{
    func registrationViewController(controller: RegistrationViewController,registerID: String, registerName: String){
        self.status = .Unpaired;
        senderId = registerID;
        senderDisplayName = registerName;
        conversation.local = LoginID(id: registerID, name: registerName)
        overseer.save();
    }
}


extension ViewController: PairViewControllerDelegate{
    func pairViewController(pairView: PairViewController, didPairedWithId id: String, name:String, backGround img: UIImage){
        self.status = .Good
        conversation.remote = LoginID(id:id, name: name)
        saveBackground(img)
        overseer.save()
        return
    }
}


