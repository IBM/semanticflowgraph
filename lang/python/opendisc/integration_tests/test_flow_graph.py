from __future__ import absolute_import

import os
from pathlib2 import Path
import unittest

import networkx as nx
import networkx.algorithms.isomorphism as iso

from ..core.flow_graph import new_flow_graph, flow_graph_to_graphml
from ..core.flow_graph_builder import FlowGraphBuilder
from ..core.graphml import write_graphml
from ..core.remote_annotation_db import RemoteAnnotationDB
from ..trace.tracer import Tracer

data_path = Path(__file__).parent.joinpath('data')
test_module_name = 'integration_test_flow_graph'


class IntegrationTestFlowGraph(unittest.TestCase):
    """ Integration tests for Python flow graphs.
    
    Uses real Python libraries (pandas, sklearn, etc) and their annotations.
    """
    
    @classmethod
    def setUpClass(cls):
        """ Set up the tracer and flow graph builder.
        """
        cls.tracer = Tracer(modules=[test_module_name])
        cls.builder = FlowGraphBuilder(store_slots=False)
        cls.builder.annotator.db = RemoteAnnotationDB.from_library_config()
        
        def handler(changed):
            event = changed['new']
            if event:
                cls.builder.push_event(event)
        cls.tracer.observe(handler, 'event')
    
    def setUp(self):
        """ Reset the flow graph builder.
        """
        self.builder.reset()
    
    def assert_isomorphic(self, actual, target):
        """ Assert that two flow graphs are isomorphic.
        """
        node_attrs = [ 'annotation', 'qual_name', 'slot' ]
        node_defaults = [ None ] * len(node_attrs)
        edge_attrs = [ 'annotation', 'sourceport', 'targetport' ]
        edge_defaults = [ None ] * len(edge_attrs)
        node_match = iso.categorical_node_match(node_attrs, node_defaults)
        edge_match = iso.categorical_multiedge_match(edge_attrs, edge_defaults)
        matcher = iso.DiGraphMatcher(
            target, actual, node_match=node_match, edge_match=edge_match)
        self.assertTrue(matcher.is_isomorphic())
        return matcher.mapping
    
    def trace_script(self, name, env=None, save=True):
        """ Execute and trace a test script.
        """
        # Read and compile the script.
        filename = str(data_path.joinpath(name + '.py'))
        with open(filename) as f:
            code = compile(f.read(), filename, 'exec')
        
        # Run the script with the right working directory and module name.
        cwd = os.getcwd()
        env = env or {}
        env['__name__'] = test_module_name
        try:
            os.chdir(str(data_path))
            with self.tracer:
                exec(code, env)
        finally:
            os.chdir(cwd)
        
        # Save the graph as GraphML for consumption by downstream tests.
        graph = self.builder.graph
        if save:
            outname = str(data_path.joinpath(name + '.xml'))
            graphml = flow_graph_to_graphml(graph, simplify_outputs=True)
            write_graphml(graphml, outname)
        
        return graph
    
    def test_pandas_read_sql(self):
        """ Read SQL table using pandas and SQLAlchemy.
        """
        graph = self.trace_script("pandas_read_sql")
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('create_engine', qual_name='create_engine')
        target.add_node('read_table', qual_name='read_sql_table',
                        annotation='python/pandas/read-sql-table')
        target.add_edge('create_engine', 'read_table',
                        sourceport='__return__', targetport='con',
                        annotation='python/sqlalchemy/engine')
        target.add_edge('create_engine', outputs, sourceport='__return__',
                        annotation='python/sqlalchemy/engine')
        target.add_edge('read_table', outputs, sourceport='__return__',
                        annotation='python/pandas/data-frame')
        self.assert_isomorphic(graph, target)
    
    def test_sklearn_clustering_kmeans(self):
        """ K-means clustering on the Iris dataset using sklearn.
        """
        graph = self.trace_script("sklearn_clustering_kmeans")
        graph.remove_node(graph.graph['output_node'])
        
        target = new_flow_graph()
        target.remove_node(target.graph['output_node'])
        target.add_node('read', qual_name='_make_parser_function.<locals>.parser_f',
                        annotation='python/pandas/read-table')
        target.add_node('drop', qual_name='NDFrame.drop')
        target.add_node('values', qual_name='DataFrame.__getattribute__',
                        slot='values')
        target.add_edge('read', 'drop', annotation='python/pandas/data-frame',
                        sourceport='__return__', targetport='self')
        target.add_edge('drop', 'values', annotation='python/pandas/data-frame',
                        sourceport='__return__', targetport='self')
        target.add_node('kmeans', qual_name='KMeans.__init__')
        target.add_node('fit', qual_name='KMeans.fit',
                        annotation='python/sklearn/fit')
        target.add_node('clusters', qual_name='KMeans.__getattribute__',
                        slot='labels_')
        target.add_edge('kmeans', 'fit', annotation='python/sklearn/k-means',
                        sourceport='self!', targetport='self')
        target.add_edge('values', 'fit', annotation='python/numpy/ndarray',
                        sourceport='__return__', targetport='X')
        target.add_edge('fit', 'clusters', annotation='python/sklearn/k-means',
                        sourceport='self!', targetport='self')
        self.assert_isomorphic(graph, target)
    
    def test_sklearn_clustering_metric(self):
        """ Compare sklearn clustering models using a cluster similarity metric.
        """
        graph = self.trace_script("sklearn_clustering_metrics")
        graph.remove_node(graph.graph['output_node'])
        
        target = new_flow_graph()
        target.remove_node(target.graph['output_node'])
        target.add_node('make_blobs', qual_name='make_blobs')
        target.add_node('kmeans', qual_name='KMeans.__init__')
        target.add_node('fit_kmeans', qual_name='KMeans.fit_predict',
                        annotation='python/sklearn/fit-predict-clustering')
        target.add_node('agglom', qual_name='AgglomerativeClustering.__init__')
        target.add_node('fit_agglom', qual_name='ClusterMixin.fit_predict',
                        annotation='python/sklearn/fit-predict-clustering')
        target.add_node('score', qual_name='mutual_info_score')
        target.add_edge('kmeans', 'fit_kmeans',
                        sourceport='self!', targetport='self',
                        annotation='python/sklearn/k-means')
        target.add_edge('make_blobs', 'fit_kmeans',
                        sourceport='__return__.0', targetport='X',
                        annotation='python/numpy/ndarray')
        target.add_edge('agglom', 'fit_agglom',
                        sourceport='self!', targetport='self',
                        annotation='python/sklearn/agglomerative')
        target.add_edge('make_blobs', 'fit_agglom',
                        sourceport='__return__.0', targetport='X',
                        annotation='python/numpy/ndarray')
        target.add_edge('fit_kmeans', 'score',
                        sourceport='__return__', targetport='labels_true',
                        annotation='python/numpy/ndarray')
        target.add_edge('fit_agglom', 'score',
                        sourceport='__return__', targetport='labels_pred',
                        annotation='python/numpy/ndarray')
        self.assert_isomorphic(graph, target)
    
    def test_sklearn_regression_metrics(self):
        """ Errors metrics for linear regression using sklearn.
        """
        graph = self.trace_script("sklearn_regression_metrics")
        graph.remove_node(graph.graph['output_node'])
        
        target = new_flow_graph()
        target.remove_node(target.graph['output_node'])
        target.add_node('read', qual_name='_make_parser_function.<locals>.parser_f',
                        annotation='python/pandas/read-table')
        target.add_node('X', qual_name='NDFrame.drop')
        target.add_node('y', qual_name='DataFrame.__getitem__')
        target.add_node('lm', qual_name='LinearRegression.__init__')
        target.add_node('fit', qual_name='LinearRegression.fit',
                        annotation='python/sklearn/fit-regression')
        target.add_node('predict', qual_name='LinearModel.predict',
                        annotation='python/sklearn/predict-regression')
        target.add_node('l1', qual_name='mean_absolute_error',
                        annotation='python/sklearn/mean-absolute-error')
        target.add_node('l2', qual_name='mean_squared_error',
                        annotation='python/sklearn/mean-squared-error')
        target.add_edge('read', 'X', sourceport='__return__', targetport='self',
                        annotation='python/pandas/data-frame')
        target.add_edge('read', 'y', sourceport='__return__', targetport='self',
                        annotation='python/pandas/data-frame')
        target.add_edge('lm', 'fit', sourceport='self!', targetport='self',
                        annotation='python/sklearn/linear-regression')
        target.add_edge('X', 'fit', sourceport='__return__', targetport='X',
                        annotation='python/pandas/data-frame')
        target.add_edge('y', 'fit', sourceport='__return__', targetport='y',
                        annotation='python/pandas/series')
        target.add_edge('fit', 'predict', sourceport='self!', targetport='self',
                        annotation='python/sklearn/linear-regression')
        target.add_edge('X', 'predict', sourceport='__return__', targetport='X',
                        annotation='python/pandas/data-frame')
        target.add_edge('y', 'l1', sourceport='__return__', targetport='y_true',
                        annotation='python/pandas/series')
        target.add_edge('predict', 'l1', sourceport='__return__', targetport='y_pred',
                        annotation='python/numpy/ndarray')
        target.add_edge('y', 'l2', sourceport='__return__', targetport='y_true',
                        annotation='python/pandas/series')
        target.add_edge('predict', 'l2', sourceport='__return__', targetport='y_pred',
                        annotation='python/numpy/ndarray')
        self.assert_isomorphic(graph, target)
    
    def test_statsmodel_regression(self):
        """ Linear regression on an R dataset using statsmodels.
        """
        graph = self.trace_script("statsmodels_regression")
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('read', qual_name='get_rdataset',
                        annotation='python/statsmodels/get-r-dataset')
        target.add_node('read-get', qual_name='Dataset.__getattribute__',
                        slot='data')
        target.add_node('ols', qual_name='Model.from_formula',
                        annotation='python/statsmodels/ols-from-formula')
        target.add_node('fit', qual_name='RegressionModel.fit',
                        annotation='python/statsmodels/fit')
        target.add_edge('read', 'read-get',
                        sourceport='__return__', targetport='self',
                        annotation='python/statsmodels/dataset')
        target.add_edge('read-get', 'ols',
                        sourceport='__return__', targetport='data',
                        annotation='python/pandas/data-frame')
        target.add_edge('ols', 'fit',
                        sourceport='__return__', targetport='self',
                        annotation='python/statsmodels/ols')
        target.add_edge('read', outputs, sourceport='__return__',
                        annotation='python/statsmodels/dataset')
        target.add_edge('read-get', outputs, sourceport='__return__',
                        annotation='python/pandas/data-frame')
        target.add_edge('ols', outputs, sourceport='__return__',
                        annotation='python/statsmodels/ols')
        target.add_edge('fit', outputs, sourceport='__return__',
                        annotation='python/statsmodels/regression-results-wrapper')
        self.assert_isomorphic(graph, target)


if __name__ == '__main__':
    unittest.main()
