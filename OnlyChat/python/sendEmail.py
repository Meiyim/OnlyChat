import smtplib
from email.mime.text import MIMEText

class EmailServer:
    def __init__(self):
        self.to_addresses = ["chen_xuyi@outlook.com"];
        self.from_host = "smtp.qq.com";
        self.from_port = 465;
        self.from_address = "362169764@qq.com";
        self.from_passwd = "lxtsworld";

        try:
            self.server = smtplib.SMTP_SSL();

        except Exception,e:
            print str(e);


    #wait server response, time comsumption
    def send_mail(self,to, sub, content):
        me = "hello"+"<"+self.from_address+">"
        msg = MIMEText(content,_subtype='plain');
        msg['Subject'] = sub;
        msg['From'] = me;
        msg['To'] = to;
        try:
            #print "connecting..."
            self.server.connect(self.from_host,self.from_port);
            #print "loging in..."
            self.server.login(self.from_address,self.from_passwd);
            #print "sending ..."
            self.server.sendmail(me,to,msg.as_string());
            self.server.close();

            return True;
        except Exception, e:
            print str(e);
            return False;



if __name__ == "__main__":
    sender = EmailServer();
    if sender.send_mail("chen_xuyi@outlook.com","helloworld","hello my name is chenxuyi\n"):
        print "succeed";
    else:
        print "Not good";

    if sender.send_mail("chen_xuyi@outlook.com","helloworld_again~","hello my name is chenxuyi\n"):
        print "succeed";
    else:
        print "Not good";





