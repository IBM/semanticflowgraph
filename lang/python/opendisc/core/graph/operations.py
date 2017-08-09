""" Generic operations and transformations on networkx graphs.
"""
from __future__ import absolute_import

import networkx as nx


def copy_topology(source, target=None):
    """ Copy the topology of a graph.
    
    Unlike the standard networkx copy methods, this function does not copy
    graph data attributes.
    """
    if target is None:
        target = type(source)()
    
    target.add_nodes_from(source)
    if source.is_multigraph() and target.is_multigraph():
        for edge in source.edges_iter(keys=True):
            target.add_edge(*edge)
    else:
        target.add_edges_from(source.edges_iter())
    return target


def collapse_subgraph(graph, subgraph, new_node):
    """ Collapse a subgraph of a graph to a single node.
    
    The graph may be directed or undirected. It is operated on in-place.
    Edges to/from the subgraph will be re-routed to/from the new node.
    """
    if new_node in graph:
        raise ValueError("New node already exists in graph")
    graph.add_node(new_node)
    
    if graph.is_directed():
        for u, v, data in graph.in_edges_iter(subgraph, data=True):
            if u not in subgraph:
                graph.add_edge(u, new_node, **data)
        for u, v, data in graph.out_edges_iter(subgraph, data=True):
            if v not in subgraph:
                graph.add_edge(new_node, v, **data)
    else:
        for u, v, data in graph.edges_iter(subgraph, data=True):
            if u not in subgraph and v in subgraph:
                graph.add_edge(u, new_node, **data)
            if u in subgraph and v not in subgraph:
                graph.add_edge(new_node, v, **data)
    
    graph.remove_nodes_from(subgraph)
    return graph


def insert_after_predecessors(graph, node, new_node, pred=None):
    """ Insert a new node between a node and its predecessors.
    """
    if not graph.is_directed():
        raise TypeError("Input graph must be directed")
    if pred is None:
        pred = graph.predecessors(node)
    elif not all(graph.has_edge(v, node) for v in pred):
        raise ValueError("Nodes are not predecessors")
    
    graph.add_edge(new_node, node)
    for v, _, data in graph.in_edges(node, data=True):
        if v in pred:
            graph.add_edge(v, new_node, **data)
            graph.remove_edge(v, node)
    return graph

def insert_before_successors(graph, node, new_node, succ=None):
    """ Insert a new node between a node and its successors.
    """
    if not graph.is_directed():
        raise TypeError("Input graph must be directed")
    if succ is None:
        succ = graph.successors(node)
    elif not all(graph.has_edge(node, v) for v in succ):
        raise ValueError("Nodes are not successors")
    
    graph.add_edge(node, new_node)
    for _, v, data in graph.out_edges(node, data=True):
        if v in succ:
            graph.add_edge(new_node, v, **data)
            graph.remove_edge(node, v)
    return graph
