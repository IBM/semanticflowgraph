""" Generic algorithms on networkx graphs.
"""
from __future__ import absolute_import

from collections import deque
from itertools import chain

import networkx as nx


def bfs(graph, source, data=False, keys=False, undirected=False, reverse=False,
        visit_node=None, visit_edge=None):
    """ Breadth-first search of graph.
    
    This function generalizes the NetworkX functions `bfs_edges`, 
    `bfs_predecessors`, `bfs_successors` in `networkx.algorithsm.traversal`.
    
    Each node and edge is visited at most once. Note that undirected edges are
    treated as two parallel directed edges, i.e., an undirected edge {a,b}
    will be visited as (a,b) and (b,a).
    
    Parameters
    ----------
    graph : NetworkX graph
    
    source : node
        Start the search at this node.
    
    data : bool, optional
        Whether to include node and edge data in visit callbacks.
    
    keys : bool, optional
        Whether to include edge key as argument for `visit_edge`.
        Only applicable to multigraphs.
    
    undirected : bool, optional
        Whether to ignore edge directionality.
        Only applicatble to directed graphs.
    
    reverse : bool, optional
        Whether to traverse edges in reverse direction.
        Only applicable to directed graphs.
    
    visit_node : callable: node -> bool, optional
        Called for each visited node. Returns whether to visit the node's edges.
    
    visit_edge : callable: src, tgt, [key] -> bool, optional
        Called for each visited edge. Returns whether to visit the target node.
    """
    def do_visit_node(node):
        if visit_node is not None:
            args = (node, graph.node[node]) if data else (node,)
            return visit_node(*args)
        return True
    
    def do_visit_edge(edge):
        if visit_edge is not None:
            return visit_edge(*edge)
        return True
    
    if graph.is_directed():
        if undirected:
            def edge_iter(node, **kwargs):
                return chain(
                    graph.in_edges_iter(node, **kwargs),
                    graph.out_edges_iter(node, **kwargs),
                )
        elif reverse:
            edge_iter = graph.in_edges_iter
        else:
            edge_iter = graph.out_edges_iter
    else:
        edge_iter = graph.edges_iter
    def edges(node):
        if graph.is_multigraph():
            return edge_iter(node, data=data, keys=keys)
        else:
            return edge_iter(node, data=data)
    
    visited = set([ source ])
    queue = deque([ source ])
    while queue:
        node = queue.popleft()
        if do_visit_node(node):
            for edge in edges(node):
                child = edge[0] if edge[1] == node else edge[1]
                if do_visit_edge(edge) and child not in visited:
                    visited.add(child)
                    queue.append(child)
