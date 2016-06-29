//
//  SystemExtensions.swift
//  OnlyChat
//
//  Created by 工作 on 16/5/20.
//  Copyright © 2016年 ChenXuyi. All rights reserved.
//

import Foundation

let SERVER_ADDRESS = "http://chenxuyi.cn:8888"
let PAIR_SERVER_ADDRESS = SERVER_ADDRESS+"/info";
let UPLOAD_ADDRESS = SERVER_ADDRESS+"/upload"
let REGISTRATION_SERVER_ADDRESS = SERVER_ADDRESS+"/register"
let WEBSOCKET_ADDRESS = SERVER_ADDRESS + "/ws"




func documentDirectory() -> String {
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    return paths[0]
}
func dataFilePath()->String {
    return documentDirectory()+"/OnlyChat.plist"
}
func portraitPath()->String{
    return documentDirectory() + ("/myPortrait.jpg");
}
func backGroundPath()->String{
    return documentDirectory() + ("/backGround.jpg");
}
func tempPath()->String{
    return documentDirectory() + ("/tmp.jpg");
}

func doAfterDelay(seconds: Double, closure: ()->()){ // GCD framework!
    let when = dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * Double(NSEC_PER_SEC)));
    dispatch_after(when, dispatch_get_main_queue(), closure);
}

func parseJSON(data: NSData) -> [String: AnyObject]? {
    do{
        let ret =  try NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions(rawValue: 0)) as? [String: AnyObject];
        return ret;
        
    }catch{
        print("cannot parse retrun json");
    }
    
    return nil
}

class Regex {
    let internalExpression:NSRegularExpression
    let pattern:String
    
    init(pattern:String) {
        self.pattern = pattern
        try! self.internalExpression = NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.CaseInsensitive)

    }
    
    func match(input:String) -> Bool {
        let matches = self.internalExpression.matchesInString(input, options: NSMatchingOptions.Anchored, range: NSMakeRange(0, input.characters.count))
        return matches.count > 0
    }
}

extension String {
    func isEmail() -> Bool {
        let regex = Regex(pattern:"^[a-zA-Z0-9]+([._\\-])*[a-zA-Z0-9]*@([a-zA-Z0-9])+(.([a-zA-Z])+)+$");
        return regex.match(self);
    }
}