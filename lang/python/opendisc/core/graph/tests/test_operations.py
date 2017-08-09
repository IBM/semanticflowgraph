from __future__ import absolute_import

import unittest

import networkx as nx

from .. import operations


class TestGraphOperations(unittest.TestCase):
    """ Test operations on networkx graphs.
    """
    
    def test_collapse_undirected(self):
        """ Test that a subgraph of an undirected graph can be collapsed.
        """
        g = nx.Graph()
        g.add_cycle([1,2,3])
        g.add_edges_from([(1,4),(4,5),(2,6)])
        actual = operations.collapse_subgraph(g, [1,2,3], 0)
        target = nx.Graph()
        target.add_edges_from([(0,4),(4,5),(0,6)])
        self.assertEqual(actual.edge, target.edge)
    
    def test_collapse_directed(self):
        """ Test that a subgraph of an directed graph can be collapsed.
        """
        g = nx.DiGraph()
        g.add_cycle([1,2,3])
        g.add_edges_from([(4,1),(5,4),(2,6)])
        actual = operations.collapse_subgraph(g, [1,2,3], 0)
        target = nx.DiGraph()
        target.add_edges_from([(4,0),(5,4),(0,6)])
        self.assertEqual(actual.edge, target.edge)
    
    def test_collapse_undirected_multigraph(self):
        """ Test that a subgraph of an undirected multigraph can be collapsed.
        """
        g = nx.MultiGraph()
        g.add_cycle([1,2,3])
        g.add_edges_from([(1,4),(2,4),(2,5)])
        actual = operations.collapse_subgraph(g, [1,2,3], 0)
        target = nx.MultiGraph()
        target.add_edges_from([(0,4),(0,4),(0,5)])
        self.assertEqual(actual.edge, target.edge)
    
    def test_collapse_directed_multigraph(self):
        """ Test that a subgraph of a directed multigraph can be collapsed.
        """
        g = nx.MultiDiGraph()
        g.add_cycle([1,2,3])
        g.add_edges_from([(4,1),(4,2),(2,5)])
        actual = operations.collapse_subgraph(g, [1,2,3], 0)
        target = nx.MultiDiGraph()
        target.add_edges_from([(4,0),(4,0),(0,5)])
        self.assertEqual(actual.edge, target.edge)
    
    def test_insert_after_predecessors(self):
        """ Test that a new node can be inserted b/w a node and its predecessors.
        """
        g = nx.DiGraph()
        g.add_edges_from([(1,2),(2,4),(3,4),(4,5)])
        actual = operations.insert_after_predecessors(g, 4, 0)
        target = nx.DiGraph()
        target.add_edges_from([(1,2),(2,0),(3,0),(0,4),(4,5)])
        self.assertEqual(actual.edge, target.edge)
    
    def test_insert_before_successors(self):
        """ Test that a new node can be inserted b/w a node and its successors.
        """
        g = nx.DiGraph()
        g.add_edges_from([(1,2),(2,3),(2,4)])
        actual = operations.insert_before_successors(g, 2, 0)
        target = nx.DiGraph()
        target.add_edges_from([(1,2),(2,0),(0,3),(0,4)])
        self.assertEqual(actual.edge, target.edge)
        

if __name__ == '__main__':
    unittest.main()
