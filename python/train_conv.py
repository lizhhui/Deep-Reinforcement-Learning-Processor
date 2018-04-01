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
	w1_target = (np.random.rand(K1, W1, W1, D1)-0.5)
	w2_target = (np.random.rand(K2, W2, W2, D2)-0.5)
	w3_target = (np.random.rand(i3_nums, o_size)-0.5)

	inputs = list()
	target = list()

	for n in range(0,nums):
		i1 = np.random.rand(i_size[0],i_size[1],i_size[2])
		i1 = i1.astype(np.float64)
		inputs.append(i1)
		i2 = conv(i1, w1_target) 
		i3 = conv(i2, w2_target)
		o = fc(i3, w3_target)
		# o += np.random.normal(0,0.4,o.shape[0])
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
	w1 = (np.random.rand(K1, W1, W1, D1)-0.5)
	w2 = (np.random.rand(K2, W2, W2, D2)-0.5)
	w3 = (np.random.rand(i3_nums, 1)-0.5)
	# w1 = np.zeros((K1, W1, W1, D1), dtype = np.float64)
	# w2 = np.zeros((K2, W2, W2, D2), dtype = np.float64)
	# w3 = np.zeros((i3_nums, 1), dtype = np.float64)

	# weights gradients
	w1_gd = np.zeros((K1, W1, W1, D1), dtype = np.float64)
	w2_gd = np.zeros((K2, W2, W2, D2), dtype = np.float64)
	w3_gd = np.zeros((i3_nums, 1), dtype = np.float64)

	# inputs gradients
	i3_gd = np.zeros((i3_nums,), dtype = np.float64)
	i2_gd = np.zeros((L2,L2,D2), dtype = np.float64)

	lr = 0.002 # learning rate

	data_nums = len(target) # dataset size

	bf_train = 0
	for n in range(0,data_nums):
		i2 = conv(inputs[n], w1) 
		i3 = conv(i2, w2)
		o = fc(i3, w3)
		bf_train += (target[n]-o)**2
	bf_train /= data_nums


	af_train = list()
	for n in range(0,data_nums):

		# feed-forward propagation
		i1 = inputs[n]
		i2 = conv(i1, w1) 
		i3 = conv(i2, w2)
		o = fc(i3, w3)
		o = o[0]

		# backward propagation
		t = target[n][0]
		o_gd = o-t # deravetive of 0.5*(o-t)**2

		# fc gradients
		# o_gd = np.reshape(o_gd, (1,1,1,1))
		w3_gd = i3*o_gd
		i3_gd = w3*o_gd

		w3_gd = np.reshape(w3_gd, (i3_nums, 1))
		w3 -= lr*w3_gd

		# conv2 gradients
		i3_gd_rs = np.reshape(i3_gd, (K2, (L2-W2+1), (L2-W2+1), 1))
		for d in range(0,D2):
			tmp = conv(i2[:,:,d].reshape((L2,L2,1)), i3_gd_rs) #
			for i in range(0,K2):
				w2_gd[i,:,:,d] = tmp[:,:,i]


		w2_rs = np.zeros((D2, W2, W2, K2))
		for i in range(0,K2):
			for j in range(0,D2):
				w2_rs[j,:,:,i] = w2[i,:,:,j] # w2 reshape
		w2_rsrt = np.rot90(w2_rs,2) # rotate 180

		pad_num = W2-1
		i3_gd_pad = np.pad(np.reshape(i3_gd, ((L2-W2+1), (L2-W2+1), K2)), ((pad_num,pad_num), (pad_num,pad_num), (0,0)), 'constant')
		i2_gd = conv(i3_gd_pad, w2_rsrt)

		w2 -= lr*w2_gd

		# conv1 gradients
		i2_gd = np.reshape(i2_gd, (K1, L2, L2, 1))
		for d in range(0,D1):
			tmp = conv(i1[:,:,d].reshape((L1,L1,1)), i2_gd)
			for i in range(0,K1):
				w1_gd[i,:,:,d] = tmp[:,:,i]

		w1 -= lr*w1_gd
		
		error = 0
		for n in np.random.randint(data_nums,size=50):
			i2 = conv(inputs[n], w1) 
			i3 = conv(i2, w2)
			o = fc(i3, w3)
			error += (target[n]-o)**2
		error /= 50
		print(error)
		af_train.append(error)

	error = 0
	for n in range(0,data_nums):
		i2 = conv(inputs[n], w1) 
		i3 = conv(i2, w2)
		o = fc(i3, w3)
		error += (target[n]-o)**2
	error /= data_nums

	print(error)


	return bf_train, af_train