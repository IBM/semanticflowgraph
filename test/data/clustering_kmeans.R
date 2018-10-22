iris = read.csv("datasets/iris.csv", stringsAsFactors=FALSE)
iris = iris[, names(iris) != "Species"]

km = kmeans(iris, 3)
centroids = km$centers
clusters = km$cluster