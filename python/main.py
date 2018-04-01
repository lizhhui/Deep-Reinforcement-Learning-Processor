import train_conv

i_size, w1_size, w2_size = (28,28,1), (32,5,5,1), (2,5,5,32)
inputs, target = train_conv.data_generate(i_size, w1_size, w2_size, 1, 100)
bf_train, af_train = train_conv.train(inputs, target, i_size, w1_size, w2_size)
