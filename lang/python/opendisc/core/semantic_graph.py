""" Build a semantic flow graph from an annotated flow graph.

This module transforms an annotated flow graph, which is language- and
library-specific (see `annotated_graph` module), into a semantic flow graph,
which is universal. The semantic graph derives its semantics from an ontology
log (see `olog` package).

The semantic graph is an instantiation of types defined in the olog.
More formally, in the terminology of category theory, the graph is a *model* of
the olog. This is explained more fully in the module `olog.model_nx`.
"""
from __future__ import absolute_import

import itertools

import networkx as nx
from networkx.algorithms.dag import topological_sort
from traitlets import HasTraits, Instance, Set, default

from .annotation_db import AnnotationDB
from .graph.algorithms import bfs
from .graph.operations import copy_topology
from .graph.util import find_nodes, node_name
from .knowledge_base import load_olog, inherited, most_specific
from .olog.api import Olog, Type, NxModel


class SemanticGraphBuilder(HasTraits):
    """ Build a semantic flow graph from an annotated flow graph.
    """
    
    # Database of annotations.
    # Do not manually load package annotations; they will be loaded on-the-fly.
    db = Instance(AnnotationDB, args=())
    
    # Derive semantics from this ontology log.
    olog = Instance(Olog)
    
    # Private traits.
    _loaded = Set() # Set of loaded (language, package) pairs.
    
    def build(self, annotated_graph):
        """ Build a semantic flow graph from an annotated flow graph.
        
        Main entry point for this class.
        """
        graph = copy_topology(annotated_graph)
        
        self.add_types(annotated_graph, graph)
        self.add_action_aspects(annotated_graph, graph)
        self.fix_action_edge_directions(graph)
        self.validate_action_aspects(graph)
        self.reify_entity_slots(graph)
        self.merge_duplicate_aspects(graph)
        self.merge_unknown_aspects(graph)
        
        return graph
    
    # Graph transformation pipeline
    
    def add_types(self, annotated_graph, graph):
        """ Add olog type information to semantic graph.
        
        Every node in the semantic graph will be assigned a type, even if it
        just 'entity' or 'action'.
        """
        def copy(src, dest, names):
            dest.update({name: src[name] for name in names if name in src })
        
        model = NxModel(olog=self.olog) # FIXME: Integrate this better?
        for node, orig_data in annotated_graph.nodes_iter(data=True):
            data = graph.node[node]
            
            # Determine type for node.
            type_name = self.get_type_name(orig_data)
            if not type_name and 'value' in orig_data:
                py_type = type(orig_data['value'])
                otype = model.python_type_to_olog_type(py_type)
                type_name = otype.name if otype else None
            if not type_name:
                type_name = orig_data['kind']
            data['type'] = type_name
            data['root_type'] = orig_data['kind'] # for convenience
            
            # Copy additional entity data.
            if data['root_type'] == 'entity':
                copy(orig_data, data, ['id','value','slots'])
    
    def add_action_aspects(self, annotated_graph, graph):
        """ Add aspects of action nodes using port data.
        
        These aspects are *provisional*. Compatibility with node types will be
        validated later.
        """
        for src, tgt, key, data in annotated_graph.edges_iter(keys=True, data=True):
            if 'port' in data:
                graph.edge[src][tgt][key]['aspect'] = data['port']
    
    def fix_action_edge_directions(self, graph):
        """ Fix direction of action edges.
        
        All aspects are represented as out-going edges, consistent with the
        meaning of ologs.
        """
        for action in find_nodes(graph, lambda n: n['root_type'] == 'action'):
            for _, _, data in graph.out_edges_iter(action, data=True):
                data.update({
                    'input': False,
                    'output': True,
                })
            for src, tgt, key, data in graph.in_edges(action, keys=True, data=True):
                data.update({
                    'input': True,
                    'output': False,
                })
                graph.remove_edge(src, tgt, key)
                graph.add_edge(tgt, src, **data)
    
    def validate_action_aspects(self, graph):
        """ Ensure that action aspects conform to the olog.
        """
        query = lambda n: n['root_type'] == 'action'
        for action, action_data in find_nodes(graph, query, data=True):
            valid_aspects = self.get_type_aspects(action_data['type'])
            
            for _, _, edge_data in graph.out_edges_iter(action, data=True):
                # FIXME: Validate codomain type also?
                aspect = edge_data.get('aspect')
                if aspect and aspect not in valid_aspects:
                    del edge_data['aspect']
    
    def reify_entity_slots(self, graph):
        """ Reify slots of entities as aspects.
        
        In concrete terms, this method turns slots of entity nodes into child
        entity nodes.
        """
        # FIXME: Should the reification be recursive?
        query = lambda n: n['root_type'] == 'entity'
        for entity, entity_data in list(find_nodes(graph, query, data=True)):
            valid_aspects = self.get_type_aspects(entity_data['type'])
            
            slots = entity_data.pop('slots', {})
            for name, slot_data in slots.items():
                aspect = valid_aspects.get(name)
                if not aspect:
                    continue
                
                node = node_name(graph, 'entity')
                notation_type_name = self.get_type_name(slot_data)
                if notation_type_name:
                    # Ensure compatibility of annotation and codomain types.
                    type = most_specific(self.olog.type(notation_type_name), 
                                         aspect.codomain)
                else:
                    type = aspect.codomain
                slot_data.setdefault('type', type.name)
                slot_data.setdefault('root_type', 'entity')
                graph.add_node(node, **slot_data)
                graph.add_edge(entity, node, aspect=name)
    
    def merge_duplicate_aspects(self, graph):
        """ Merge duplicate input/output aspects in olog.
        
        This is a common pattern in object-oriented systems like Python.
        """
        query = lambda n: n['root_type'] == 'action'
        for action in list(find_nodes(graph, query)):
            inputs, outputs = {}, {}
            for _, entity, data in graph.out_edges_iter(action, data=True):
                aspect = data.get('aspect')
                if aspect and data['input']:
                    inputs[aspect] = entity
                elif aspect and data['output']:
                    outputs[aspect] = entity
            
            for aspect in set(inputs).intersection(outputs):
                # Merge only if input has no predecessors.
                if len(graph.predecessors(inputs[aspect])) == 1:
                    graph.remove_edge(action, inputs[aspect])
                    self.merge_nodes(graph, inputs[aspect], outputs[aspect])
    
    def merge_unknown_aspects(self, graph):
        """ Try to merge unknown aspects of actions.
        """
        query = lambda n: n['root_type'] == 'action'
        for action in list(find_nodes(graph, query)):
            for _, entity, data in graph.out_edges(action, data=True):
                if 'aspect' not in data:
                    if data['input']:
                        self.merge_unknown_input_output(
                            graph, action, entity, 'input')
                    elif data['output']:
                        self.merge_unknown_input_output(
                            graph, action, entity, 'output')
    
    def merge_unknown_input_output(self, graph, action, entity, entity_kind):
        """ Try to merge an unknown input or output of an action.
        """
        # Only merge entities with IDs.
        entity_data = graph.node[entity]
        entity_id = entity_data.get('id')
        if not entity_id:
            return
        
        # Try to find a suitable node to merge into.
        def visit_node(node, data):
            # Find the first node with the same ID.
            if data.get('id') == entity_id:
                raise StopIteration(node)
            return True
        
        def visit_edge(src, tgt, data):
            # Respect input/output designation.
            if src == action and not data[entity_kind]:
                return False
            # Only visit edges that are aspects.
            return data.get('aspect') is not None
        try:
            bfs(graph, action, data=True,
                visit_node=visit_node, visit_edge=visit_edge)
        
        # Perform the merge.
        except StopIteration as stop:
            node = stop.args[0]
            graph.remove_edge(action, entity)
            self.merge_nodes(graph, entity, node)
    
    # Helper methods
    
    def get_annotation(self, language, package, id):
        """ Retrieve a specific annotation from the DB.
        """
        # Load relevant annotations if they are not already.
        if (language, package) not in self._loaded:
            self.db.load_package(language, package)
            self._loaded.add((language, package))
        
        query = {'language': language, 'package': package, 'id': id}
        return self.db.get(query)
    
    def get_type_aspects(self, type_or_name):
        """ Get all inherited aspects of olog type.
        """
        if isinstance(type_or_name, Type):
            type = type_or_name
        else:
            type = self.olog.type(type_or_name)
        types, aspects = inherited(type)
        return { aspect.name: aspect for aspect in aspects }
    
    def get_type_name(self, data):
        """ Try to get a type name from entity or slot data.
        """
        note = data.get('annotation') or {}
        try:
            # First, check if there is already a type present. Currently,
            # this will only happen for "pseudo objects" (see the
            # `flow_graph_builder` module).
            return note['type']
        except KeyError:
            try:
                # Typical case: only an annotation primary key is present.
                # Retrieve the full annotation and check for a type.
                key = (note['language'], note['package'], note['id'])
                note = self.get_annotation(*key) or {}
                return note['type']
            except KeyError:
                # No type information available.
                return None
    
    def merge_nodes(self, graph, src, dest):
        """ Merge the source node into the destination node.
        
        The source node is removed and its data and edges are copied to the
        destination node.
        """
        # Merge type information, preferring the more specific type.
        src_data, dest_data = graph.node[src], graph.node[dest]
        src_type = self.olog.type(src_data['type'])
        dest_type = self.olog.type(dest_data['type'])
        dest_data['type'] = most_specific(src_type, dest_type).name
        
        # Merge incoming edges.
        for node, _, data in graph.in_edges_iter(src, data=True):
            graph.add_edge(node, dest, **data)
        
        # Merge outgoing edges recursively.
        dest_aspects = {
            data['aspect']: tgt
            for _, tgt, data in graph.out_edges_iter(dest, data=True)
            if 'aspect' in data
        }
        for _, tgt, data in graph.out_edges(src, data=True):
            aspect = data.get('aspect')
            if aspect and aspect in dest_aspects:
                self.merge_nodes(graph, tgt, dest_aspects[aspect])
            else:
                graph.add_edge(dest, tgt, **data)
        
        # Remove the source node.
        graph.remove_node(src)
    
    @default('olog')
    def _default_olog(self):
        return load_olog()
