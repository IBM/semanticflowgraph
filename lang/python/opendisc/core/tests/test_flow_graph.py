from __future__ import absolute_import

from collections import OrderedDict
from pathlib2 import Path
import unittest

import networkx as nx
import networkx.algorithms.isomorphism as iso

from opendisc.trace.tracer import Tracer
from ..annotation_db import AnnotationDB
from ..flow_graph import new_flow_graph, flatten, join
from ..flow_graph_builder import FlowGraphBuilder
from ..graphutil import find_node
from ..graphml import read_graphml_str, write_graphml_str
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
    
    def get_ports(self, graph, node, portkind=None):
        """ Convenience method to get ports from node in flow graph.
        """
        ports = graph.node[node]['ports']
        if portkind is not None:
            ports = OrderedDict((p, data) for p, data in ports.items()
                                if data['portkind'] == portkind)
        return ports

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
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='bar_from_foo')
        target.add_edge('1', '2', id=self.id(foo),
                        sourceport='self!', targetport='foo')
        target.add_edge('1', outputs, id=self.id(foo), sourceport='self!')
        target.add_edge('2', outputs, id=self.id(bar), sourceport='__return__')
        self.assert_isomorphic(actual, target)
    
    def test_two_object_flow_external(self):
        """ Check a simple, two-object flow with input from external object.
        """
        foo = objects.Foo()
        with self.tracer:
            bar = objects.bar_from_foo(foo)
        
        actual = self.builder.graph
        target = new_flow_graph()
        inputs, outputs = target.graph['input_node'], target.graph['output_node']
        target.add_node('1', qual_name='bar_from_foo')
        target.add_edge(inputs, '1', id=self.id(foo), targetport='foo')
        target.add_edge('1', outputs, id=self.id(bar), sourceport='__return__')
        self.assert_isomorphic(actual, target)
    
    def test_three_object_flow(self):
        """ Check a simple, three-object flow.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
            baz = objects.baz_from_bar(bar)
        
        actual = self.builder.graph
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='bar_from_foo')
        target.add_node('3', qual_name='baz_from_bar')
        target.add_edge('1', '2', id=self.id(foo),
                        sourceport='self!', targetport='foo')
        target.add_edge('2', '3', id=self.id(bar),
                        sourceport='__return__', targetport='bar')
        target.add_edge('1', outputs, id=self.id(foo), sourceport='self!')
        target.add_edge('2', outputs, id=self.id(bar), sourceport='__return__')
        target.add_edge('3', outputs, id=self.id(baz), sourceport='__return__')
        self.assert_isomorphic(actual, target)
    
    def test_nonpure_flow(self):
        """ Test that pure and non-pure functions are handled differently.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo_mutating(foo)
            baz = objects.baz_from_foo(foo)
        
        actual = self.builder.graph
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='bar_from_foo_mutating')
        target.add_node('3', qual_name='baz_from_foo')
        target.add_edge('1', '2', id=self.id(foo),
                        sourceport='self!', targetport='foo')
        target.add_edge('2', '3', id=self.id(foo),
                        sourceport='foo!', targetport='foo')
        target.add_edge('2', outputs, id=self.id(foo), sourceport='foo!')
        target.add_edge('2', outputs, id=self.id(bar), sourceport='__return__')
        target.add_edge('3', outputs, id=self.id(baz), sourceport='__return__')
        self.assert_isomorphic(actual, target)
    
    def test_pure_flow(self):
        """ Test that pure and non-pure functions are handled differently.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
            baz = objects.baz_from_foo(foo)
        
        actual = self.builder.graph
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='bar_from_foo')
        target.add_node('3', qual_name='baz_from_foo')
        target.add_edge('1', '2', id=self.id(foo),
                        sourceport='self!', targetport='foo')
        target.add_edge('1', '3', id=self.id(foo),
                        sourceport='self!', targetport='foo')
        target.add_edge('1', outputs, id=self.id(foo), sourceport='self!')
        target.add_edge('2', outputs, id=self.id(bar), sourceport='__return__')
        target.add_edge('3', outputs, id=self.id(baz), sourceport='__return__')
        self.assert_isomorphic(actual, target)
    
    def test_singly_nested(self):
        """ Test that nested function calls are mapped to a nested subgraph.
        """
        with self.tracer:
            bar = outer_bar()
        
        actual = self.builder.graph
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='outer_bar')
        target.add_edge('1', outputs, id=self.id(bar), sourceport='__return__')
        self.assert_isomorphic(actual, target)
        
        node = find_node(actual, lambda n: n.get('qual_name') == 'outer_bar')
        actual_sub = actual.node[node]['graph']
        target_sub = new_flow_graph()
        outputs = target_sub.graph['output_node']
        target_sub.add_node('1', qual_name='Foo.__init__')
        target_sub.add_node('2', qual_name='bar_from_foo')
        target_sub.add_edge('1', '2', sourceport='self!', targetport='foo')
        target_sub.add_edge('1', outputs, sourceport='self!')
        target_sub.add_edge('2', outputs, sourceport='__return__')
        self.assert_isomorphic(actual_sub, target_sub, check_id=False)
    
    def test_flatten_singly_nested(self):
        """ Test that a singly nested function call can be flattened.
        """
        with self.tracer:
            bar = outer_bar()
        
        actual = flatten(self.builder.graph)
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='bar_from_foo')
        target.add_edge('1', '2', sourceport='self!', targetport='foo')
        target.add_edge('2', outputs, sourceport='__return__')
        self.assert_isomorphic(actual, target, check_id=False)
    
    def test_doubly_nested(self):
        """ Test that doubly nested function calls are handled.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = outer_bar_from_foo(foo)
            
        actual = self.builder.graph
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='outer_bar_from_foo')
        target.add_edge('1', '2', id=self.id(foo),
                        sourceport='self!', targetport='foo')
        target.add_edge('1', outputs, id=self.id(foo), sourceport='self!')
        target.add_edge('2', outputs, id=self.id(bar), sourceport='__return__')
        self.assert_isomorphic(actual, target)
        
        node = find_node(actual, lambda n: n.get('qual_name') == 'outer_bar_from_foo')
        actual_sub1 = actual.node[node]['graph']
        target_sub1 = new_flow_graph()
        inputs = target_sub1.graph['input_node']
        outputs = target_sub1.graph['output_node']
        target_sub1.add_node('1', qual_name='inner_bar_from_foo')
        target_sub1.add_edge(inputs, '1', id=self.id(foo), targetport='foo')
        target_sub1.add_edge('1', outputs, id=self.id(bar), sourceport='__return__')
        self.assert_isomorphic(actual_sub1, target_sub1)
        
        node = find_node(actual_sub1, lambda n: n.get('qual_name') == 'inner_bar_from_foo')
        actual_sub2 = actual_sub1.node[node]['graph']
        target_sub2 = new_flow_graph()
        inputs = target_sub2.graph['input_node']
        outputs = target_sub2.graph['output_node']
        target_sub2.add_node('1', qual_name='bar_from_foo')
        target_sub2.add_edge(inputs, '1', id=self.id(foo), targetport='foo')
        target_sub2.add_edge('1', outputs, id=self.id(bar), sourceport='__return__')
        self.assert_isomorphic(actual_sub2, target_sub2)
    
    def test_flatten_doubly_nested(self):
        """ Test that doubly nested function calls can be flattened.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = outer_bar_from_foo(foo)
            
        actual = flatten(self.builder.graph)
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='bar_from_foo')
        target.add_edge('1', '2', id=self.id(foo),
                        sourceport='self!', targetport='foo')
        target.add_edge('1', outputs, id=self.id(foo), sourceport='self!')
        target.add_edge('2', outputs, id=self.id(bar), sourceport='__return__')
        self.assert_isomorphic(actual, target)
    
    def test_higher_order_function(self):
        """ Test that higher-order functions using user-defined functions work.
        """
        with self.tracer:
            foo = objects.Foo()
            foo.apply(lambda x: objects.Bar(x))
        
        actual = self.builder.graph
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='Foo.__getattribute__')
        target.add_node('3', qual_name='Foo.apply')
        target.add_edge('1', '2', id=self.id(foo),
                        sourceport='self!', targetport='self')
        target.add_edge('1', '3', id=self.id(foo),
                        sourceport='self!', targetport='self')
        target.add_edge('1', outputs, id=self.id(foo), sourceport='self!')
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
        target = new_flow_graph()
        outputs = target.graph['output_node']
        target.add_node('1', qual_name='Foo.__init__')
        target.add_node('2', qual_name='Foo.__init__')
        target.add_node('3', qual_name='foo_x_sum')
        target.add_edge('1', '3', id=self.id(foo1),
                        sourceport='self!', targetport='foos')
        target.add_edge('2', '3', id=self.id(foo2),
                        sourceport='self!', targetport='foos')
        target.add_edge('1', outputs, id=self.id(foo1), sourceport='self!')
        target.add_edge('2', outputs, id=self.id(foo2), sourceport='self!')
        self.assert_isomorphic(actual, target)
    
    def test_function_annotations(self):
        """ Test that function annotations are stored.
        """
        with self.tracer:
            foo = objects.create_foo()
            bar = objects.bar_from_foo(foo)
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n.get('qual_name') == 'create_foo')
        note = graph.node[node]['annotation']
        self.assertEqual(note, 'python/opendisc/create-foo')
        
        node = find_node(graph, lambda n: n.get('qual_name') == 'bar_from_foo')
        note = graph.node[node]['annotation']
        self.assertEqual(note, 'python/opendisc/bar-from-foo')
    
    def test_input_ports(self):
        """ Test that data for input ports is stored.
        """
        with self.tracer:
            foo = objects.create_foo()
            bar = objects.bar_from_foo(foo, 10)
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n.get('qual_name') == 'bar_from_foo')
        actual = self.get_ports(graph, node, 'input')
        desired = OrderedDict([
            ('foo', {
                'portkind': 'input',
                'annotation_domain': 1,
                'annotation': 'python/opendisc/foo',
                'id': self.id(foo),
            }),
            ('x', {
                'portkind': 'input',
                'annotation_domain': 2,
                'value': 10,
            }),
            ('y', {
                'annotation_domain': 3,
                'portkind': 'input',
            })
        ])
        self.assertEqual(actual, desired)
    
    def test_input_ports_varargs(self):
        """ Test that varargs and keyword arguments are stored.
        """
        with self.tracer:
            objects.sum_varargs(1,2,3,w=4)
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n.get('qual_name') == 'sum_varargs')
        actual = self.get_ports(graph, node, 'input')
        desired = OrderedDict([
            ('x', {
                'portkind': 'input',
                'value': 1,
            }),
            ('y', {
                'portkind': 'input',
                'value': 2,
            }),
            ('__vararg0__', {
                'portkind': 'input',
                'value': 3,
            }),
            ('w', {
                'portkind': 'input',
                'value': 4,
            })
        ])
        self.assertEqual(actual, desired)
    
    def test_output_data(self):
        """ Test that data for output ports is stored.
        """
        with self.tracer:
            foo = objects.create_foo()
            x = foo.do_sum()
        
        graph = self.builder.graph
        node = find_node(graph, lambda n: n.get('qual_name') == 'Foo.do_sum')
        actual = self.get_ports(graph, node, 'output')
        desired = OrderedDict([
            ('__return__', {
                'portkind': 'output',
                'annotation_domain': 1,
                'value': x,
            })
        ])
        self.assertEqual(actual, desired)
        
        node = find_node(graph, lambda n: n.get('qual_name') == 'create_foo')
        actual = self.get_ports(graph, node, 'output')
        desired = OrderedDict([
            ('__return__', {
                'portkind': 'output',
                'annotation_domain': 1,
                'annotation': 'python/opendisc/foo',
                'id': self.id(foo),
            })
        ])
        self.assertEqual(actual, desired)
    
    def test_output_data_mutating(self):
        """ Test that output ports are created for mutated arguments.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo_mutating(foo)
            
        graph = self.builder.graph
        node = find_node(graph, lambda n: n.get('qual_name') == 'bar_from_foo_mutating')
        actual = self.get_ports(graph, node, 'output')
        desired = OrderedDict([
            ('__return__', {
                'portkind': 'output',
                'annotation_domain': 2,
                'annotation': 'python/opendisc/bar',
                'id': self.id(bar),
            }),
            ('foo!', {
                'portkind': 'output',
                'annotation_domain': 1,
                'annotation': 'python/opendisc/foo',
                'id': self.id(foo),
            }),
        ])
        self.assertEqual(actual, desired)
    
    def test_two_join_three_object_flow(self):
        """ Test join of simple, three-object flow captured in two stages.
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
        """ Test join of simple, three-object flow captured in three stages.
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
    
    def test_two_join_mutation(self):
        """ Test join of two-object flow with mutation of the first object.
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo_mutating(foo)
        full = self.builder.graph
        
        self.builder.reset()
        with self.tracer:
            foo = objects.Foo()
        first = self.builder.graph
        
        self.builder.reset()
        with self.tracer:
            bar = objects.bar_from_foo_mutating(foo)
        second = self.builder.graph
    
        joined = join(first, second)
        self.assert_isomorphic(joined, full, check_id=False)
    
    def test_graphml_serialization(self):
        """ Can a flow graph be roundtripped through GraphML?
        """
        with self.tracer:
            foo = objects.Foo()
            bar = objects.bar_from_foo(foo)
        graph = self.builder.graph
        
        xml = write_graphml_str(graph)
        roundtripped = read_graphml_str(xml, multigraph=True)
        roundtripped.graph.pop('node_default', None)
        roundtripped.graph.pop('edge_default', None)
        self.assertEqual(graph.graph, roundtripped.graph)
        self.assertEqual(graph.node, roundtripped.node)
        self.assertEqual(graph.edge, roundtripped.edge)


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
