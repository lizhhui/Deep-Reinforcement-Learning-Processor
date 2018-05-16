import scipy.io as sio
import numpy as np
import math

mat_contents = sio.loadmat('alexnet_pepper.mat')
bias2 =  mat_contents['bias2']
ifmap2 = mat_contents['ifmap2']
filter2 = mat_contents['filter2']
ifmap3 = mat_contents['ifmap3']


xmove = 1
ymove = 1
scale = 7

size = 5
channel = 48

ifmap2_shape = ifmap2.shape
bias2_shape = bias2.shape
filter2_shape = filter2.shape
ifmap3_shape = ifmap3.shape

input_scale_factor = 127/ifmap2.max()    
filter2_scale_factor = 127/np.absolute(filter2).max()

ifmap2_2= ifmap2*input_scale_factor
ifmap2_round = np.round(ifmap2_2)
ifmap2_pad = np.pad(ifmap2_round, ((0,0), (1,1), (1,1)), 'constant')
ifmap2_fig0 = ifmap2_pad[0:48,:,:]
ifmap2_fig1 = ifmap2_pad[48:96,:,:]
filter2_scale = filter2*filter2_scale_factor
filter2_round = np.round(filter2_scale)

bias2_scale = bias2*input_scale_factor*filter2_scale_factor
bias2_round = np.round(bias2_scale)

filter2_fig0 = filter2_round[0:48,:,:]
filter2_fig1 = filter2_round[48:96,:,:]

yend = 5+ymove
xend = 5*(xmove+1)
part_ifmap2 = ifmap2_fig0[:,0:yend,0:xend]
part_filter2 = filter2_fig0[16:32,:,:]
part_bias2 = bias2_round[16:32,0]


addr = 0
count = 0
with open('memory.list','w') as f:
    for z in range(0, channel):
        for x_base in range(0, xend, size):
            for y in range(0, yend):
                for x in range(x_base, x_base+size):
                    num = int(part_ifmap2[z,y,x])
                    if num > 127:
                        num = 127
                    if num < -128:
                        num = -128
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
    for i in range(0,40):
        if count < 16:
            num = int(part_bias2[count])
        if num > 127:
            num = 127
        if num < -128:
            num = -128
        if num < 0:
            num += 256
        if i%5 == 0:
            f.write("00_{0:02x}\t// bias, addr = ".format(num)+str(addr)+'\n')
            count+=1
        elif i%5 ==2:
            f.write("{0:02x}_00\t// bias, addr = ".format(num)+str(addr)+'\n')
        else:
            f.write("00_00\t// bias, addr = "+str(addr)+'\n')
        addr += 1
    
    # filter
    count = 0
    for z in range(0, channel):
        for c in range(0, 16):
            for y in range(0, size):
                for x in range(0, size):
                    num = int(part_filter2[c,z,y,x])
                    if num > 127:
                        num = 127
                    if num < -128:
                        num = -128
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
                r=part_bias2[pe]
                i+=1
                for x in range(0, size):
                    for y in range(0, size):
                        for z in range (0, channel):
                            r+=(part_ifmap2[z,y+y_base,x+x_base]*part_filter2[pe,z,y,x])
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