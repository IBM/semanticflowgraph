from opendisc.api import read_data
from sklearn.cluster import KMeans

iris_path = str(data_path.joinpath('iris.csv'))
iris = read_data(iris_path)
iris = iris.drop('Species', 1)

kmeans = KMeans(n_clusters=3).fit(iris.values)
clusters = kmeans.labels_
