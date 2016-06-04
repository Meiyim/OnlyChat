#import random
#import time



class RandomCodeGenerator:
    def __init__(self):
        #self.PERIOD = 30; #the expiration time for validation code is 300 * 2
        #self.history = [];
        self.code_list = []
        for i in range(10):#
            self.code_list.append(str(i))
        for i in range(65, 91):#A-Z
            self.code_list.append(chr(i))
    def identify(self,string):
        end = string.find('@');
        prefix = string[:end];
        postfix = string[end+1:-1]
        asciicodes = [];
        asciicodes2 = [];
        for letter in prefix:
           asciicodes.append(ord(letter)); 
        for letter in postfix:
           asciicodes2.append(ord(letter)); 

        ret = self.code_list[ max(asciicodes) % 36 ]; 
        ret += self.code_list[ min(asciicodes) % 36 ]; 
        ret += self.code_list[ max(asciicodes)/len(asciicodes) % 36 ]; 
        ret += self.code_list[ max(asciicodes2) % 36 ]; 
        ret += self.code_list[ min(asciicodes2) % 36 ]; 
        ret += self.code_list[ max(asciicodes2)/len(asciicodes) % 36 ]; 
        return ret;


 
    def validate(self,code,email):
        return code == self.identify(email);

    def generate(self,email):
        return self.identify(email);



        


if __name__ == "__main__":
    gen = RandomCodeGenerator();
    vr = gen.generate("chenxuyi@outlook.com");
    print vr
    print gen.validate(str(vr),"ch3nxuyi@outlook.com")
