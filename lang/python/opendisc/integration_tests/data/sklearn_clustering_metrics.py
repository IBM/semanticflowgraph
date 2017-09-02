from sklearn.datasets import make_blobs
from sklearn.cluster import KMeans, AgglomerativeClustering
from sklearn.metrics import mutual_info_score

X, labels = make_blobs(n_samples=100, n_features=2, centers=3)

kmeans = KMeans(n_clusters=3)
kmeans_clusters = kmeans.fit_predict(X)

agglom = AgglomerativeClustering(n_clusters=3)
agglom_clusters = agglom.fit_predict(X)

score = mutual_info_score(kmeans_clusters, agglom_clusters)
