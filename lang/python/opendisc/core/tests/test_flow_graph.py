from __future__ import absolute_import

from pathlib2 import Path
import unittest

import networkx as nx
import networkx.algorithms.isomorphism as iso

from ..annotation_db import AnnotationDB
from ..flow_graph import flatten, join
from ..flow_graph_builder import FlowGraphBuilder
from ..graph.util import find_node
from ...kernel.trace.tracer import Tracer
from . import objects


class TestFlowGraph(unittest.TestCase):
    """ Tests for Python flow graph machinery.
    """
    
    def assert_isomorphic(self, g1, g2, check_id=True):
        """ Assert that two flow graphs are isomorphic.
        """
        if check_id:
            edge_attrs = [ 'id', 'sourceport', 'targetport' ]
        else:
            edge_attrs = [ 'sourceport', 'targetport' ]
        edge_defaults = [ None ] * len(edge_attrs)
        
        node_match = iso.categorical_node_match('qual_name', None)
        edge_match = iso.categorical_multiedge_match(edge_attrs, edge_defaults)
        self.assertTrue(nx.is_isomorphic(
            g1, g2, node_match=node_match, edge_match=edge_match))

    def setUp(self):
        """ Create the tracer and flow graph builder.
        """
        json_path = Path(objects.__file__).parent.joinpath('data', 'opendisc.json')
        db = AnnotationDB()
        db.load_file(str(json_path))
        
        self.builder = FlowGraphBuilder()
        self.builder.annotator.db = db
        self.tracer = Tracer()
        self.tracer.modules = [ 'opendisc.core.tests.test_flow_graph' ]
        self.id = self.tracer.object_tracker.get_id # For convenience
        
        def handler(changed):
            event = changed['new']
            if event:
                self.builder.push_event(event)
        self.tracer.observe(handler, 'event')
    
    def test_two_object_flow(self):
        """ Check a simple, two-object flow.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
        
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='bar_from_foo')
        target.add_edge(1, 2, id=self.id(foo),
                        sourceport='self', targetport='foo')
        self.assert_isomorphic(actual, target)
    
    def test_three_object_flow(self):
        """ Check a simple, three-object flow.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
            baz = objects.baz_from_bar(bar)
        
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='bar_from_foo')
        target.add_node(3, qual_name='baz_from_bar')
        target.add_edge(1, 2, id=self.id(foo),
                        sourceport='self', targetport='foo')
        target.add_edge(2, 3, id=self.id(bar),
                        sourceport='__return__', targetport='bar')
        self.assert_isomorphic(actual, target)
    
    def test_nonpure_flow(self):
        """ Test that pure and non-pure functions are handled differently.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo_mutating(foo)
            baz = objects.baz_from_foo(foo)
        
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='bar_from_foo_mutating')
        target.add_node(3, qual_name='baz_from_foo')
        target.add_edge(1, 2, id=self.id(foo),
                        sourceport='self', targetport='foo')
        target.add_edge(2, 3, id=self.id(foo),
                        sourceport='foo', targetport='foo')
        self.assert_isomorphic(actual, target)
    
    def test_pure_flow(self):
        """ Test that pure and non-pure functions are handled differently.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
            baz = objects.baz_from_foo(foo)
        
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='bar_from_foo')
        target.add_node(3, qual_name='baz_from_foo')
        target.add_edge(1, 2, id=self.id(foo),
                        sourceport='self', targetport='foo')
        target.add_edge(1, 3, id=self.id(foo),
                        sourceport='self', targetport='foo')
        self.assert_isomorphic(actual, target)
    
    def test_singly_nested(self):
        """ Test that nested function calls are mapped to a nested subgraph.
        """
        with self.tracer:
            bar = outer_bar()
        
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='outer_bar')
        self.assert_isomorphic(actual, target)
        
        node = find_node(actual, lambda n: n['qual_name'] == 'outer_bar')
        actual_sub = actual.node[node]['graph']
        target_sub = nx.MultiDiGraph()
        target_sub.add_node(1, qual_name='Foo.__init__')
        target_sub.add_node(2, qual_name='bar_from_foo')
        target_sub.add_edge(1, 2, sourceport='self', targetport='foo')
        self.assert_isomorphic(actual_sub, target_sub, check_id=False)
    
    def test_flatten_singly_nested(self):
        """ Test that a singly nested function call can be flattened.
        """
        with self.tracer:
            bar = outer_bar()
        
        actual = flatten(self.builder.graph)
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='bar_from_foo')
        target.add_edge(1, 2, sourceport='self', targetport='foo')
        self.assert_isomorphic(actual, target, check_id=False)
    
    def test_doubly_nested(self):
        """ Test that doubly nested function calls are handled.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = outer_bar_from_foo(foo)
            
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='outer_bar_from_foo')
        target.add_edge(1, 2, id=self.id(foo),
                        sourceport='self', targetport='foo')
        self.assert_isomorphic(actual, target)
        
        node = find_node(actual, lambda n: n['qual_name'] == 'outer_bar_from_foo')
        actual_sub1 = actual.node[node]['graph']
        target_sub1 = nx.MultiDiGraph()
        target_sub1.add_node(1, qual_name='inner_bar_from_foo')
        self.assert_isomorphic(actual_sub1, target_sub1)
        
        node = find_node(actual_sub1, lambda n: n['qual_name'] == 'inner_bar_from_foo')
        actual_sub2 = actual_sub1.node[node]['graph']
        target_sub2 = nx.MultiDiGraph()
        target_sub2.add_node(1, qual_name='bar_from_foo')
        self.assert_isomorphic(actual_sub2, target_sub2)
    
    def test_flatten_doubly_nested(self):
        """ Test that doubly nested function calls can be flattened.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = outer_bar_from_foo(foo)
            
        actual = flatten(self.builder.graph)
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='bar_from_foo')
        target.add_edge(1, 2, id=self.id(foo),
                        sourceport='self', targetport='foo')
        self.assert_isomorphic(actual, target)
        
        source, sink = actual.graph['source'], actual.graph['sink']
        self.assertEqual(source, {})
        node = find_node(actual, lambda n: n['qual_name'] == 'Foo.__init__')
        self.assertEqual(sink[self.id(foo)], (node, 'self'))
        node = find_node(actual, lambda n: n['qual_name'] == 'bar_from_foo')
        self.assertEqual(sink[self.id(bar)], (node, '__return__'))
    
    def test_higher_order_function(self):
        """ Test that higher-order functions using user-defined functions work.
        """
        with self.tracer:
            foo = objects.Foo()
            foo.apply(lambda x: objects.Bar(x))
        
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='Foo.__getattribute__')
        target.add_node(3, qual_name='Foo.apply')
        target.add_edge(1, 2, id=self.id(foo),
                        sourceport='self', targetport='self')
        target.add_edge(1, 3, id=self.id(foo),
                        sourceport='self', targetport='self')
        self.assert_isomorphic(actual, target)
    
    def test_tracked_inside_list(self):
        """ Test a function call with tracked objects inside a list.
        """
        with self.tracer:
            foo1 = objects.Foo()
            foo2 = objects.Foo()
            foos = [foo1, foo2]
            objects.foo_x_sum(foos)
        
        actual = self.builder.graph
        target = nx.MultiDiGraph()
        target.add_node(1, qual_name='Foo.__init__')
        target.add_node(2, qual_name='Foo.__init__')
        target.add_node(3, qual_name='foo_x_sum')
        target.add_edge(1, 3, id=self.id(foo1),
                        sourceport='self', targetport='foos')
        target.add_edge(2, 3, id=self.id(foo2),
                        sourceport='self', targetport='foos')
        self.assert_isomorphic(actual, target)
    
    def test_function_annotations(self):
        """ Test that function annotations are stored.
        """
        with self.tracer:
            foo = objects.create_foo()
            bar = objects.bar_from_foo(foo)
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n['qual_name'] == 'create_foo')
        note = graph.node[node]['annotation']
        self.assertEqual(note, 'python/opendisc/create-foo')
        
        node = find_node(graph, lambda n: n['qual_name'] == 'bar_from_foo')
        note = graph.node[node]['annotation']
        self.assertEqual(note, 'python/opendisc/bar-from-foo')
    
    def test_object_annotations(self):
        """ Test that object annotations are stored.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
        
        graph = self.builder.graph
        object_notes = graph.graph['object_annotations']
        self.assertEqual(object_notes[self.id(foo)], 'python/opendisc/foo')
        self.assertEqual(object_notes[self.id(bar)], 'python/opendisc/bar')
    
    def test_input_data(self):
        """ Test that data for input objects is stored.
        """
        with self.tracer:
            foo = objects.create_foo()
            bar = objects.bar_from_foo(foo, 10)
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n['qual_name'] == 'bar_from_foo')
        actual = graph.node[node]['inputs']
        desired = {
            'input': {
                'id': self.id(foo),
                'annotation': 'python/opendisc/foo',
                'slots': {
                    'x': {'value': 1},
                    'y': {'value': 1},
                    'sum': {'value': 2},
                },
            },
            'x': {'value': 10},
            'y': {},
        }
        self.assertEqual(actual, desired)
    
    def test_input_data_varargs(self):
        """ Test that *args and **kwds inputs are stored.
        """
        with self.tracer:
            objects.sum_varargs(1,2,3,w=4)
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n['qual_name'] == 'sum_varargs')
        actual = graph.node[node]['inputs']
        desired = {
            'x': {'value': 1},
            'y': {'value': 2},
            'z': {'value': 3},
            'w': {'value': 4},
        }
        self.assertEqual(actual, desired)
    
    def test_output_data(self):
        """ Test that data for output objects is stored.
        """
        with self.tracer:
            foo = objects.create_foo()
            x = foo.do_sum()
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n['qual_name'] == 'Foo.do_sum')
        actual = graph.node[node]['outputs']
        desired = {
            'sum': {'value': x},
        }
        self.assertEqual(actual, desired)
        
        node = find_node(graph, lambda n: n['qual_name'] == 'create_foo')
        actual = graph.node[node]['outputs']
        desired = {
            'created-foo': {
                'id': self.id(foo),
                'annotation': 'python/opendisc/foo',
                'slots': {
                    'x': {'value': 1},
                    'y': {'value': 1},
                    'sum': {'value': 2},
                },
            },
        }
        self.assertEqual(actual, desired)
    
    def test_two_join_three_object_flow(self):
        """ Test join of simple, three-object captured in two stages.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
            baz = objects.baz_from_bar(bar)
        full = self.builder.graph
    
        self.builder.reset()
        with self.tracer:
            foo = objects.Foo()
        first = self.builder.graph
        
        self.builder.reset()
        with self.tracer:
            bar = objects.bar_from_foo(foo)
            baz = objects.baz_from_bar(bar)
        second = self.builder.graph
        
        joined = join(first, second)
        self.assert_isomorphic(joined, full, check_id=False)
    
    def test_three_join_three_object_flow(self):
        """ Test join of simple, three-object captured in three stages.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
            baz = objects.baz_from_bar(bar)
        full = self.builder.graph
    
        self.builder.reset()
        with self.tracer:
            foo = objects.Foo()
        first = self.builder.graph
        
        self.builder.reset()
        with self.tracer:
            bar = objects.bar_from_foo(foo)
        second = self.builder.graph
        
        self.builder.reset()
        with self.tracer:
            baz = objects.baz_from_bar(bar)
        third = self.builder.graph
        
        joined = join(join(first, second), third)
        self.assert_isomorphic(joined, full, check_id=False)
        
        joined = join(first, join(second, third))
        self.assert_isomorphic(joined, full, check_id=False)


# Test data

def outer_bar_from_foo(foo):
    return inner_bar_from_foo(foo)
    
def inner_bar_from_foo(foo):
    return objects.bar_from_foo(foo)

def outer_bar():
    foo = objects.Foo()
    return objects.bar_from_foo(foo)


if __name__ == '__main__':
    unittest.main()
