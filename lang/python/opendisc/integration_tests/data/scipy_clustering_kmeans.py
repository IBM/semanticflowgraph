import numpy as np
from scipy.cluster.vq import kmeans2

iris = np.genfromtxt('datasets/iris.csv', dtype='f8', delimiter=',', skip_header=1)
iris = np.delete(iris, 4, axis=1)

centroids, clusters = kmeans2(iris, 3)
