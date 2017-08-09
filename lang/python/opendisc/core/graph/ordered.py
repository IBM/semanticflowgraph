""" Ordered networkx graphs.
"""
from __future__ import absolute_import

from collections import OrderedDict
from contextlib import contextmanager

import networkx as nx


class OrderedGraph(nx.Graph):
    """ An ordered Graph.
    """
    node_dict_factory = OrderedDict
    adjlist_dict_factory = OrderedDict

class OrderedDiGraph(nx.DiGraph):
    """ An ordered DiGraph.
    """
    node_dict_factory = OrderedDict
    adjlist_dict_factory = OrderedDict

class OrderedMultiGraph(nx.MultiGraph):
    """ An ordered MultiGraph.
    """
    node_dict_factory = OrderedDict
    adjlist_dict_factory = OrderedDict
    edge_key_dict_factory = OrderedDict

class OrderedMultiDiGraph(nx.MultiDiGraph):
    """ An ordered MultiDiGraph.
    """
    node_dict_factory = OrderedDict
    adjlist_dict_factory = OrderedDict
    edge_key_dict_factory = OrderedDict


@contextmanager
def ordered_graphs():
    """ When enabled, all created networkx graphs will have ordered semantics.
    
    This context manager should be considered a hack, but it can be useful.
    """
    import networkx
    
    replace = {
        'Graph': OrderedGraph,
        'DiGraph': OrderedDiGraph,
        'MultiGraph': OrderedMultiGraph,
        'MultiDiGraph': OrderedMultiDiGraph,
    }
    original = { name: getattr(networkx, name) for name in replace.keys() }
    
    for name, value in replace.items():
        setattr(networkx, name, value)
    yield
    for name, value in original.items():
        setattr(networkx, name, value)
