import numpy as np
import math

size = 6
xmove = 1
ymove = 1
zmove = 32
scale = 7

channel = zmove

np.random.seed(1)
bias = np.random.randint(0,20,size=16)
act = np.random.randint(0,30,size=(zmove, size+ymove, size*(xmove+1)))
fil = np.random.randint(-29,30,size=(16, zmove, size, size))

yend = size+ymove
xend = size*(xmove+1)

addr = 0
count = 0
with open('memory.list','w') as f:
    for z in range(0, channel):
        for x_base in range(0, xend, size):
            for y in range(0, yend):
                for x in range(x_base, x_base+size):
                    num = act[z,y,x]
                    if num < 0:
                        num += 256
                    
                    if count == 1:
                        f.write("{0:02x}_".format(num)+"{0:02x}\t// img, addr = ".format(nn)+str(addr)+'\n')
                        addr += 1
                        count = 0
                    else:
                        nn = num
                        count = 1


addr = 32768
with open('memory.list','a') as f:
    # Weight address
    f.write("@0000_8000\n")
    
    # bias
    count = 0
    for i in range(0,48):
        if count < 16:
            num = bias[count]
            if num < 0:
                num += 256
        if i%3 == 0:
            f.write("00_{0:02x}\t// bias, addr = ".format(num)+str(addr)+'\n')
            count+=1
        else:
            f.write("00_00\t// bias, addr = "+str(addr)+'\n')
        addr += 1
    
    # filter
    count = 0
    for z in range(0, channel):
        for c in range(0, 16):
            for y in range(0, size):
                for x in range(0, size):
                    num = fil[c,z,y,x]
                    if num < 0:
                        num += 256

                    if count == 1:
                        f.write("{0:02x}_".format(num)+"{0:02x}\t// wgt, addr = ".format(nn)+str(addr)+'\n')
                        addr += 1
                        count = 0
                    else:
                        nn = num
                        count = 1
                        

i = 0
with open('right_result.txt','w') as f:
    for pe in range(0,16):
        for x_base in range(0,xend-(size-1)):
            for y_base in range(0,ymove+1):
                r=bias[pe]
                i+=1
                for x in range(0, size):
                    for y in range(0, size):
                        for z in range (0, channel):
                            r+=(act[z,y+y_base,x+x_base]*fil[pe,z,y,x])
                r = math.floor(r/(2**(scale+1)))
                if(r>127):
                    r=127
                if(r<-128):
                    r=-128
                if(i<4):
                    f.write(str(r)+'\t')
                else:
                    f.write(str(r)+'\t')
                    f.write('\n')
                    i=0