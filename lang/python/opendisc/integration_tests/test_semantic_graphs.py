from __future__ import absolute_import

from pathlib2 import Path
import tempfile
import unittest

import networkx as nx
import networkx.algorithms.isomorphism as iso

from ..core.annotated_graph import AnnotatedGraphBuilder
from ..core.flow_graph_builder import FlowGraphBuilder
from ..core.semantic_graph import SemanticGraphBuilder
from ..kernel.trace.tracer import Tracer

data_path = Path(__file__).parent.joinpath('data')


class TestPythonSemanticGraphs(unittest.TestCase):
    """ Integration tests for Python semantic flow graphs.
    
    Tests the full pipeline:
        Python traces -> concrete flow graph -> annotated flow graph -> semantic flow graph
    
    Uses the real annotations for Python libraries like pandas, sklearn, etc.
    """

    def setUp(self):
        """ Set up the tracing pipeline.
        """
        self.tracer = Tracer(
            modules = [ 'opendisc.integration_tests.test_semantic_graphs' ],
        )
        self.flow_graph_builder = FlowGraphBuilder()
        self.annotated_graph_builder = AnnotatedGraphBuilder()
        self.semantic_graph_builder = SemanticGraphBuilder()
        
        def handler(changed):
            event = changed['new']
            if event:
                self.flow_graph_builder.push_event(event)
        self.tracer.observe(handler, 'event')
    
    def semantic_graph(self):
        """ Build the semantic graph.
        """
        concrete_graph = self.flow_graph_builder.graph
        annotated_graph = self.annotated_graph_builder.build(concrete_graph)
        semantic_graph = self.semantic_graph_builder.build(annotated_graph)
        return semantic_graph
    
    def assert_isomorphic(self, actual, target):
        """ Assert that two semantic flow graphs are isomorphic.
        """
        attr = [ 'type', 'value' ]
        defaults = [ None, None ]
        node_match = iso.categorical_node_match(attr, defaults)
        
        attr = [ 'aspect', 'input', 'output' ]
        defaults = [ None, False, False ]
        edge_match = iso.categorical_multiedge_match(attr, defaults)
        
        matcher = iso.DiGraphMatcher(target, actual, node_match=node_match,
                                     edge_match=edge_match)
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
            clusters = kmeans.fit_predict(iris)
        
        actual = self.semantic_graph()
        target = nx.MultiDiGraph()
        target.add_node('source', type='file')
        target.add_node('filename', type='path', value=iris_path)
        target.add_edge('source', 'filename', aspect='filename')
        
        target.add_node('read_csv', type='read-data')
        target.add_edge('read_csv', 'source', aspect='source', input=True)
        
        target.add_node('iris', type='table')
        #target.add_node('iris_nrows', type='integer', value=150)
        #target.add_edge('iris', 'iris_nrows', aspect='n-rows')
        target.add_edge('read_csv', 'iris', aspect='data', output=True)
        
        target.add_node('transform', type='action')
        target.add_node('iris_trans', type='table')
        #target.add_node('iris_trans_nrows', type='integer', value=150)
        #target.add_edge('iris_trans', 'iris_trans_nrows', aspect='n-rows')
        target.add_edge('transform', 'iris', input=True)
        target.add_edge('transform', 'iris_trans', output=True)
        
        target.add_node('fit_predict', type='fit')
        target.add_edge('fit_predict', 'iris_trans', aspect='data', input=True)
        
        target.add_node('kmeans', type='k-means')
        target.add_node('kmeans_nclusters', type='integer', value=3)
        target.add_node('kmeans_clusters', type='array')
        target.add_node('kmeans_centers', type='array')
        target.add_edge('kmeans', 'kmeans_nclusters', aspect='n-clusters')
        target.add_edge('kmeans', 'kmeans_clusters', aspect='clusters')
        target.add_edge('kmeans', 'kmeans_centers', aspect='centers')
        target.add_edge('fit_predict', 'kmeans', aspect='model', output=True)
        
        self.assert_isomorphic(actual, target)
    
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
        
        actual = self.semantic_graph()
        target = nx.MultiDiGraph()
        target.add_node('X', type='array')
        
        target.add_node('kmeans', type='k-means')
        target.add_node('fit_kmeans', type='fit')
        target.add_edge('fit_kmeans', 'X', aspect='data', input=True)
        target.add_edge('fit_kmeans', 'kmeans', aspect='model', output=True)
        
        target.add_node('kmeans_nclusters', type='integer', value=3)
        target.add_node('kmeans_clusters', type='array')
        target.add_node('kmeans_centers', type='array')
        target.add_edge('kmeans', 'kmeans_nclusters', aspect='n-clusters')
        target.add_edge('kmeans', 'kmeans_clusters', aspect='clusters')
        target.add_edge('kmeans', 'kmeans_centers', aspect='centers')
        
        target.add_node('agglom', type='agglomerative-clustering')
        target.add_node('fit_agglom', type='fit')
        target.add_edge('fit_agglom', 'X', aspect='data', input=True)
        target.add_edge('fit_agglom', 'agglom', aspect='model', output=True)
        
        target.add_node('agglom_nclusters', type='integer', value=3)
        target.add_node('agglom_clusters', type='array')
        target.add_node('agglom_linkage', type='linkage-matrix')
        target.add_edge('agglom', 'agglom_nclusters', aspect='n-clusters')
        target.add_edge('agglom', 'agglom_clusters', aspect='clusters')
        target.add_edge('agglom', 'agglom_linkage', aspect='linkage')
        
        target.add_node('mutual_info', type='mutual-information')
        target.add_node('mutual_info_score', type='number', value=score)
        target.add_edge('mutual_info', 'kmeans_clusters', aspect='left', input=True)
        target.add_edge('mutual_info', 'agglom_clusters', aspect='right', input=True)
        target.add_edge('mutual_info', 'mutual_info_score', aspect='score', output=True)
        
        self.assert_isomorphic(actual, target)
    
    def test_pandas_read_sql(self):
        """ Read a table from a SQLite database. 
        """
        import pandas as pd
        import sqlalchemy as sa
        
        with tempfile.NamedTemporaryFile(suffix='.db') as f:
            table = pd.DataFrame({'x': [0,1,2], 'y': [True,False,True]})
            conn = sa.create_engine('sqlite:///' + f.name)
            table.to_sql('my_table', conn)
        
            with self.tracer:
                conn = sa.create_engine('sqlite:///' + f.name)
                df = pd.read_sql_table('my_table', conn)
        
        actual = self.semantic_graph()
        target = nx.MultiDiGraph()
        target.add_node('source', type='sql-table')
        target.add_node('table_name', type='string', value='my_table')
        target.add_node('conn', type='sql-database')
        target.add_edge('source', 'table_name', aspect='name')
        target.add_edge('source', 'conn', aspect='database')
        
        target.add_node('read_sql_table', type='read-data')
        target.add_edge('read_sql_table', 'source', aspect='source', input=True)

        target.add_node('df', type='table')
        #target.add_node('df_nrows', type='integer', value=3)
        target.add_edge('read_sql_table', 'df', aspect='data', output=True)
        #target.add_edge('df', 'df_nrows', aspect='n-rows')
        
        mapping = self.assert_isomorphic(actual, target)
        self.assertEqual(actual.node[mapping['conn']]['id'],
                         self.tracer.object_tracker.get_id(conn))


if __name__ == '__main__':
    unittest.main()
