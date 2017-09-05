import pandas as pd
from sklearn.cluster import KMeans

iris = pd.read_csv('datasets/iris.csv')
iris = iris.drop('Species', 1)

kmeans = KMeans(n_clusters=3).fit(iris.values)
clusters = kmeans.labels_
