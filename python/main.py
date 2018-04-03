from train_conv import *
import mnist

# mnist.init()
# x_train, t_train, x_test, t_test = mnist.load()

# x_train=np.reshape(x_train,(60000,28,28,1))
# x_test=np.reshape(x_test,(10000,28,28,1))


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