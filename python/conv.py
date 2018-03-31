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

	for n in xrange(0,K):
		for y_base in xrange(0,L-W+1):
			for x_base in xrange(0,L-W+1):
				for z in xrange(0,D):
					for y in xrange(y_base,y_base+W):
						for x in xrange(x_base,x_base+W):
							outputs[x_base,y_base,n] += inputs[x,y,z]*weights[n,x-x_base,y-y_base] 
   
	return outputs

def fc(inputs, weights):
	# inputs[x,y,z], weights[i,o]
	inputs_ar = inputs.flatten()
	inputs_nums = inputs_ar.shape[0]
	output_nums = weights.shape[1]

	outputs = np.zeros((output_nums,))

	for o in xrange(0,output_nums):
		for i in xrange(0,inputs_nums):
			outputs[o] += inputs_ar[i]*weights[i,o]

	return outputs


def data_generate(i_size, w1_size, w2_size, o_size, nums):
	# conv1 - conv2 - FC - o
	# i_size, conv1 inputs size, (x, y, z)
	# w1_size, conv1 weights size (n, x)
	# w2_size, conv2 weights size (n, x)
	# o_size, FC outputs size

	L1 = i_size[0] # conv1 inputs length
	D1 = i_size[2] # conv1 inputs depth
	W1 = w1_size[1] # conv1 weights length
	K1 = w1_size[0] # number of weighs in conv1

	L2 = L1-W1+1 # conv2 inputs length
	D2 = K1 # conv2 inputs depth
	W2 = w2_size[1] # conv2 weights length
	K2 = w2_size[0] # number of weighs in conv2

	i3_nums = (L2-W2+1)*(L2-W2+1)*K2 # FC inputs size

	# target weights generate
	w1_target = np.random.rand(K1, W1, W1, D1)
	w2_target = np.random.rand(K2, W2, W2, D2)
	w3_target = np.random.rand(i3_nums, o_size)

	inputs = list()
	target = list()

	for n in xrange(0,nums):
		i1 = np.random.rand(i_size)
		inputs.append(i1)
		i2 = conv(i1, w1_target) 
		i3 = conv(i2, w2_target)
		o = fc(i3, w3_target)
		target.append(o)
		pass

	return inputs, target

def train(inputs, target, i_size, w1_size, w2_size):

	L1 = i_size[0] # conv1 inputs length
	D1 = i_size[2] # conv1 inputs depth
	W1 = w1_size[1] # conv1 weights length
	K1 = w1_size[0] # number of weighs in conv1

	L2 = L1-W1+1 # conv2 inputs length
	D2 = K1 # conv2 inputs depth
	W2 = w2_size[1] # conv2 weights length
	K2 = w2_size[0] # number of weighs in conv2

	i3_nums = (L2-W2+1)*(L2-W2+1)*K2 # FC inputs size

	# weights randomly inialize
	w1 = np.random.rand(K1, W1, W1, D1)
	w2 = np.random.rand(K2, W2, W2, D2)
	w3 = np.random.rand(i3_nums, 1)

	# weights gradients
	w1_gd = np.zeros(K1, W1, W1, D1)
	w2_gd = np.zeros(K2, W2, W2, D2)
	w3_gd = np.zeros(i3_nums, 1)

	# inputs gradients
	x3_gd = np.zeros(i3_nums)
	x2_gd = np.zeros((L2,L2,D2))

	lr = 0.001 # learning rate

	data_nums = len(target) # dataset size

	for n in xrange(0,data_nums):

		# feed-forward propagation
		i1 = inputs[n]
		i2 = conv(i1, w1) 
		i3 = conv(i2, w2)
		o = fc(i3, w3)
		o = o[0]

		# backward propagation
		t = target[n][0]
		e_gd = o-t # deravetive of 0.5*(o-t)**2

		# fc gradients
		w3_gd = conv(i3, e_gd)
		x3_gd = conv(w3, e_gd)

		w3_gd = w3_gd.flatten()
		w3 -= lr*w3_gd

		# conv2 gradients
		w2_gd = conv(i2, x3_gd)
		



		pass



	pass

