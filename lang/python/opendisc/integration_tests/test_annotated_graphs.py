from __future__ import absolute_import

from pathlib2 import Path
import unittest

import networkx as nx
import networkx.algorithms.isomorphism as iso

from ..core.annotated_graph import AnnotatedGraphBuilder
from ..core.flow_graph_builder import FlowGraphBuilder
from ..kernel.trace.tracer import Tracer

data_path = Path(__file__).parent.joinpath('data')


class TestPythonAnnotatedGraphs(unittest.TestCase):
    """ Integration tests for Python annotated flow graphs.
    
    Tests the pipeline:
        Python traces -> concrete flow graph -> annotated flow graph

    Uses the real annotations for Python libraries like pandas, sklearn, etc.
    """
    
    def setUp(self):
        """ Set up the tracing pipeline.
        """
        self.tracer = Tracer(
            modules = [ 'opendisc.integration_tests.test_annotated_graphs' ],
        )
        self.flow_graph_builder = FlowGraphBuilder()
        self.annotated_graph_builder = AnnotatedGraphBuilder()
        
        def handler(changed):
            event = changed['new']
            if event:
                self.flow_graph_builder.push_event(event)
        self.tracer.observe(handler, 'event')
    
    def annotated_graph(self):
        """ Build the annotated graph.
        """
        concrete_graph = self.flow_graph_builder.graph
        annotated_graph = self.annotated_graph_builder.build(concrete_graph)
        return annotated_graph
    
    def assert_isomorphic(self, actual, target):
        """ Assert that two annotated flow graphs are isomorphic.
        """
        attr = [ 'kind', 'label', 'value' ]
        defaults = [ None, '', None ]
        node_match = iso.categorical_node_match(attr, defaults)
        matcher = iso.DiGraphMatcher(target, actual, node_match=node_match)
        self.assertTrue(matcher.is_isomorphic())
        return matcher.mapping
    
    def test_sklearn_clustering_kmeans(self):
        """ K-means clustering on the Iris dataset.
        """
        with self.tracer:
            from opendisc.api import read_data
            from sklearn.cluster import KMeans
            
            iris_path = str(data_path.joinpath('iris.csv'))
            iris = read_data(iris_path)
            iris = iris.drop('Species', 1)
            
            kmeans = KMeans(n_clusters=3)
            clusters = kmeans.fit_predict(iris.values)
        
        actual = self.annotated_graph()
        target = nx.DiGraph()
        target.add_node('source', kind='entity', label='object')
        target.add_node('read_csv', kind='action', label='read-data')
        target.add_node('iris', kind='entity', label='data-frame')
        target.add_node('transform', kind='action')
        target.add_node('iris_trans', kind='entity', label='array')
        target.add_node('kmeans', kind='entity', label='k-means')
        target.add_node('fit_predict', kind='action', label='fit-cluster')
        target.add_node('kmeans_fit', kind='entity', label='k-means')
        target.add_node('clusters', kind='entity', label='array')
        target.add_path(['source', 'read_csv', 'iris', 'transform',
                         'iris_trans', 'fit_predict', 'clusters'])
        target.add_path(['kmeans', 'fit_predict', 'kmeans_fit'])
        mapping = self.assert_isomorphic(actual, target)
        
        # Test that some entity IDs are stored.
        data = actual.node[mapping['kmeans']]
        self.assertEqual(data['id'], self.tracer.object_tracker.get_id(kmeans))
        data = actual.node[mapping['clusters']]
        self.assertEqual(data['id'], self.tracer.object_tracker.get_id(clusters))
    
    def test_sklearn_clustering_metric(self):
        """ Compare two clusterings using a cluster similarity metric.
        """
        from sklearn.datasets import make_blobs
        X, labels = make_blobs(n_samples=100, n_features=2, centers=3)
        
        with self.tracer:
            from sklearn.cluster import KMeans, AgglomerativeClustering
            from sklearn.metrics import mutual_info_score
            
            kmeans = KMeans(n_clusters=3)
            kmeans_clusters = kmeans.fit_predict(X)

            agglom = AgglomerativeClustering(n_clusters=3)
            agglom_clusters = agglom.fit_predict(X)
            
            score = mutual_info_score(kmeans_clusters, agglom_clusters)
        
        actual = self.annotated_graph()
        target = nx.MultiDiGraph()
        target.add_node('X', kind='entity', label='array')
        
        target.add_node('kmeans', kind='entity', label='k-means')
        target.add_node('fit_kmeans', kind='action', label='fit-cluster')
        target.add_node('kmeans_fit', kind='entity', label='k-means')
        target.add_node('kmeans_clusters', kind='entity', label='array')
        target.add_path(['X', 'fit_kmeans', 'kmeans_clusters'])
        target.add_path(['kmeans', 'fit_kmeans', 'kmeans_fit'])
        
        target.add_node('agglom', kind='entity', label='agglomerative')
        target.add_node('fit_agglom', kind='action', label='fit-cluster')
        target.add_node('agglom_fit', kind='entity', label='agglomerative')
        target.add_node('agglom_clusters', kind='entity', label='array')
        target.add_path(['X', 'fit_agglom', 'agglom_clusters'])
        target.add_path(['agglom', 'fit_agglom', 'agglom_fit'])
        
        target.add_node('mutual_info', kind='action', label='mutual-info')
        target.add_node('score', kind='entity', label='value', value=score)
        target.add_edge('kmeans_clusters', 'mutual_info')
        target.add_edge('agglom_clusters', 'mutual_info')
        target.add_edge('mutual_info', 'score')
    
        self.assert_isomorphic(actual, target)
    
    def test_sklearn_regression_with_metric(self):
        """ Linear regression on diabetes data with some error measures.
        """
        with self.tracer:
            from opendisc.api import read_data
            from sklearn.linear_model import LinearRegression
            import sklearn.metrics
            
            diabetes_path = str(data_path.joinpath('diabetes.csv'))
            diabetes = read_data(diabetes_path)
            
            X = diabetes.drop('y', 1)
            y = diabetes['y']
            lm = LinearRegression()
            lm.fit(X, y)
            
            y_hat = lm.predict(X)
            l1_err = sklearn.metrics.mean_absolute_error(y, y_hat)
            l2_err = sklearn.metrics.mean_squared_error(y, y_hat)
        
        actual = self.annotated_graph()
        target = nx.DiGraph()
        
        target.add_node('source', kind='entity', label='object')
        target.add_node('read_csv', kind='action', label='read-data')
        target.add_node('diabetes', kind='entity', label='data-frame')
        target.add_path(['source', 'read_csv', 'diabetes'])
        
        target.add_node('trans_X', kind='action')
        target.add_node('X', kind='entity', label='data-frame')
        target.add_node('trans_y', kind='action')
        target.add_node('y', kind='entity', label='series')
        target.add_node('lm', kind='entity', label='ols')
        target.add_node('fit', kind='action', label='fit-regression')
        target.add_node('lm_fit', kind='entity', label='ols')
        target.add_path(['diabetes', 'trans_X', 'X', 'fit'])
        target.add_path(['diabetes', 'trans_y', 'y', 'fit'])
        target.add_path(['lm', 'fit', 'lm_fit'])
        
        target.add_node('predict', kind='action', label='predict-regression')
        target.add_node('y_hat', kind='entity', label='array')
        target.add_node('l1_err', kind='action', label='l1-error')
        target.add_node('l1_val', kind='entity', label='value', value=l1_err)
        target.add_node('l2_err', kind='action', label='l2-error')
        target.add_node('l2_val', kind='entity', label='value', value=l2_err)
        target.add_path(['X', 'predict'])
        target.add_path(['lm_fit', 'predict', 'y_hat'])
        target.add_path(['y', 'l1_err'])
        target.add_path(['y_hat', 'l1_err', 'l1_val'])
        target.add_path(['y', 'l2_err'])
        target.add_path(['y_hat', 'l2_err', 'l2_val'])
        
        mapping = self.assert_isomorphic(actual, target)
        
        # Test that some entity slots are retrieved.
        data = actual.node[mapping['source']]
        self.assertEqual(data['slots']['filename']['value'], diabetes_path)
        
        data = actual.node[mapping['diabetes']]
        self.assertEqual(data['slots']['n-rows']['value'], len(diabetes))
        self.assertEqual(data['slots']['columns']['value'], list(diabetes.columns))
        
        data = actual.node[mapping['lm_fit']]
        self.assertEqual(data['slots']['intercept']['value'], lm.intercept_)
        self.assertEqual(data['slots']['coefficients']['id'],
                         self.tracer.object_tracker.get_id(lm.coef_))
    
    def test_statsmodels_regression(self):
        """ Linear regression with an R data set.
        """
        # Code ripped from statsmodels homepage.
        with self.tracer:
            import numpy as np
            import statsmodels.api as sm
            import statsmodels.formula.api as smf

            # Load data
            dat = sm.datasets.get_rdataset('Guerry', 'HistData', cache=True).data

            # Fit regression model (using the natural log of one of the regressors)
            results = smf.ols('Lottery ~ Literacy + np.log(Pop1831)', data=dat).fit()
        
        actual = self.annotated_graph()
        target = nx.DiGraph()
        target.add_node('source', kind='entity', label='object')
        target.add_node('load_data', kind='action', label='load-r-data')
        target.add_node('dataset', kind='entity', label='dataset')
        target.add_node('trans', kind='action')
        target.add_node('ols', kind='entity', label='ols')
        target.add_node('fit', kind='action', label='fit-regression')
        target.add_node('results', kind='entity', label='regression-results')
        target.add_path(['source', 'load_data', 'dataset', 'trans', 'ols',
                         'fit', 'results'])
        mapping = self.assert_isomorphic(actual, target)
        
        data = actual.node[mapping['source']]
        self.assertEqual(data['slots']['name']['value'], 'Guerry')
        self.assertEqual(data['slots']['package']['value'], 'HistData')


if __name__ == '__main__':
    unittest.main()
