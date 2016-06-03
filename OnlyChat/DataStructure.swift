//
//  DataStructure.swift
//  OnlyChat
//
//  Created by 工作 on 16/5/20.
//  Copyright © 2016年 ChenXuyi. All rights reserved.
//

import Foundation
import JSQMessagesViewController
import Starscream

class Overseer{//singular pattern
    let socket = WebSocket(url: NSURL(string: "ws://chenxuyi.cn:8888/ws")!, protocols: ["chat", "superchat"]);
    
    var conversation: Conversation! = nil
    
    init(){
    }
    
    
    //DataStorage
    func save(){
        let worksLibData = NSMutableData();
        let archiver = NSKeyedArchiver(forWritingWithMutableData: worksLibData)
        archiver.encodeObject(conversation, forKey: "conversation")
        archiver.finishEncoding();
        worksLibData.writeToFile(dataFilePath(), atomically: true);
        print("SAVE SUCCESSFULLY")
    }
    
    func load()->Conversation {
        var ret: Conversation! = nil;
        let path = dataFilePath();
        if NSFileManager.defaultManager().fileExistsAtPath(path){
            if let data = NSData(contentsOfFile: path){
                let unarchiver = NSKeyedUnarchiver(forReadingWithData: data)
                ret = unarchiver.decodeObjectForKey("conversation") as? Conversation;
                unarchiver.finishDecoding();
                print("LOAD SUCCESSFULLY")
            }
        }
        if ret == nil {
            ret = Conversation()
        }
        conversation = ret;
        return ret;
    }
    
    

    
}




class LoginID:NSObject, NSCoding{
    var id = "";
    var displayName = ""
    var lastLogin:NSDate?
    var portrait:UIImage?
    //Data Storage
    init(id:String, name: String){
        self.id = id;
        self.displayName = name;
    }
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(id, forKey: "id")
        aCoder.encodeObject(displayName, forKey: "id")
        aCoder.encodeObject(lastLogin, forKey: "id")
        aCoder.encodeObject(portrait, forKey: "id")
    }
    required init?(coder aDecoder: NSCoder) {
        id = aDecoder.decodeObjectForKey("id") as! String;
        displayName = aDecoder.decodeObjectForKey("displayName") as! String;
        portrait = aDecoder.decodeObjectForKey("portrait") as? UIImage;
    }
}

class Conversation: NSObject,NSCoding{
    var local:LoginID! = nil;
    var remote:LoginID? = nil;
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(local, forKey: "local")
        aCoder.encodeObject(remote, forKey: "remote")
    }
    required init?(coder aDecoder: NSCoder) {
        local = aDecoder.decodeObjectForKey("local") as? LoginID
        remote = aDecoder.decodeObjectForKey("remote") as? LoginID
    }
    override init(){
        super.init();
        local = nil;
        remote = nil;
    }
    init(me: LoginID, she: LoginID){
        super.init();
        local = me;
        remote = she;
    }
}




//test use
func makeConversation()->[JSQMessage]{
    let remotename = "fucker"
    let remoteid = "f"
    let myname = "me"
    let myid = "m"
    let message:JSQMessage = JSQMessage(senderId: remoteid, displayName: remotename, text: "What is this Black Majic?")
    let message2:JSQMessage = JSQMessage(senderId: myid, displayName: myname, text: "It is simple, elegant, and easy to use. There are super sweet default settings, but you can customize like crazy")
    let message3:JSQMessage = JSQMessage(senderId: remoteid, displayName: remotename, text: "It even has data detectors. You    can call me tonight. My cell number is 123-456-7890. My website is www.hexedbits.com.")
    let message4:JSQMessage = JSQMessage(senderId: myid, displayName: myname, text: "JSQMessagesViewController is nearly an exact replica of the iOS Messages App. And perhaps, better.")
    let message5:JSQMessage = JSQMessage(senderId: remoteid, displayName: remotename, text: "It is unit-tested, free, open-source, and documented.")

    let conversation = [message, message2,message3, message4, message5]
    return conversation
}
