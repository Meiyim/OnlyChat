# import logging
import tornado.escape;
import tornado.ioloop
import tornado.options
import tornado.web
import tornado.websocket
# import os.path
# import uuid;

import json
import re
import pymongo
from pymongo import MongoClient
from bson.binary import Binary
from bson.objectid import ObjectId

from SendEmail import *
from RandomCodeGenerator import *

from tornado.options import define, options

define("port", default=8888, help="run on given port", type=int)

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
users_collection.create_index([('user_id', pymongo.ASCENDING)], unique=True)

randomCodeGenerator = RandomCodeGenerator();


# utility function

def emailIsValid(address):
    if len(address) > 7:
        pattern = "^.+\\@(\\[?)[a-zA-Z0-9\\-\\.]+\\.([a-zA-Z]{2,3}|[0-9]{1,3})(\\]?)$"
        if re.match(pattern, address) is not None:
            return True;
    print 'email illegal'
    return False;


def emailIsTaken(address):
    return users_collection.find_one({'user_id': address}) is not None;


def findEmail(address):
    return users_collection.find_one({'user_id': address});


def usernameIsGood(name):
    if len(name) < 3:
        return False
    pattern = r'[\w+]';
    if re.match(pattern, name) is None:
        print 'username illegal'
        return False;

    return True

class OnlyChatCommunicationProtocol:
    remoteStatus = 's'
    realTimeChange = 'c'
    message = 'm'
    recvConfirm = 'r'


# tornado request handler...
class WSHandler(tornado.websocket.WebSocketHandler):
    #tornado is a single threaded app...  assuming _THREAD_ _SAFE_
    clients = {};  # multiply instance might be generated. set this to static param
    unreadMsgs = {};

    # instance property
    pair = None;
    pairid = '';
    userid = '';

    def open(self):
        self.userid = self.request.headers['user_id']
        print 'new connection arrived : %s' % self.userid
        self.write_message("Connection was accepted");
        WSHandler.clients[self.userid] = self;
        user = findEmail(self.userid);
        self.pairid = user['pair_id']
        WSHandler.unreadMsgs[self.pairid] = []
        self.pair  = WSHandler.clients.get(self.pairid)
        #using customed communication protocol...
        if self.pair is None : #pair is offline
            self.write_message('%s,%s' %(OnlyChatCommunicationProtocol.remoteStatus,'n'));
        else:
            self.write_message('%s,%s' %(OnlyChatCommunicationProtocol.remoteStatus,'y'));
        #checkt & send unread Msgs
        msgs = findEmail(self.pairid)['unread_Msgs'];
        msgsInServer = WSHandler.unreadMsgs.get(self.userid); 
        if msgsInServer is not None:
            msgs += msgsInServer;
        if len(msgs) == 0:
            pass
        else:
            print 'you have %d unread msgs...' % len(msgs)
            for msg in msgs:
                self.write_message('%s,%s' %(OnlyChatCommunicationProtocol.message,msg));
            #reset unread msgs
            print 'pretending the clear msgs...'
            #users_collection.find_one_and_update({'user_id':self.pairid},{'$set':{'unread_Msgs':[]}})

        print "there are %d clients now" % len(WSHandler.clients);

    def on_close(self):
        print "user: %s close ... %d clients remain" % (self.userid,len(WSHandler.clients))
        del WSHandler.clients[self.userid]
        msgs = findEmail(self.pairid)['unread_Msgs'];
        msgs  += WSHandler.unreadMsgs[self.pairid]; 
        print 'pretending to save unread msgs...'
        #users_collection.find_one_and_update({'user_id':self.pairid},{'$set':{'unread_Msgs':msgs}})
        del WSHandler.unreadMsgs[self.pairid]

    def forwardMessage(self, msg):
        self.pair.write_message(msg);

    def saveUnreadMessage(self,msg):
        WSHandler.unreadMsgs[self.pairid].append(msg);
    
    def on_message(self, message):
        print "message received: %s, forwarding..." % message
        #self.write_message(message) #temporary a echo server
        if self.pair is None:
            self.saveUnreadMessage(message);
        else:
            self.forwardMessage(message);
        #send recv confirm
        self.write_message('%s,%s'%(OnlyChatCommunicationProtocol.recvConfirm,'foo'));
            


class TestHandler(tornado.web.RequestHandler):  # for browser tester
    def get(self):
        loader = tornado.template.Loader(".")
        self.write(loader.load("index.html").generate())


# userInfo search
class InfoSearchHandler(tornado.web.RequestHandler):
    def handleSearch(self, email):
        answer = {'response': 'wrong'};
        if not emailIsValid(email) or not emailIsTaken(email):
            answer['response'] = 'emailInvalid'
        else:
            searchResult = findEmail(email)
            if searchResult is None:
                answer['response'] = 'noSuchUser'
            elif searchResult['pair_id'] is not None:
                answer['response'] = 'userPaired'
                answer['user_id'] = searchResult['user_id'];
                answer['user_name'] = searchResult['user_name']
                answer['downloadID'] = str(searchResult['_id']);
                answer['hash'] = 'xxxxxxxxxxxxxxxx'
            else:
                # return status
                answer['response'] = 'userAvailable'
                answer['user_id'] = searchResult['user_id'];
                answer['user_name'] = searchResult['user_name']
                answer['downloadID'] = str(searchResult['_id']);
                answer['hash'] = 'xxxxxxxxxxxxxxxx'
                #return picture hash
                
        self.write(json.dumps(answer));

    def handlePair(self, email, pairEmail):
        answer = 'wrong'
        if not emailIsValid(email) or not emailIsTaken(email):
            pass
        else:
            me = findEmail(email)
            she = findEmail(pairEmail)
            if me is None or she is None:
                pass
            elif me['pair_id'] is not None or she['pair_id'] is not None:
                print 'some body is paired'
            else:
                me['pair_id'] = she['user_id']
                she['pair_id'] = me['user_id'];
                # update database
                users_collection.find_one_and_update({'user_id':email},{'$set':{'pair_id':pairEmail}})
                users_collection.find_one_and_update({'user_id':pairEmail},{'$set':{'pair_id':email}})
                answer = 'paired'
        self.write(answer);

    def handleUpdate(self, email):
        pass

    def post(self):
        param_request_type = self.get_argument('request');
        param_id = self.get_argument('id');
        param_id = param_id.lower();
        param_pair_id = self.get_argument('pairId', 'nil');
        print 'search request received %s: id = %s' % (param_request_type, param_id);
        if param_request_type == 'search':
            self.handleSearch(param_id)
        elif param_request_type == 'pair':
            self.handlePair(param_id, param_pair_id);
        elif param_request_type == 'update':
            self.handleUpdate(param_id)
        else:
            print 'request cannot handled: %s' % param_request_type

        # upload handler


class UploadHanler(tornado.web.RequestHandler):
    def get(self):
        downloadID = self.get_argument('downloadID');
        user = users_collection.find_one(ObjectId(downloadID));
        portraitData = user['portrait']
        if portraitData:
            self.write(portraitData);

    def post(self):
        answer = 'wrong'
        data = Binary(self.request.body);
        userid = self.request.headers["Filename"];
        userid = userid.lower()
        # process file
        if len(data) > 4 * 1024 * 1024:  # Todo: compress image locally
            print 'file too large'
            answer = 'portraitFileTooLarge'
        else:
            oldUser = users_collection.find_one_and_update({'user_id': userid}, {'$set': {'portrait': data}});
            if oldUser:
                print 'portrait updated'
                answer = 'succeed'
        self.write(answer);


# verification handler
class VerificationHandler(tornado.web.RequestHandler):
    emailServr = EmailServer();

    def get(self):
        print 'get request received..'
        self.write("hello client");

    # request handler...
    @tornado.web.asynchronous
    @tornado.gen.coroutine
    def sendCode(self, address):
        answer = {"response": "wrong"}
        # check email
        if not emailIsValid(address):
            answer["response"] = "emailInvalid";
        else:
            isOldUser = False;
            if emailIsTaken(address):
                isOldUser = True;
            # asynchrounos send method
            sendSuccess = yield tornado.gen.Task(VerificationHandler.emailServr.send_mail, address, \
                    "OnlyChat VerificationCode", \
                    "hi~ , here's your verification code for OnlyChat\n %s\n Thank you for Using\n" % \
                    randomCodeGenerator.generate(str(address)) \
                )
            if sendSuccess:
                if isOldUser:
                    answer['response'] = 'codeSentOldUser'
                    answer['oldUsername'] = findEmail(address)['user_name'];
                    print 'code sent old user'
                else:
                    answer["response"] = "codeSent";
                    print 'code sent'

        self.write(json.dumps(answer));
        self.finish();

    def register(self, userid, userName, code):
        answer = {'response': 'wrong'};
        if not randomCodeGenerator.validate(str(code), str(userid)):
            answer['response'] = 'codeWrong';
        elif not usernameIsGood(userName):
            answer['response'] = 'nameWrong';
        elif not emailIsValid(userid):
            # user should not change email
            print 'email check failed'
        else:
            oldUser = findEmail(userid);
            if oldUser is None:
                documentToInsert = {
                    'user_id': userid,
                    'user_name': userName,
                    'pair_id': None,
                    'unread_Msgs': [],
                    'portrait': None,
                    'last_login': None
                }
                # pretended to inserted
                users_collection.insert_one(documentToInsert);
                answer['response'] = 'registed';
                print 'new user registered %s' % userid;
            else:
                users_collection.find_one_and_update({'user_id': userid}, {'$set': {'user_name': userName}});
                answer['response'] = 'oldUser';
                # answer['oldUserMongoID'] = oldUser['_id'];
                print 'old user returned'
        self.write(json.dumps(answer));

    def unpair(self, userid):
        answer = 'wrong'
        if not emailIsValid(userid):
            pass
        if not emailIsTaken(userid):
            pass
        else:
            #return the record before udpate... so pair_id is valid
            user = users_collection.find_one_and_update({'user_id':userid},{'$set':{'pair_id':None}});
            pairid = user['pair_id']
            users_collection.find_one_and_update({'user_id':pairid},{'$set':{'pair_id':None}});
            answer = 'done'
        self.write(answer);

        

    def post(self):
        param_request_type = self.get_argument('request');
        param_id = self.get_argument('id');
        param_id = param_id.lower();
        param_name = self.get_argument('name', '!');
        param_code = self.get_argument('code', 'xxx');
        print 'post request received id = %s, code=%s, name=%s' % (param_id, param_code, param_name);
        if param_request_type == 'code':
            self.sendCode(param_id)
        elif param_request_type == 'register':
            self.register(param_id, param_name, param_code);
        elif param_request_type == 'unpair':
            self.unpair(param_id);
        else:
            print 'request cannot handled: %s' % param_request_type


if __name__ == "__main__":
    tornado.options.parse_command_line();
    app = tornado.web.Application(
        handlers=[
            (r'/ws', WSHandler),
            (r'/test', TestHandler),
            (r'/register', VerificationHandler),
            (r'/info', InfoSearchHandler),
            (r'/upload', UploadHanler),
        ]);

    app.listen(options.port);
    tornado.ioloop.IOLoop.instance().start();
