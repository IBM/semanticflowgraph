""" Build an annotated flow graph from a concrete object flow graph.

A concrete flow graph has nodes representing language-specific function calls
and directed edges representing pointers to objects. (For more details, see the
`flow_graph_builder` module.) Some of these functions and objects will have
annotations, but most will not. The purpose of this class is to transform this
concrete graph into a simplified graph in which most nodes and edges have
annotations.

The annotated flow graph is a bipartite directed acyclic graph (DAG). The two
classes of nodes are *entity* and *action*. A directed edge from an entity to an
action means that the entity is an *input* to the action. Likewise, a directed
edge from an action to an entity means that the entity is an *output* of the
action. Note that entities in the annotated graph may correspond to zero, one or
more concrete objects, and  actions may correspond to zero, one or more function
calls. Alternatively, the annotated graph can be viewed as a directed acyclic
hypergraph, whose nodes are entities and whose hyperedges are actions.
"""
from __future__ import absolute_import

from collections import deque
import uuid

import networkx as nx
from networkx.algorithms.dag import topological_sort, transitive_closure
from traitlets import HasTraits

from .graph.operations import copy_topology, collapse_subgraph
from .graph.util import find_nodes, node_name


class AnnotatedGraphBuilder(HasTraits):
    """ Build an annotated flow graph from a concrete object flow graph.
    """

    def build(self, concrete):
        """ Build an annotated flow graph from a concrete object flow graph.
        
        Main entry point for this class.
        """
        graph = copy_topology(concrete)
        
        self.add_source_sink_actions(concrete, graph)
        self.add_action_data(concrete, graph)
        self.add_edge_data(concrete, graph)
        self.collapse_unannotated_actions(graph)
        self.reify_entities(graph)
        self.remove_dangling_actions(graph)
        self.remove_dangling_entities(graph)
        self.remove_duplicate_edges(graph)

        return graph

    # Graph transformation pipeline
    
    def add_source_sink_actions(self, concrete, graph):
        """ Create special nodes for sources and sinks.
        
        This transformation allows objects associated with edges, sources, and
        sinks to be treated uniformly. By construction, the source and sink
        nodes are dangling unannotated actions, so they are guaranteed to be
        removed later in the pipeline.
        """
        # Add source and sink nodes.
        source_node = node_name(graph, '__source__')
        sink_node = node_name(graph, '__sink__')
        graph.add_nodes_from([source_node, sink_node])
        
        # Add edges between annotated actions and source/sink nodes.
        is_annotated = lambda n: bool(concrete.node[n].get('annotation'))
        for obj_id, nodes in concrete.graph.get('source', {}).items():
            if any(map(is_annotated, nodes)):
                for node in nodes:
                    graph.add_edge(source_node, node, id=obj_id)
        for obj_id, node in concrete.graph.get('sink', {}).items():
            if is_annotated(node):
                graph.add_edge(node, sink_node, id=obj_id)

    def add_action_data(self, concrete, graph):
        """ Copy action data from concrete to annotated graph.
        
        For annotated actions, we ensure that all inputs/outputs (including 
        those with no IDs and those associated with sources/sinks) are reified.
        For unannotated actions, we will reify on an as-needed basis;
        in particular, only inputs/outputs associated with edges are reified.
        """
        # Store object annotations for later use.
        self._object_annotations = concrete.graph.get('object_annotations', {})
        
        # Add annotation and, for annotated calls, inputs and outputs.
        for action, data in graph.nodes_iter(data=True):
            orig_data = concrete.node.get(action, {})
            note = orig_data.get('annotation')
            self.annotate_action(graph, action, {'annotation': note})
            if note:
                data['inputs'] = inputs = {}
                data['outputs'] = outputs = {}
                for name, entity_data in orig_data.get('inputs', {}).items():
                    self.add_entity_to_id_map(inputs, entity_data, name=name)
                for name, entity_data in orig_data.get('outputs', {}).items():
                    self.add_entity_to_id_map(outputs, entity_data, name=name)
    
    def add_edge_data(self, concrete, graph):
        """ Copy edge data from concrete to annotated graph.
        """
        for src, tgt, key, data in concrete.edges_iter(keys=True, data=True):
            graph.edge[src][tgt][key]['id'] = data['id']
    
    def collapse_unannotated_actions(self, graph):
        """ Collapse subgraphs of unannotated actions to single nodes.
        
        TODO: Describe algorithm.
        """
        closure = transitive_closure(graph)
        is_annotated = lambda n: bool(graph.node[n]['annotation'])
        is_unannotated = lambda n: not is_annotated(n)
        
        def annotated_ancestors(node):
            return (n for n in closure.predecessors_iter(node) if is_annotated(n))
            
        def annotated_descendants(node):
            return (n for n in closure.successors_iter(node) if is_annotated(n))
        
        def can_collapse(parent, child):
            return all(closure.has_edge(src, tgt)
                       for tgt in annotated_descendants(parent)
                       for src in annotated_ancestors(child))
            
        def collapse(subgraph, new_node):
            collapse_subgraph(graph, subgraph, new_node)
            collapse_subgraph(closure, subgraph, new_node)
        
        stack = deque(topological_sort(graph))
        while stack:
            parent = stack.pop()
            if parent in graph and is_unannotated(parent):
                child = next((c for c in graph.successors_iter(parent)
                              if is_unannotated(c) and can_collapse(parent, c)),
                              None)
                if child:
                    new_node = node_name(graph, 'collapsed')
                    collapse([parent, child], new_node)
                    self.annotate_action(graph, new_node, {'collapsed': True})
                    stack.append(new_node)

    def reify_entities(self, graph):
        """ Reify inputs and ouputs of action nodes as entity nodes.
        
        We process the actions in topological sort order. This ensures that any
        any inputs to a node have already been reified if they are outputs of
        another node.
        """
        for action in topological_sort(graph):
            assert graph.node[action]['kind'] == 'action' # Sanity check
            self.reify_inputs(graph, action)
            self.reify_outputs(graph, action)

    def reify_inputs(self, graph, action):
        """ Reify inputs of an action node as entity nodes.
        """
        # Add incoming edges to ID map.
        action_data = graph.node[action]
        id_map = action_data.pop('inputs', {})
        for v, _, edge_data in graph.in_edges_iter(action, data=True):
            entity_data = self.add_entity_to_id_map(id_map, edge_data['id'])
            entity_data.setdefault('predecessors', set()).add(v)
        
        # Reify every entity in the ID map that is not already reified.
        for obj_id, entity_data in id_map.items():
            pred = entity_data.pop('predecessors', set())
            if pred:
                # If there is a predecessor, it must be the aleady reified
                # entity. Use it. (Unless the action is collapsed, there cannot
                # be more than one predecessor.)
                assert all(graph.node[n]['kind'] == 'entity' for n in pred)
                if len(pred) == 1:
                    node = pred.pop()
                else:
                    assert action_data['collapsed']
                    node = None
            else:
                # Otherwise, create a new node.
                node = node_name(graph, 'entity')
                graph.add_node(node)
                graph.add_edge(node, action)
            
            # Add ports to edge, if available.
            ports = entity_data.pop('ports', [])
            if node and ports:
                graph.remove_edge(node, action)
                for port in ports:
                    graph.add_edge(node, action, port=port)
            
            # Annotate the entity node if it's not already annotated. We do 
            # this to ensure that an entity which is an output of unannotated 
            # action but an input of annotated action gets its slot data.
            # XXX: We are tacitly assuming that explicitly annotated inputs
            # and outputs have compatible annotations, e.g., in terms of olog
            # type information. If that is violated, the entity will get the 
            # annotation associated with the action that created it as output,
            # not any subsequent actions taking it as input, because the 
            # actions are processed in topological sort order.
            if node and not graph.node[node].get('annotation'):
                self.annotate_entity(graph, node, entity_data)

    def reify_outputs(self, graph, action):
        """ Reify outputs of an action node as entity nodes.
        """
        # Add outgoing edges to ID map.
        action_data = graph.node[action]
        id_map = action_data.pop('outputs', {})
        for _, v, edge_data in graph.out_edges_iter(action, data=True):
            self.add_entity_to_id_map(id_map, edge_data['id'])
        
        # Reify every entity in the ID map.
        for obj_id, entity_data in id_map.items():            
            # Insert a new node and rewire the edges.
            node = node_name(graph, 'entity')
            graph.add_edge(action, node)
            for _, tgt, key, data in graph.out_edges(action, keys=True, data=True):
                if data.get('id') == obj_id:
                    graph.remove_edge(action, tgt, key)
                    graph.add_edge(node, tgt, **data)
            
            # Add ports to edge, if available.
            ports = entity_data.pop('ports', [])
            if ports:
                graph.remove_edge(action, node)
                for port in ports:
                    graph.add_edge(action, node, port=port)
            
            # Annotate the newly created node.
            self.annotate_entity(graph, node, entity_data)

    def remove_dangling_actions(self, graph):
        """ Remove dangling unannotated actions.
        
        A "dangling" node is a node that does not have both predecessors and 
        successors.
        """
        def dangling(n):
            return not (graph.predecessors(n) and graph.successors(n))
        
        def predicate(n):
            return (graph.node[n]['kind'] == 'action' and
                    not graph.node[n]['annotation'] and 
                    dangling(n))

        graph.remove_nodes_from(n for n in graph.nodes() if predicate(n))
    
    def remove_dangling_entities(self, graph):
        """ Remove entities dangling from unannotated actions.

        These can be created by the previous step (removing dangling actions).
        """
        def dangling_predecessor(n):
            return not (graph.predecessors(n) or
                any(graph.node[v]['annotation'] for v in graph.successors(n)))
        
        def dangling_successor(n):
            return not (graph.successors(n) or
                any(graph.node[v]['annotation'] for v in graph.predecessors(n)))
        
        def predicate(n):
            return (graph.node[n]['kind'] == 'entity'
                    and (dangling_predecessor(n) or dangling_successor(n)))
        
        graph.remove_nodes_from(n for n in graph.nodes() if predicate(n))
    
    def remove_duplicate_edges(self, graph):
        """ Remove duplicate edges to/from unannotated actions.
        
        These can be created when unannotated actions are collapsed.
        """
        query = lambda n: n['kind'] == 'action' and not n['annotation']
        for action in list(find_nodes(graph, query)):
            data = graph.node[action]
            pred, succ = graph.predecessors(action), graph.successors(action)
            graph.remove_node(action)
            graph.add_node(action, data)
            graph.add_edges_from((src, action) for src in pred)
            graph.add_edges_from((action, tgt) for tgt in succ)
        
    # Helper methods
    
    def add_entity_to_id_map(self, id_map, id_or_data, name=None):
        """ Add an entity to a map from object IDs to entity data.
        
        This function ensures that there is at most entity for each ID.
        """
        # Unpack object ID and data. If there is no ID, a new one is generated.
        if isinstance(id_or_data, dict):
            data = dict(id_or_data)
            obj_id = data['id'] if 'id' in data else uuid.uuid4().hex
        else:
            obj_id = id_or_data
            data = {
                'id': obj_id, 
                'annotation': self._object_annotations.get(obj_id),
            }
        
        # Add data to ID map if not already present.
        if obj_id in id_map:
            # Prefer existing data.
            # FIXME: Should we check for compatibility of annotations?
            data = id_map[obj_id] 
        else:
            id_map[obj_id] = data
        if name is not None:
            data.setdefault('ports', []).append(name)
        return data
    
    def annotate_action(self, graph, node, attr):
        """ Copy annotations to action node in annotated graph.
        """
        note = attr.pop('annotation', None)
        
        if note and 'id' in note:
            label = note['id']
        else:
            label = ''
        
        data = {
            'annotation': note,
            'kind': 'action',
            'label': label,
        }
        data.update(attr)
        graph.node[node].update(data)

    def annotate_entity(self, graph, node, attr):
        """ Copy annotations to entity node in annotated graph.
        """
        note = attr.pop('annotation', None)
        
        if note and 'id' in note:
            label = note['id']
        elif 'value' in attr:
            label = 'value'
        else:
            label = 'object' if note else ''
        
        data = {
            'annotation': note,
            'kind': 'entity',
            'label': label,
        }
        data.update(attr)
        graph.node[node].update(data)
