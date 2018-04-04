from train_conv import *
import mnist
import numpy as np

# mnist.init()
x_train, t_train, x_test, t_test = mnist.load()

x_train=np.reshape(x_train,(60000,28,28,1))
x_test=np.reshape(x_test,(10000,28,28,1))

c1_size = (8, 5, 5, 1)
c2_size = (16, 5, 5, 8)
f1_size = (256, 256)
f2_size = (256, 10)


# def inference(inputs, result):
# 	# The inference for mnist, inputs is a [28,28,1] 3-d matrix
# 	# 
nums = 10
inputs = np.random.rand(nums, 10, 10, 1)
w1_target = (np.random.rand(4, 3, 3, 1)-0.5)
w2_target = (np.random.rand(2, 3, 3, 4)-0.5)
w3_target = (np.random.rand(8, 4)-0.5)
# conv1: [10,10,1]*[4,3,3,1]=[8,8,4], relu
# pool2x2: [8,8,4]->[4,4,4]
# conv2: [4,4,4]*[2,3,3,4]=[2,2,2], relu
# fc: [2,2,2]->[4]
# softmax
def inference(inputs, w1, w2, w3):
	o1 = relu(conv(inputs, w1))
	x2, x2_pos = max_pool(o1, 2)
	o2 = relu(conv(x2, w2))
	o3 = fc(o2, w3)
	results = softmax(o3)
	return results

def inference_train(inputs, w1, w2, w3):
	o1 = relu(conv(inputs, w1))
	x2, x2_pos = max_pool(o1, 2)
	o2 = relu(conv(x2, w2))
	o3 = fc(o2, w3)
	results = softmax(o3)
	return o1, x2_pos, o2, o3, results

# inference, generate data
outputs = np.zeros((nums,4))
for i in range(0,nums):
 	outputs[i,:] = inference(inputs[i,:,:,:], w1_target, w2_target, w3_target)
labels = np.argmax(outputs, axis=1)

w1 = (np.random.rand(4, 3, 3, 1)-0.5)
w2 = (np.random.rand(2, 3, 3, 4)-0.5)
w3 = (np.random.rand(8, 4)-0.5)

w1_gd = np.zeros((4, 3, 3, 1))
w2_gd = np.zeros((2, 3, 3, 4))
w3_gd = np.zeros((8, 4))

# train, SGD
lr = 0.001
for i in range(0,nums):
	x = np.random.randint(nums, size=1)[0]
	o1, x2_pos, o2, o3, o = inference_train(inputs[x,:,:,:], w1, w2, w3)
	label = labels[x]
	o_gd = back_ce(o, label)
	w3_gd, i3_gd = back_fc(o2.flatten(), w3, o_gd)
	w3 -= lr*w3_gd
	o2_gd = np.reshape(i3_gd, (2,2,2))
	w2_gd, i2_gd = back_conv(x2, w2, back_relu(o2, o2_gd))
	w2 -= lr*w2_gd
	w1_gd, i1_gd = back_conv(inputs[x,:,:,:], w1, back_relu(o1 ,back_maxpool(i2_gd, x2_pos, 2)))
	w1 -= lr*w1_gd


c1 = (np.random.rand(c1_size[0],c1_size[1],c1_size[2],c1_size[3])-0.5)
c2 = (np.random.rand(c2_size[0],c2_size[1],c2_size[2],c2_size[3])-0.5)
f1 = (np.random.rand(f1_size[0], f1_size[1])-0.5)
f2 = (np.random.rand(f2_size[0], f2_size[1])-0.5)

# train, SGD
lr = 0.001
for i in range(0,nums):
	x = np.random.randint(60000, size=1)[0]
	o1, x2_pos, x2, o2, x3_pos, x3, o3, o = mnist_in(x_train[x,:,:,:], c1, c2, f1, f2)
	label = t_train[x]
	o_gd = back_ce(o, label)
	f2_gd, i4_gd = back_fc(o3.flatten(), f2, o_gd)
	f1_gd, i3_gd = back_fc(x3.flatten(), f1, i4_gd)
	
	o2_gdrs = np.reshape(i3_gd, (4,4,16))
	o2_gd = back_maxpool(o2_gdrs, x3_pos, 2)
	c2_gd, i2_gd = back_conv(x2, c2, back_relu(o2, o2_gd))

	o1_gd = back_maxpool(i2_gd, x2_pos, 2)
	c1_gd, i1_gd = back_conv(x_train[x,:,:,:], c1, back_relu(o1, o1_gd))
	
	
	f2 -= lr*f2_gd
	f1 -= lr*f1_gd
	w3 -= lr*w3_gd
	w1 -= lr*w1_gd