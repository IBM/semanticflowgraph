from __future__ import absolute_import

import unittest

import networkx as nx

from ..algorithms import bfs
from ..ordered import OrderedGraph, OrderedDiGraph, OrderedMultiDiGraph


def bfs_record(*args, **kwargs):
    nodes = []
    def visit_node(*args):
        nodes.append(args[0] if len(args) == 1 else args)
        return True
    edges = []
    def visit_edge(*edge):
        edges.append(edge)
        return True
    bfs(*args, visit_node=visit_node, visit_edge=visit_edge, **kwargs)
    return nodes, edges


class TestGraphAlgorithms(unittest.TestCase):
    
    def test_bfs_undirected(self):
        """ Test breadth-first search on undirected graph.
        """
        graph = OrderedGraph()
        graph.add_cycle([1,2,3])
        
        bfs_nodes, bfs_edges = bfs_record(graph, 2)
        self.assertEqual(bfs_nodes, [2,1,3])
        self.assertEqual(bfs_edges, [(2,1),(2,3),(1,2),(1,3),(3,2),(3,1)])
    
    def test_bfs_directed(self):
        """ Test breadth-first search on directed graph.
        """
        nodes = list(range(1,13))
        edges = [(1,2), (1,3), (1,4), (2,5), (2,6), (4,7), (4,8), (5,9), (5,10),
                 (7,11), (7,12)] # From BFS on Wikipedia :)
        graph = OrderedDiGraph()
        graph.add_nodes_from(nodes)
        graph.add_edges_from(edges)
        
        bfs_nodes, bfs_edges = bfs_record(graph, 1)
        self.assertEqual(bfs_nodes, nodes)
        self.assertEqual(bfs_edges, edges)
    
    def test_bfs_directed_data(self):
        """ Test breadth-first search on directed graph with data.
        """
        graph = OrderedDiGraph()
        graph.add_node('foo', kind='f')
        graph.add_node('bar', kind='b')
        graph.add_node('baz', kind='b')
        graph.add_edge('foo', 'bar', port='one')
        graph.add_edge('foo', 'baz', port='two')
        
        bfs_nodes, bfs_edges = bfs_record(graph, 'foo', data=True)
        self.assertEqual(bfs_nodes, graph.nodes(data=True))
        self.assertEqual(bfs_edges, graph.edges(data=True))
    
    def test_bfs_directed_undirected(self):
        """ Test breath-first search of directed graph, ignoring directionality.
        """
        graph = OrderedDiGraph()
        graph.add_path([1,2,3])
        
        bfs_nodes, bfs_edges = bfs_record(graph, 3)
        self.assertEqual(bfs_nodes, [3])
        bfs_nodes, bfs_edges = bfs_record(graph, 3, undirected=True)
        self.assertEqual(bfs_nodes, [3,2,1])
    
    def test_bfs_directed_reversed(self):
        """ Test breadth-first search of directed graph with reversed directions.
        """
        nodes = range(5)
        graph = OrderedDiGraph()
        graph.add_path(nodes)
        
        bfs_nodes, bfs_edges = bfs_record(graph, 4, reverse=True)
        self.assertEqual(bfs_nodes, list(reversed(nodes)))
    
    def test_bfs_directed_multigraph(self):
        """ Test breadth-first search of directed multigraph.
        """
        nodes = [1,2,3]
        edges = [(1,2,0,{}), (1,2,1,{}), (2,3,0,{}), (3,1,0,{})]
        graph = OrderedMultiDiGraph()
        graph.add_nodes_from(nodes)
        graph.add_edges_from(edges)
        edges = [ edge[0:3] for edge in edges ]
        edges_no_key = [ edge[0:2] for edge in edges ]
        
        bfs_nodes, bfs_edges = bfs_record(graph, 1, keys=False)
        self.assertEqual(bfs_nodes, nodes)
        self.assertEqual(bfs_edges, edges_no_key)
        
        bfs_nodes, bfs_edges = bfs_record(graph, 1, keys=True)
        self.assertEqual(bfs_nodes, nodes)
        self.assertEqual(bfs_edges, edges)
        

if __name__ == '__main__':
    unittest.main()
