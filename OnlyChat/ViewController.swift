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
import Dodo

enum MainViewControllerStatus{
    case Unregistered
    //case below means registered
    case Unpaired
    case Disconnected  //ws disconnected
    case Good
}

class OnlyChatCommunicationProtocol{
    static var remoteStatus = "s"; // y--'online',n=--'offline', u--'unpaired'
    static var realTimeChange = "c";
    static var message = "m"
    static var recvConfirm = "r"
}


class ViewController: JSQMessagesViewController {
    var messages = [JSQMessage]()
    var messagePointer = 0;
    
    weak var conversation : Conversation! = nil;
    var status = MainViewControllerStatus.Unregistered;
    var downUploadRequest:Alamofire.Request?
    weak var imageView: UIImageView!
    weak var titleView: ConversationHeaderView! = nil
    

    //var shouldUseTempBubble = false;
    /*
    let incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
    let outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImageWithColor(UIColor.lightGrayColor())
    
    let fakeBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImageWithColor(UIColor.clearColor())
    */
    //conversationUI
    var incomingBubble: JSQMessagesBubbleImage! = nil
    var outgoingBubble: JSQMessagesBubbleImage! = nil

    var backgroundImage:UIImage! = nil;
    var backgroundImageMono:UIImage! = nil;
    
    //websocket related
    var pendingMessageRemote = "";
    var pendingMessageLocal = "";
    var remoteIsOnline = false;

    
    //MARK: - IBoutlet
    //MARK: - IBAction
    
    @IBAction func didPressSettingsButton(sender: UIBarButtonItem) {
        performSegueWithIdentifier("showSettings", sender: self)
    }
    
    //MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        let template = UIImage(named: "bubble_incoming_tailless");
        let factory = JSQMessagesBubbleImageFactory(bubbleImage: template!, capInsets: UIEdgeInsetsZero)
        incomingBubble = factory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor());
        outgoingBubble = factory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor());
        
        //check if user exits
        //check if
        //JSQMessage configuration
        self.inputToolbar?.contentView?.leftBarButtonItem = nil

        
        //Set the SenderId  to the current User
        // For this Demo we will use Woz's ID
        // Anywhere that AvatarIDWoz is used you should replace with you currentUserVariable
        
        //config background... load from user directory
        let background = UIImageView(frame: self.view.bounds)
        self.collectionView.backgroundView = background;
        imageView = background;

        //config title View
        let titleView = ConversationHeaderView(frame: CGRect(x: 0, y: 0, width: 232, height: 44))
        self.navigationItem.titleView = titleView
        self.titleView = titleView;
        
        //config dodoView
        view.dodo.topLayoutGuide = topLayoutGuide
        view.dodo.style.bar.onTap = {
            print("Tap tap tap 🌻🌼🐁🍃")
        }
        view.dodo.style.bar.locationTop = true
        view.dodo.style.bar.hideAfterDelaySeconds = 0
        view.dodo.style.bar.debugMode = false
        view.dodo.style.bar.hideOnTap = false
        view.dodo.style.label.shadowColor = DodoColor.fromHexString("#00000050")
        view.dodo.style.bar.backgroundColor = DodoColor.fromHexString("#0003AAE0")
        view.dodo.style.label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        view.dodo.style.bar.animationShow = DodoAnimations.SlideVertically.show;
        view.dodo.style.bar.animationHide = DodoAnimations.SlideVertically.hide

        
        //self.view.insertSubview(imageView, atIndex: 0)
        defer{
                self.tryConnect();
                self.collectionView?.collectionViewLayout.springinessEnabled = false
                self.automaticallyScrollsToMostRecentMessage = true
                self.collectionView?.collectionViewLayout.incomingAvatarViewSize = .zero
                self.collectionView?.collectionViewLayout.outgoingAvatarViewSize = .zero
                self.collectionView?.reloadData()
                self.collectionView.layoutIfNeeded()
        }
        print("view did load")

        
        if let local = conversation.local {
            senderId = local.id;
            senderDisplayName = local.displayName;
            guard conversation.remote != nil else{
                status = .Unpaired
                return;
            }
            status = .Disconnected
            //set init value for remote;
            for chat in overseer.diaglog{
                self.messages.append(chat)
            }
            self.messagePointer = messages.count;
            self.loadBackGround()
            updateRemoteUI();
            
            //test
            /*
            doAfterDelay(0.5){
                self.collectionView?.reloadData()
                self.collectionView?.layoutIfNeeded()
            }*/
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
        super.viewWillAppear(animated)
        /*
        doAfterDelay(1, closure: {
            self.updateStatus();
        })*/
    }
    /*
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
        cell.backgroundColor = UIColor.redColor()
        return cell
    }*/
    //override func collectionView
 
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        if segue.identifier == "showRegister" {
            let dest = (segue.destinationViewController as! UINavigationController).viewControllers[0] as! RegistrationViewController
            dest.delegate = self
        }else if segue.identifier == "showPair" {
            let dest = (segue.destinationViewController as! UINavigationController).viewControllers[0] as! PairViewController
            dest.myEmail = senderId
            dest.delegate = self;
        }else if segue.identifier == "showSettings"{
            let dest = (segue.destinationViewController as! UINavigationController).viewControllers[0] as! SettingsViewController
            let factor = backgroundImage.size.width / 80;
            let scale = CGSize(width: backgroundImage.size.width / factor, height: backgroundImage.size.height / factor)
            dest.thumbnail = self.getThumbnailofImage(backgroundImage, scale: scale)
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
    
    //update navigation title and Black/White featrue
    func updateRemoteUI(){
        if let remote = conversation.remote{
            self.titleView.setHeader(remote.displayName)
            if let img = backgroundImage{
                if let bimg = backgroundImageMono{
                    if remoteIsOnline{
                        imageView.image = img;
                    }else{
                        imageView.image = bimg;
                    }
                }
            }
        }else{
            self.titleView.setHeader("Welcome to OnlyChat")
            imageView.image = nil;// or other default background
        }

        //update last login time
        //uodate last login location...
        //etc
    }
    
    //call this to send warning or guidline
    func updateStatus(){
        switch status {
        case .Unregistered:
            //show a registration guide
            doAfterDelay(3.0){
                if !(self===self.navigationController!.topViewController) { return };
                self.showAlert("please register first", OKButton: "OK", handler: {
                    _ in
                    self.performSegueWithIdentifier("showRegister", sender: self)
                })
            }
            overseer.socket.disconnect();
            overseer.unpair();
            self.messages.removeAll()
            messagePointer = 0;
            collectionView.reloadData()
            collectionView.layoutIfNeeded();
            print("update unregisted")
            break;
        case .Unpaired:
            //show reconnection guide
            doAfterDelay(3.0){
                if !(self===self.navigationController!.topViewController) { return };
                self.showAlert("invite a frient to pair!", OKButton: "OK", handler: {
                    _ in
                    self.performSegueWithIdentifier("showPair", sender: self)
                })
            }
            overseer.socket.disconnect();
            overseer.unpair();
            self.messages.removeAll()
            messagePointer = 0;
            collectionView.reloadData()
            collectionView.layoutIfNeeded();
            print("update unpaired")
            break;
        case .Disconnected:
            //any thing could happen...
            doAfterDelay(3.0){
                if !(self===self.navigationController!.topViewController) { return };
                self.showBadNetworkIndicator();
            }
            print("update disconnected")
            break;
        case .Good:
            //connected to WebSocket
            print("update good")
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
        self.sendMessage(text!)
        let msg = JSQMessage(senderId: conversation?.local.id, displayName: conversation.local.displayName, text: text)
        self.messages.append(msg)
        self.finishSendingMessageAnimated(true)
        
        //a fake reply
        /*
        doAfterDelay(2.0){
            self.messages.append(JSQMessage(senderId: self.conversation?.remote?.id,displayName: self.conversation.remote?.displayName,text: "fuck you bitch"))
            self.finishReceivingMessageAnimated(true)
        }*/

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
            //return NSAttributedString(string: senderDisplayName)
            return nil
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout?, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        //return messages[indexPath.item].senderId == conversation.local.id ? 0 : kJSQMessagesCollectionViewCellLabelHeightDefault
        return 0
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
                    self.updateRemoteUI();
    
                })
        }
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    
    func performUpdateSelf(){
        Alamofire.request(.POST,PAIR_SERVER_ADDRESS,parameters: ["request":"search","id":conversation.local.id])
            .validate()
            .responseJSON{ response in
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                guard let json = response.result.value else{
                    self.status = .Disconnected;
                    self.updateStatus();
                    return;
                }
                let isPaired = json["response"] as! String
                assert(self.conversation.local.id == json["user_id"] as! String)
                
                if isPaired == "userPaired" {
                    self.status = .Disconnected
                    self.performUpdateRemote(json["pair_id"] as! String);
                }else if isPaired == "userAvailable"{
                    self.status = .Unpaired;
                    self.updateRemoteUI();
                    self.updateStatus();
                }else{
                    assert(false);
                }
                
                //update last login time, location, .etc
        }
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    func performUpdateRemote(remoteid:String){
        Alamofire.request(.POST,PAIR_SERVER_ADDRESS,parameters: ["request":"search","id":remoteid])
            .validate()
            .responseJSON{ response in
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                guard let json = response.result.value else{
                    self.status = .Disconnected;
                    self.updateRemoteUI();
                    self.updateStatus();
                    return;
                }
                let id = json["downloadID"] as! String
                let name = json["user_name"] as! String
                let hash = json["hash"] as! String
                self.conversation.remote?.displayName = name
                //update last login time, location, .etc
                
                if let remote = self.conversation.remote{
                    assert(remote.id == remoteid)
                }else{
                    self.conversation.remote = LoginID(id: remoteid, name: name)
                    self.status = .Disconnected
                    
                }
                
                self.updateRemoteUI()
                if self.conversation.remoteHash == hash{
                    //do nothing
                }else{
                    //download new background
                    self.downloadPortrait(id)
                }
                overseer.webSocketConnect();
                
        }
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    func tryConnect(){
        assert(!overseer.socket.isConnected);
        //update self status;
        performUpdateSelf();
    }
    func showBadNetworkIndicator(){
        showAlert("No Network Connection!", OKButton: "retry"){ _ in
            self.tryConnect();
        }
    }
    //MARK: - utility
    //load image wont load the image to imageView, this needs to be done in updateRemoteUI
    func loadBackGround(){
        let path  = backGroundPath();
        if NSFileManager.defaultManager().fileExistsAtPath(path){
            backgroundImage = UIImage(contentsOfFile: path)
            backgroundImageMono = monoImage(backgroundImage)
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
    private func monoImage(img: UIImage)->UIImage{
        let sourceImage = CIImage(image: img)!
        let filter = CIFilter(name: "CIPhotoEffectMono")!
        filter.setDefaults();
        filter.setValue(sourceImage, forKey: kCIInputImageKey)
        let context = CIContext(options: nil)
        let outCG = context.createCGImage(filter.outputImage!, fromRect: filter.outputImage!.extent)
        return UIImage(CGImage: outCG)
    }
    private func getThumbnailofImage(img:UIImage, scale: CGSize)->UIImage{
        UIGraphicsBeginImageContext(scale)
        img.drawInRect(CGRect(x: 0, y: 0, width: scale.width, height: scale.height));
        let ret = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return ret;
    }
    
}


extension ViewController :WebSocketDelegate {
    //MARK: WebSocket Delegate
    func websocketDidConnect(ws: WebSocket) {
        print("websocket is connected")
        assert(conversation != nil);
        doAfterDelay(2.0){
            if overseer.socket.isConnected {
                self.status = .Good;
                self.updateStatus();
                return
            }
        }

    }
    
    func websocketDidDisconnect(ws: WebSocket, error: NSError?) {
        if let e = error {
            print("websocket is disconnected: \(e.localizedDescription)")
        } else {
            print("websocket disconnected")
        }
        doAfterDelay(2.0){
            if !overseer.socket.isConnected {
                self.status = .Disconnected
                self.updateStatus();
                return
            }
        }

    }
    
    func websocketDidReceiveMessage(ws: WebSocket, text: String) {
        print("message received \(text)")
        parseIncomingMessage(text)
    }
    
    func websocketDidReceiveData(ws: WebSocket, data: NSData) {
        
    }
    
    //MARK: - websocket utility
    private func sendMessage(msg:String){
        let toSend = String(format:"%@,%@",
                            OnlyChatCommunicationProtocol.message  ,msg);
        overseer.socket.writeString(toSend);
    }
    private func sendRealTimeChange(range: NSRange, msg: String){
        let toSend = String(format:"%@,%i,%i,%@",OnlyChatCommunicationProtocol.realTimeChange,range.location,range.length,msg);
        //print(toSend);
        overseer.socket.writeString(toSend);
    }
    private func showRealTimeChange(t:String){
        guard let label = self.view.viewWithTag(3344) as? UILabel else{
            //fatalError()
            view.dodo.show(t)
            return;
        }
        label.text = t;
    }
    private func parseIncomingMessage(incomingMsg: String){
        var ret = ""
        let parseRets = incomingMsg.componentsSeparatedByString(",");
        if parseRets[0] == OnlyChatCommunicationProtocol.realTimeChange {
            let range =  NSRange(location:Int(parseRets[1])!, length: Int(parseRets[2])!);
            let text:String = parseRets[3];
            let oldText: NSString = pendingMessageRemote;
            let newText: NSString = oldText.stringByReplacingCharactersInRange(range, withString: text)
            pendingMessageRemote = newText as String;
            ret = String(newText);
            showRealTimeChange(ret)
        }else if parseRets[0] == OnlyChatCommunicationProtocol.message {//a new arrival message
            ret = parseRets[1];
            self.view.dodo.hide();
            let msg = JSQMessage(senderId: self.conversation?.remote?.id,displayName: self.conversation.remote?.displayName,text: ret)
            self.messages.append(msg)
            overseer.diaglog.append(msg)
            print("number of msgs: \(messages.count)")
            self.finishReceivingMessageAnimated(true)
            
        }else if parseRets[0] == OnlyChatCommunicationProtocol.remoteStatus{//remote status changed... on/offline
            switch parseRets[1] {
            case "y":
                remoteIsOnline = true;
            case "n":
                remoteIsOnline = false;
            case "u":
                remoteIsOnline = false;
                self.status = .Unpaired;
                showAlert("seems that he/she unpaired you...", OKButton: "OK"){ _ in
                    self.updateStatus();
                    self.updateRemoteUI()
                }
            default:
                assertionFailure();
            }
            updateRemoteUI();
        }else if parseRets[0] == OnlyChatCommunicationProtocol.recvConfirm{
            overseer.diaglog.append(self.messages[ messagePointer ]);
            print(overseer.diaglog.count)
            messagePointer+=1;
            print("msg confirmed")
        }
        
    }
    private func compareStrings(str1:String, and str2:String)->(NSRange,String)?{
        let cs1 = str1.characters;
        let cs2 = str2.characters;
        
        var iter1 = cs1.startIndex;
        var iter2 = cs2.startIndex;
        var iterStart1:String.CharacterView.Index!;
        var iterStart2:String.CharacterView.Index!;
        
        
        var lenHead = 0;
        var lenEnd = 0;
        while (iter1 != cs1.endIndex ) && (iter2 != cs2.endIndex) && (cs1[iter1]==cs2[iter2]) {
            iter1 = iter1.successor();
            iter2 = iter2.successor();
            lenHead+=1;
        }
        iterStart1 = iter1;
        iterStart2 = iter2;
        iter1 = cs1.endIndex;
        iter2 = cs2.endIndex;
        while(iter1 != iterStart1) && (iter2 != iterStart2) && (cs1[iter1.predecessor()]==cs2[iter2.predecessor()]){
            iter1=iter1.predecessor()
            iter2=iter2.predecessor()
            lenEnd+=1;
        }
        //return nil can avoid network communication
        if(iter1 == iterStart1) && (iter2==iterStart2) {return nil}
        
        let range = NSRange(location: lenHead  ,length: cs1.count - lenHead - lenEnd);
        let substr = str2.substringWithRange(iterStart2 ..< iter2);
        
        //print("compare result \(substr)");
        return (range,substr);
        
    }
    override func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool{
        
        let oldText: NSString = textView.text!
        let newText: NSString = oldText.stringByReplacingCharactersInRange(range, withString: text)
        if remoteIsOnline{
            if let retTup = compareStrings(pendingMessageLocal, and: String(newText)){
                sendRealTimeChange(retTup.0, msg: retTup.1)
            }
            pendingMessageLocal = newText as String;
        }

        return true;
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
    func compreeImg(img:UIImage) -> UIImage{
        let rect = CGSize(width: 360, height: 640)//the screen size of iphone 6s plus
        return self.getThumbnailofImage(img, scale: rect)
    }
}


extension ViewController: PairViewControllerDelegate{
    func pairViewController(pairView: PairViewController, didPairedWithId id: String, name:String, backGround img: UIImage){
        self.status = .Good
        let pairremote = LoginID(id:id, name: name)
        conversation.remote = pairremote
        saveBackground(img)
        overseer.save()
        updateRemoteUI();
        self.tryConnect()
        return
    }
}

extension ViewController: SettingsViewControllerDelegate{
    func accoutDidUnpair() {
        self.updateRemoteUI();
        self.status = .Unpaired;
        self.updateStatus();
    }
    func accoutDidLogout(){
        self.updateRemoteUI();
        self.status = .Unregistered;
        self.updateStatus();

    }
}


