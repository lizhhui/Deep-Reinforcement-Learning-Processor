import numpy as np

def conv(inputs, weights):
	# convolution layer with stride = 1
	# inputs[x,y,z], weights[n,x,y,z]
	i_size = inputs.shape
	w_size = weights.shape
	L = i_size[0] # inputs length
	D = i_size[2] # inputs/weights depth
	W = w_size[1] # weights length
	K = w_size[0] # number of weighs
	O_L = L-W+1 # outputs length
	O_D = K # outputs depth
	outputs = np.zeros((O_L, O_L, O_D))
	for n in range(0,K):
		for y_base in range(0,L-W+1):
			for x_base in range(0,L-W+1):
				for z in range(0,D):
					for y in range(y_base,y_base+W):
						for x in range(x_base,x_base+W):
							outputs[x_base,y_base,n] += inputs[x,y,z]*weights[n,x-x_base,y-y_base,z] 
	return outputs


def max_pool(inputs, pool_size):
	# Compute max-pooling on inputs (3-D matirx) using a window size of pool_size*pool_size
	# return the pooling results and posistion
	i_size = inputs.shape
	L = i_size[0] # inputs length
	D = i_size[2] # inputs depth
	O_L = int(L/pool_size)
	outputs = np.zeros((O_L, O_L, D))
	position = np.zeros((O_L, O_L, D))
	for z in range(0,D):
		for y in range(0,O_L):
			y_base = y*pool_size
			for x in range(0,O_L):
				x_base = x*pool_size
				max_num = -99999.99
				max_pos = 0
				for j in range(y_base,y_base+pool_size):
					for i in range(x_base,x_base+pool_size):
						if inputs[i,j,z]>max_num:
							max_num = inputs[i,j,z]
							max_pos = (i-x_base) + (j-y_base)*pool_size
				outputs[x,y,z] = max_num
				position[x,y,z] = max_pos
	return outputs, position


def relu(inputs):
	# Compute the relu function
	# inputs[x,y,z]
	return np.maximum(inputs,0)


def fc(inputs, weights):
	# inputs[x,y,z], weights[i,o]
	inputs_ar = inputs.flatten()
	inputs_nums = inputs_ar.shape[0]
	output_nums = weights.shape[1]
	outputs = np.zeros((output_nums,))
	for o in range(0,output_nums):
		for i in range(0,inputs_nums):
			outputs[o] += inputs_ar[i]*weights[i,o]
	return outputs

def softmax(x):
	# Compute softmax values for each number in inputs (1-D array)
	shift_x = x - np.max(x)
	exp_x = np.exp(shift_x)
	return exp_x / np.sum(exp_x)


def cross_entropy(outputs, label):
	# Compute the cross entropy loss
	# outputs is a 1-d array, label is a number (classification)
	return -np.log(outputs[label])
				
def back_conv(inputs, weights, out_gd):
	# Compute the gradients in one convolution layer
	# inputs[l,l,d], weights[k,w,w,d], out_gd[o_l,o_l,k]
	# The outputs are the weights gradients and inputs gradients
	i_size = inputs.shape
	w_size = weights.shape
	o_size = out_gd.shape
	L = i_size[0]
	D = i_size[2]
	W = w_size[1]
	K = w_size[0] # number of weighs and the depth of outputs
	O_L = o_size[0] # outputs length = L-W+1
	# Reshape out_gd[o_l,o_l,k] into [k,o_l,o_l,1]
	out_gd_rs = np.zeros((K,O_L,O_L,1))
	for n in range(0,K):
		for y in range(0,O_L):
			for x in range(0,O_L):
				out_gd_rs[n,x,y,0] = out_gd[x,y,n]
	w_gd = np.zeros(weights.shape)
	for d in range(0,D):
		tmp = conv(inputs[:,:,d].reshape((L,L,1)), out_gd_rs)
		for i in range(0,K):
			w_gd[i,:,:,d] = tmp[:,:,i]
	w_rs = np.zeros((D, W, W, K))
	for i in range(0,K):
		for j in range(0,D):
			w_rs[j,:,:,i] = weights[i,:,:,j] # w reshape
	w_rsrt = np.rot90(w_rs,2) # rotate 180
	pad_num = W-1
	out_gd_pad = np.pad(out_gd, ((pad_num,pad_num), (pad_num,pad_num), (0,0)), 'constant')
	i_gd = conv(out_gd_pad, w_rsrt)
	return w_gd, i_gd

def back_maxpool(out_gd, pos, pool_size):
	# Compute the gradients of max-pooling layer
	o_size = out_gd.shape
	i_size = (pool_size*o_size[0], pool_size*o_size[1], o_size[2])
	i_gd = np.zeros(i_size)
	for z in range(0,o_size[2]):
		for y in range(0,o_size[1]):
			y_base = y*pool_size
			for x in range(0,o_size[0]):
				x_base = x*pool_size
				x_add = int(pos[x,y,z]%pool_size)
				y_add = int(pos[x,y,z]/pool_size)
				i_gd[(x_base+x_add), (y_base+y_add), z] = out_gd[x,y,z]
	return i_gd

def back_relu(inputs, out_gd):
	# Compute the gradients of relu
	# inputs[l,l,d], out_gd[l,l,d]
	i_gd = out_gd
	i_size = inputs.shape
	for z in range(0,i_size[2]):
		for y in range(0,i_size[1]):
			for x in range(0,i_size[0]):
				if inputs[x,y,z]<=0:
					i_gd[x,y,z]=0
	return i_gd

def back_fc(inputs, weights, out_gd):
	# Compute the gradients in one FC layer
	# inputs[i_size], weights[i_size, o_size], out_gd[o_size]
	# The results are the weights gradients and inputs gradients
	i_size = inputs.shape[0]
	o_size = out_gd.shape[0]
	w_gd = np.zeros((i_size,o_size))
	for o in range(0,o_size):
		for i in range(0,i_size):
			w_gd[i,o] = out_gd[o]*inputs[i]
	i_gd = np.zeros((i_size,))
	for i in range(0,i_size):
		for o in range(0,o_size):
			i_gd[i] += out_gd[o]*weights[i,o]
	return w_gd, i_gd


def back_ce(outputs, label):
	# Compute the gradients of cross entropy loss on softmax inputs, d(a_k)=o_k-t_k
	# outputs is a 1-d array (softmax outputs), label is a number (classification)
	o_gd = outputs
	o_gd[label] -= 1
	return o_gd