""" Operations on object flow graphs.

This module contains functions that operate on existing flow graphs. To create 
a new flow graph by tracing Python code, see the `flow_graph_builder` module.

These graphs are sometimes called "concrete" or "raw" flow graphs to
distinguish them from other dataflow graphs in the Open Discovery system.
"""
from __future__ import absolute_import

import networkx as nx
from .graph_util import node_name


def new_flow_graph():
    """ Create a new, empty flow graph.
    """
    graph = nx.MultiDiGraph()
    input_node = node_name(graph, '__in__')
    output_node = node_name(graph, '__out__')
    graph.add_nodes_from((input_node, output_node))
    graph.graph.update({
        'input_node': input_node,
        'output_node': output_node
    })
    return graph


def copy_flow_graph(source_graph, dest_graph):
    """ Copy all nodes and edges from source flow graph to destination flow graph.
    
    Note: The special input and output nodes of the source graph are ignored.
    """
    skip = (source_graph.graph['input_node'], source_graph.graph['output_node'])
    dest_graph.add_nodes_from(
        (node, data) for node, data in source_graph.nodes_iter(data=True)
        if node not in skip)
    dest_graph.add_edges_from(
        edge for edge in source_graph.edges_iter(data=True)
        if edge[0] not in skip and edge[1] not in skip)
    return dest_graph


def flatten(graph, copy=True):
    """ Recursively flatten an object flow graph.
    
    All nested graphs are lifted to the root graph. This means that only 
    "atomic" (not traced) function calls will be preserved.
    """
    if copy:
        graph = graph.copy()
    input_node = graph.graph['input_node']
    output_node = graph.graph['output_node']
    
    for node in graph.nodes():
        subgraph = graph.node[node].get('graph', None)
        if not subgraph:
            continue
        subgraph = flatten(subgraph, copy=False)
        sub_input_node = subgraph.graph['input_node']
        sub_output_node = subgraph.graph['output_node']
        
        # First, add all nodes and edges from the subgraph.
        copy_flow_graph(subgraph, graph)
        
        # Re-wire the input objects of the subgraph.
        for _, tgt, data in subgraph.out_edges_iter(sub_input_node, data=True):
            obj_id, tgt_port = data['id'], data['targetport']
            
            # Try to find an incoming edge in the parent graph carrying the
            # above object. There could be multiple edges carrying the object
            # (if the same object is passed to multiple arguments) but we need
            # only consider one because they should all have the same source.
            for src, _, data in graph.in_edges_iter(node, data=True):
                other_id, src_port = data['id'], data.get('sourceport')
                if obj_id == other_id:
                    graph.add_edge(src, tgt, id=obj_id,
                                   sourceport=src_port, targetport=tgt_port)
                    break
            # If that fails, add a new input object to the parent graph.
            else:
                graph.add_edge(input_node, tgt, id=obj_id, targetport=tgt_port)
        
        # Re-wire the output objects of the subgraph.
        for src, _, data in subgraph.in_edges_iter(sub_output_node, data=True):
            obj_id, src_port = data['id'], data['sourceport']
            
            # Find outgoing edges in the parent graph carrying the above object.
            # If there are none, forget about the output: it cannot be a return
            # value or a mutated argument, hence is lost to the outer scope.
            for _, tgt, data in graph.out_edges_iter(node, data=True):
                other_id, tgt_port = data['id'], data.get('targetport')
                if obj_id == other_id:
                    graph.add_edge(src, tgt, id=obj_id,
                                   sourceport=src_port, targetport=tgt_port)
        
        # Finally, remove the original node (and its edges).
        graph.remove_node(node)
    
    return graph


def join(first, second, copy=True):
    """ Join two object flow graphs that have been captured sequentially.
    """
    # Start with the first graph.
    graph = first.copy() if copy else first
    
    # Build output table. See `FlowGraphBuilder` for motivation.
    input_node = graph.graph['input_node']
    output_node = graph.graph['output_node']
    output_table = { data['id']: (src, key) for src, _, key, data
                     in graph.in_edges_iter(output_node, keys=True, data=True) }
    
    # Add all nodes and edges from the second graph.
    copy_flow_graph(second, graph)

    # Add inputs from the second graph.
    for _, tgt, data in second.out_edges_iter(second.graph['input_node'], data=True):
        obj_id, tgt_port = data['id'], data['targetport']
        # If there is a corresponding output of the first graph, use it.
        if obj_id in output_table:
            src, key = output_table[obj_id]
            src_port = graph.edge[src][output_node][key]['sourceport']
            graph.add_edge(src, tgt, id=obj_id,
                           sourceport=src_port, targetport=tgt_port)
        # Otherwise, add the input to the first graph.
        else:
            graph.add_edge(input_node, tgt, id=obj_id, targetport=tgt_port)
    
    # Add outputs from the second graph, overwriting outputs of the first graph
    # if there is a conflict.
    for src, _, data in second.in_edges_iter(second.graph['output_node'], data=True):
        obj_id, src_port = data['id'], data['sourceport']
        if obj_id in output_table:
            old, key = output_table[obj_id]
            graph.remove_edge(old, output_node, key=key)
        graph.add_edge(src, output_node, id=obj_id, sourceport=src_port)
        
    return graph
