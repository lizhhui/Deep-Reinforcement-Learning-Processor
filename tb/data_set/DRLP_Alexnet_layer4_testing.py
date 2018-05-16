import scipy.io as sio
import numpy as np
import math

xmove = 2
ymove = 2
scale = 5
input_scale_factor = 0.3
filter4_scale_factor = 640

mat_contents = sio.loadmat('alexnet_pepper.mat')

bias4 =  mat_contents['bias4']
ifmap4 = mat_contents['ifmap4']
filter4 = mat_contents['filter4']
ifmap5 = mat_contents['ifmap5']

ifmap4_shape = ifmap4.shape
bias4_shape = bias4.shape
filter4_shape = filter4.shape
ifmap5_shape = ifmap5.shape


ifmap4_2= ifmap4*input_scale_factor
ifmap4_round = np.round(ifmap4_2)
ifmap4_pad = np.pad(ifmap4_round, ((0,0), (1,1), (1,1)), 'constant')
ifmap4_fig0 = ifmap4_pad[0:192,:,:]
ifmap4_fig1 = ifmap4_pad[192:384,:,:]

yend = 3+ymove
xend = 3*(xmove+1)
part_ifmap4 = ifmap4_fig0[:,0:yend,0:xend]

addr = 0
count = 0

with open('memory.list','w') as f:
	for z_base in range(0, 192, 4):
		for x_base in range(0, xend, 3):
			for y in range(0,yend):
				for z in range(z_base, z_base+4):
					for x in range(x_base, x_base+3):
						num = int(part_ifmap4[z,y,x])
						if num > 127:
							num = 1272048
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


filter4_max = 0.2
filter4_scale = filter4*filter4_scale_factor
filter4_round = np.round(filter4_scale)

bias4_scale = bias4*input_scale_factor*filter4_scale_factor
bias4_round = np.round(bias4_scale)

filter4_fig0 = filter4_round[0:192,:,:]
filter4_fig1 = filter4_round[192:384,:,:]

part_filter4 = filter4_fig0[16:32,:,:]
part_bias4 = bias4_round[16:32,0]

addr =32768
with open('memory.list','a') as f:
	# Weight address
	f.write("@0000_8000\n")
	
	# bias
	count = 0
	for i in range(0,48):
		if count < 16:
			num = int(part_bias4[count])
		if num > 127:
			num = 127
		if num < -128:
			num = -128
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
	for z_base in range(0, 192, 4):
		for c in range(0,16):
			for y in range(0,3):
				for z in range(z_base, z_base+2):
					for x in range(0,3):
						num = int(part_filter4[c,z,y,x])
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
						
			for y in range(0,3):
				for z in range(z_base+2, z_base+4):
					for x in range(0,3):
						num = int(part_filter4[c,z,y,x])
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
		a = list()
		for x_base in range(0,xend-2):
			for y_base in range(0,ymove+1):
				r=part_bias4[pe]
				i+=1
				for x in range(0, 3):
					for y in range(0, 3):
						for z in range (0,4*48):
							r+=(part_ifmap4[z,y+y_base,x+x_base]*part_filter4[pe,z,y,x])
				r = math.floor(r/(2**(scale+1)))
				if(r>127):
					r=127
				if(r<-128):
					r=-128
				if(r<0):
					r=0
				if(i<4):
					f.write(str(r)+'\t')
				else:
					f.write(str(r)+'\t')
					f.write('\n')
					i=0