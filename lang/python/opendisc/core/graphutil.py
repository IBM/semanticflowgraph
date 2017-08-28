""" Miscellaneous utility functions for NetworkX graphs.
"""
from __future__ import absolute_import

import itertools
import uuid


def find_node(graph, query, **kwargs):
    """ Find a single node matching the data query.
    
    Returns a matching node or None.
    """
    return next(find_nodes(graph, query, **kwargs), None)

def find_nodes(graph, query, data=False):
    """ Iterator over all nodes matching the data query.
    """
    return ((v, graph.node[v]) if data else v 
            for v in graph if query(graph.node[v]))


def node_name(graph, base=None, sep=None):
    """ Create a name (string ID) for a node.
    
    With overwhelming probability, the (partially random) node name will be
    unique not just in the given graph, but in all graphs created by networkx.
    """
    name = uuid.uuid4().hex
    if base:
        sep = sep or ':'
        name = base + sep + name
    return name

def deterministic_node_name(graph, base, sep=None):
    """ Create a name for a node.
    
    Unlike `node_name`, this function produces names that are:
        - deterministic
        - unique in the given graph, but not necessarily globally
    """
    sep = sep or ':'
    for i in itertools.count(1):
        name = base + sep + str(i)
        if name not in graph:
            break
    return name
