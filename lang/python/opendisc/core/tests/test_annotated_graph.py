from __future__ import absolute_import

import unittest

import networkx as nx
import networkx.algorithms.isomorphism as iso

from ..annotated_graph import AnnotatedGraphBuilder


class TestAnnotatedGraph(unittest.TestCase):
    """ Some basic unit tests for creating annotated graphs.
    
    These tests are tedious to write, so there are not too many.
    More comprehensive testing is provided by the package integration tests.
    """
    
    @classmethod
    def setUpClass(cls):
        """ Create annotated graph builder.
        """
        cls.builder = AnnotatedGraphBuilder()

    def assert_isomorphic(self, g1, g2):
        """ Assert that two annotated flow graphs are isomorphic.
        """
        attr = [ 'label', 'kind', 'collapsed' ]
        defaults = [ '', None, False ]
        node_match = iso.categorical_node_match(attr, defaults)
        
        attr = [ 'port' ]
        defaults = [ None ]
        edge_match = iso.categorical_multiedge_match(attr, defaults)
        
        is_iso = nx.is_isomorphic(g1, g2, node_match=node_match, 
                                  edge_match=edge_match)
        self.assertTrue(is_iso)
    
    def test_linear_annotated(self):
        """ Test a fully annotated, linear object flow.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('create_foo', annotation={'id': 'create-foo'})
        concrete.add_node('bar_from_foo', annotation={'id': 'bar-from-foo'})
        concrete.add_edge('create_foo', 'bar_from_foo', id=1)
        concrete.graph['object_annotations'] = {
            1: {'id': 'foo'},
            2: {'id': 'bar'},
        }
        concrete.graph['sink'] = {
            2: 'bar_from_foo',
        }
        
        graph = nx.MultiDiGraph()
        graph.add_node('create_foo', label='create-foo', kind='action')
        graph.add_node('foo', label='foo', kind='entity')
        graph.add_node('bar_from_foo', label='bar-from-foo', kind='action')
        graph.add_node('bar', label='bar', kind='entity')
        graph.add_path(['create_foo', 'foo', 'bar_from_foo', 'bar'])
        self.assert_isomorphic(self.builder.build(concrete), graph)

    def test_linear_fully_annotated(self):
        """ Test a fully annotated (including inputs/outputs) linear flow.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('create_foo',
            annotation = {
                'id': 'create-foo',
            },
            outputs = {
                'created-foo': {
                    'id': 1,
                    'annotation': {
                        'id': 'foo',
                    },
                },
            },
        )
        concrete.add_node('bar_from_foo',
            annotation = {
                'id': 'bar-from-foo',
            },
            inputs = {
                'input': {
                    'id': 1,
                    'annotation': {
                        'id': 'foo',
                    },
                },
            },
            outputs = {
                'output': {
                    'id': 2,
                    'annotation': {
                        'id': 'bar',
                    },
                },
            },
        )
        concrete.add_edge('create_foo', 'bar_from_foo', id=1)
        
        graph = nx.MultiDiGraph()
        graph.add_node('create_foo', label='create-foo', kind='action')
        graph.add_node('foo', label='foo', kind='entity')
        graph.add_node('bar_from_foo', label='bar-from-foo', kind='action')
        graph.add_node('bar', label='bar', kind='entity')
        
        graph.add_edge('create_foo', 'foo', port='created-foo')
        graph.add_edge('foo', 'bar_from_foo', port='input')
        graph.add_edge('bar_from_foo', 'bar', port='output')
        
        self.assert_isomorphic(self.builder.build(concrete), graph)
    
    def test_linear_dangling_unannotated(self):
        """ Test linear object flow with a dangling unnannotated call.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('create_foo', annotation={'id': 'create-foo'})
        concrete.add_node('unknown_foo')
        concrete.add_edge('create_foo', 'unknown_foo', id=1)
        concrete.graph['object_annotations'] = {
            1: {'id': 'foo'},
        }
        
        graph = nx.MultiDiGraph()
        graph.add_node('create_foo', label='create-foo', kind='action')
        graph.add_node('foo', label='foo', kind='entity')
        graph.add_path(['create_foo', 'foo'])
        self.assert_isomorphic(self.builder.build(concrete), graph)
    
    def test_linear_collapse_unannotated(self):
        """ Test linear object flow with multiple unannotated calls.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('create_foo', annotation={'id': 'create-foo'})
        concrete.add_node('unknown_foo')
        concrete.add_node('unknown_bar')
        concrete.add_node('baz_from_bar', annotation={'id': 'baz-from-bar'})
        
        concrete.add_edge('create_foo', 'unknown_foo', id=1)
        concrete.add_edge('unknown_foo', 'unknown_bar', id=2)
        concrete.add_edge('unknown_bar', 'baz_from_bar', id=3)
        concrete.graph['object_annotations'] = {
            1: {'id': 'foo'},
            2: {'id': 'foo'},
            3: {'id': 'bar'},
            4: {'id': 'baz'},
        }
        concrete.graph['sink'] = {
            4: 'baz_from_bar',
        }
        
        graph = nx.MultiDiGraph()
        graph.add_node('create_foo', label='create-foo', kind='action')
        graph.add_node('foo', label='foo', kind='entity')
        graph.add_node('collapsed', kind='action', collapsed=True)
        graph.add_node('bar', label='bar', kind='entity')
        graph.add_node('baz_from_bar', label='baz-from-bar', kind='action')
        graph.add_node('baz', label='baz', kind='entity')
        graph.add_path(['create_foo', 'foo', 'collapsed', 'bar',
                        'baz_from_bar', 'baz'])
        self.assert_isomorphic(self.builder.build(concrete), graph)
    
    def test_multipath_no_collapse(self):
        """ Test flow with two paths: one annonated and one unannotated.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('unknown_foo')
        concrete.add_node('bar_from_foo', annotation={'id': 'bar-from-foo'})
        concrete.add_node('unknown_foo_bar')
        concrete.add_edge('unknown_foo', 'bar_from_foo', id=1)
        concrete.add_edge('unknown_foo', 'unknown_foo_bar', id=1)
        concrete.add_edge('bar_from_foo', 'unknown_foo_bar', id=2)
        concrete.graph['object_annotations'] = {
            1: {'id': 'foo'},
            2: {'id': 'bar'},
        }
        
        graph = nx.MultiDiGraph()
        graph.add_node('foo', label='foo', kind='entity')
        graph.add_node('bar_from_foo', label='bar-from-foo', kind='action')
        graph.add_node('bar', label='bar', kind='entity')
        graph.add_path(['foo', 'bar_from_foo', 'bar'])
        self.assert_isomorphic(self.builder.build(concrete), graph)
    
    def test_multipath_no_collapse_v2(self):
        """ Test longer flow with two paths: one annonated and one unannotated.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('unknown_foo_1')
        concrete.add_node('unknown_foo_2')
        concrete.add_node('bar_from_foo', annotation={'id': 'bar-from-foo'})
        concrete.add_node('unknown_bar')
        concrete.add_node('unknown_foo_bar')
        concrete.add_edge('unknown_foo_1', 'unknown_foo_2', id=1)
        concrete.add_edge('unknown_foo_2', 'bar_from_foo', id=2)
        concrete.add_edge('bar_from_foo', 'unknown_bar', id=3)
        concrete.add_edge('unknown_foo_1', 'unknown_foo_bar', id=1)
        concrete.add_edge('unknown_bar', 'unknown_foo_bar', id=4)
        concrete.graph['object_annotations'] = {
            1: {'id': 'foo'},
            2: {'id': 'foo'},
            3: {'id': 'bar'},
            4: {'id': 'bar'},
        }
        
        graph = nx.MultiDiGraph()
        graph.add_node('foo2', label='foo', kind='entity')
        graph.add_node('bar_from_foo', label='bar-from-foo', kind='action')
        graph.add_node('bar', label='bar', kind='entity')
        graph.add_path(['foo2', 'bar_from_foo', 'bar'])
        actual = self.builder.build(concrete)
        self.assert_isomorphic(self.builder.build(concrete), graph)
    
    def test_unannotated_mutation(self):
        """ Test flow graph that mutates an object.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('create_foo', annotation={'id': 'create-foo'})
        concrete.add_node('get_foo_attr')
        concrete.add_edge('create_foo', 'get_foo_attr', id=1)
        concrete.add_node('mutate_foo')
        concrete.add_edge('create_foo', 'mutate_foo', id=1)
        concrete.add_node('bar_from_foo', annotation={'id': 'bar-from-foo'})
        concrete.add_edge('mutate_foo', 'bar_from_foo', id=1)
        concrete.graph['object_annotations'] = {
            1: {'id': 'foo'},
            2: {'id': 'foo_attr'},
            3: {'id': 'bar'},
        }
        concrete.graph['sink'] = {
            1: 'mutate_foo',
            2: 'get_foo_attr',
            3: 'bar_from_foo',
        }
        
        graph = nx.MultiDiGraph()
        graph.add_node('create_foo', label='create-foo', kind='action')
        graph.add_node('foo1', label='foo', kind='entity')
        graph.add_node('mutate_foo', kind='action')
        graph.add_node('foo2', label='foo', kind='entity')
        graph.add_node('bar_from_foo', label='bar-from-foo', kind='action')
        graph.add_node('bar', label='bar', kind='entity')
        graph.add_path(['create_foo', 'foo1', 'mutate_foo', 'foo2', 
                        'bar_from_foo', 'bar'])
        self.assert_isomorphic(self.builder.build(concrete), graph)
    
    def test_unannotated_mutation_v2(self):
        """ Test another flow graph that mutates an object.
        """
        concrete = nx.MultiDiGraph()
        concrete.add_node('create_foo', annotation={'id': 'create-foo'})
        concrete.add_node('get_foo_attr')
        concrete.add_edge('create_foo', 'get_foo_attr', id=1)
        concrete.add_node('mutate_foo', annotation={'id': 'mutate-foo'})
        concrete.add_edge('create_foo', 'mutate_foo', id=1)
        concrete.add_node('unknown_foo')
        concrete.add_edge('mutate_foo', 'unknown_foo', id=1)
        concrete.add_edge('get_foo_attr', 'unknown_foo', id=2)
        concrete.graph['object_annotations'] = {
            1: {'id': 'foo'},
            2: {'id': 'foo_attr'},
        }
        concrete.graph['sink'] = {
            1: 'mutate_foo',
            2: 'get_foo_attr',
        }
        
        graph = nx.MultiDiGraph()
        graph.add_node('create_foo', label='create-foo', kind='action')
        graph.add_node('foo1', label='foo', kind='entity')
        graph.add_node('mutate_foo', label='mutate-foo', kind='action')
        graph.add_node('foo2', label='foo', kind='entity')
        graph.add_path(['create_foo', 'foo1', 'mutate_foo', 'foo2'])
        self.assert_isomorphic(self.builder.build(concrete), graph)


if __name__ == '__main__':
    unittest.main()
