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
        edge_attrs = [ 'sourceport', 'targetport' ]
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
            write_graphml(flow_graph_to_graphml(graph), outname)
        
        return graph
    
    def test_sklearn_clustering_kmeans(self):
        """ K-means clustering on the Iris dataset.
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
        target.add_edge('values', 'fit', annotation='python/sklearn/k-means',
                        sourceport='__return__', targetport='X')
        target.add_edge('fit', 'clusters', annotation='python/sklearn/k-means',
                        sourceport='self!', targetport='self')
        self.assert_isomorphic(graph, target)


if __name__ == '__main__':
    unittest.main()
