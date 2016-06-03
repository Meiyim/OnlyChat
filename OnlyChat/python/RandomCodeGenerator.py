import random
import time


class RandomCodeGenerator:
    def __init__(self):
        self.PERIOD = 300; #the expiration time for validation code is 300 * 2
        self.history = [];
        self.code_list = []
        for i in range(10):#
            self.code_list.append(str(i))
        for i in range(65, 91):#A-Z
            self.code_list.append(chr(i))
 
    def validate(self,code):
        now = time.time();
        if code == self.history[0][1] and now - self.history[0][0] < self.PERIOD:
            return True;
        if len(self.history)>1:
            if code == self.history[1][1] and now - self.history[1][0] < self.PERIOD:
                return True;
        print 'code illegal'
        return False;


    def generate(self):
        if len(self.history)==0 or self.history[0][0] - time.time() > self.PERIOD :
            myslice = random.sample(self.code_list, 6) 
            verification_code = ''.join(myslice) # list to string
            self.history.insert(0,(time.time(),verification_code))
            if len(self.history)>10:
                del self.history[-1];
            return verification_code
        else:
            return self.history[0][1];


if __name__ == "__main__":
    gen = RandomCodeGenerator();
    print gen.generate();
