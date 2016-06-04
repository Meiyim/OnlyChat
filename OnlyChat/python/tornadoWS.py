#import logging
import tornado.escape;
import tornado.ioloop
import tornado.options
import tornado.web
import tornado.websocket
#import os.path
#import uuid;

import json
import re
from pymongo import MongoClient


from SendEmail import *
from RandomCodeGenerator import *

from tornado.options import define, options


define("port",default=8888,help="run on given port",type=int)

# mongoDB  configurations...
# userInfo document format:
#   user_id     : chen_xuyi@outlook.com
#   user_name   : Yim
#   pair_id     : chenYuxian@qq.com
#   unread_Msgs : [str]
#   portrait    : data
#   last_login   : str

db = MongoClient('mongodb://localhost:27017/')['OnlyChat_DataBase'];
users_collection = db['userInfo_Collection'];

randomCodeGenerator = RandomCodeGenerator();

# utility function

def emailIsValid(address):
    if len(address)>7 :
        pattern = "^.+\\@(\\[?)[a-zA-Z0-9\\-\\.]+\\.([a-zA-Z]{2,3}|[0-9]{1,3})(\\]?)$"
        if re.match(pattern, address) != None:
            return True;
    print 'email illegal'
    return False;

def emailIsTaken(address):
    return users_collection.find_one({'user_id':address}) != None ;

def usernameIsGood(name):
    if len(name)<3 :
        return False
    pattern = r'[\w+]';
    if re.match(pattern,name) is None:
        print 'username illegal'
        return False;
    
    return True

# tornado request handler...
class WSHandler(tornado.websocket.WebSocketHandler):
    clients = set();#multiply instance might be generated. set this to static param

    #instance property
    pair = None;

    def open(self):
        print 'new connection arrived'
        self.write_message("Hellp\n Connection was accepted");
        WSHandler.clients.add(self);
        self.pair = self;
        print "there are %d clients now" % len(WSHandler.clients);
        
    def on_close(self):
        WSHandler.clients.remove(self);
        print "connection closed... %d clients remain" % len(WSHandler.clients)

    def forwardMessage(self,msg):
        self.pair.write_message(msg);

    def on_message(self,message):
        print "message received: %s, forwarding..." % message
        self.forwardMessage(message);


class TestHandler(tornado.web.RequestHandler):  #for browser tester
    def get(self):
        loader = tornado.template.Loader(".")
        self.write(loader.load("index.html").generate())

class VerificationHandler(tornado.web.RequestHandler):
    emailServr = EmailServer();

    def get(self):
        print 'get request received..'
        self.write("hello client");
        
    #request handler...
    @tornado.web.asynchronous
    @tornado.gen.coroutine
    def sendCode(self,address):
        answer = {"response":"wrong"}
        #check email
        if not emailIsValid(address):
            answer["response"] = "emailInvalid";
        else:
            isOldUser = False;
            if emailIsTaken(address):
                isOldUser = True;
            #asynchrounos send method
            sendSuccess = yield tornado.gen.Task( VerificationHandler.emailServr.send_mail,address,\
                "OnlyChat VerificationCode",\
                "hi~ , here's your verification code for OnlyChat\n %s\n Thank you for Using\n" %\
                randomCodeGenerator.generate(str(address))   \
                )
            if sendSuccess :
                if isOldUser:
                    answer['response'] = 'coldeSentOldUser'
                    answer['oldUsername'] = users_collection.find_one({'user_id':userid}).user_name;
                    print 'code sent old user'
                else:
                    answer["response"] = "codeSent";
                    print 'code sent'

        self.write(json.dumps(answer));
        self.finish();

    def register(self,userid,userName,code):
        answer = {'response':'wrong'};
        if not randomCodeGenerator.validate(str(code),str(userid)):
            answer['response'] = 'codeWrong';
        elif not usernameIsGood(userName):
            answer['response'] = 'nameWrong';
        elif not emailIsValid(userid):
            #user should not change email
            print 'email check failed'
        else:
            if emailIsTaken(userid):
                oldUsername = users_collection.find_one({'user_id':userid}).user_name;
                answer['response'] = 'oldUser';
                answer['oldUsename'] = oldUsername;
                print 'old user returned'
            else:
                documentToInsert = {
                    'user_id':userid,
                    'user_name':userName,
                    'pair_id':None,
                    'unread_Msgs':[],
                    'portrait':None,
                    'last_login':None
                    }
                #pretended to inserted
                users_collection.insert_one(documentToInsert);
                answer['response'] = 'registed';
                print 'new user registered %s' % userid;
        self.write(json.dumps(answer));
                
    def post(self):
        param_request_type = self.get_argument('request');
        param_id = self.get_argument('id');
        param_name = self.get_argument('name','!');
        param_code = self.get_argument('code','xxx');
        print 'post request received id = %s, code=%s, name=%s' % (param_id,param_code,param_name);
        if param_request_type == 'code':
            self.sendCode(param_id)
        elif param_request_type  == 'register':
            self.register(param_id,param_name,param_code);
        else: 
            print 'request cannot handled: %s' % param_request_type 



if __name__ == "__main__":
    tornado.options.parse_command_line();
    app = tornado.web.Application(
            handlers = [
                (r'/ws',WSHandler),
                (r'/test', TestHandler),
                (r'/register', VerificationHandler),
                
            ]);

    app.listen(options.port);
    tornado.ioloop.IOLoop.instance().start();



