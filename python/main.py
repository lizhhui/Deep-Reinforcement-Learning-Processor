import train_conv

i_size, w1_size, w2_size = (10,10,4), (5,3,3,4), (2,3,3,5)
inputs, target = train_conv.data_generate(i_size, w1_size, w2_size, 1, 100)
bf_train, af_train = train_conv.train(inputs, target, i_size, w1_size, w2_size)
