from __future__ import absolute_import

from copy import deepcopy
import gc

import networkx as nx
from traitlets import HasTraits, Instance, List, Unicode, default

from opendisc.kernel.slots import get_slot
from opendisc.kernel.trace.annotator import Annotator
from opendisc.kernel.trace.object_tracker import ObjectTracker
from opendisc.kernel.trace.trace_event import TraceEvent, TraceCall, TraceReturn
from .graph.util import node_name
from .json.util import json_clean


class FlowGraphBuilder(HasTraits):
    """ Build an object flow graph from a stream of trace events.
    
    A flow graph is a directed acyclic multigraph that describes the flow of
    objects through a program. Its nodes are function calls and its edges
    are (pointers to) objects. The incoming edges of a node are arguments to
    the function and outgoing edges are arguments or return values.
    (If the function is pure, the outgoing edges are only return values.)
    """
    
    # Top-level flow graph. Read-only.
    graph = Instance(nx.MultiDiGraph)
    
    # Finds annotations for Python object and functions.
    annotator = Instance(Annotator, args=())
    
    # Private traits.
    _stack = List() # List(Instance(_CallItem))
    
    # Public interface
    
    def push_event(self, event):
        """ Push a new TraceEvent to the builder.
        """
        if isinstance(event, TraceCall):
            self._push_call_event(event)
        elif isinstance(event, TraceReturn):
            self._push_return_event(event)
        else:
            raise TypeError("Event must be TraceCall or TraceReturn")
    
    def reset(self):
        """ Reset the flow graph builder.
        """
        self.graph = self._create_graph()
        self._stack = []
    
    def is_primitive(self, obj):
        """ Is the object considered primitive?
        
        Only primitive objects will be captured as "value" data for explicitly
        annotated inputs, outputs, and slots. (This does not preclude getting
        "id" data if object is also weak-referenceable.)
        
        Almost always, scalar types (bool, int, float, string, etc.) should be
        regarded primitive. The default implementation allows any object which
        is JSON-able (essentially, the scalar types plus the built-in container
        types if their contents are JSON-able).
        
        Note: any objects stored as "value" data will be deep-copied.
        """
        try:
            json_clean(obj)
        except ValueError:
            return False
        return True
    
    def is_pure(self, event, annotation, arg_name):
        """ Is the call event pure with respect to the given argument?
        
        In a pure functional language (like Haskell) or a language with
        copy-on-modify semantics (like R), this would always be True, but in
        Python functions frequently mutate their arguments. Nevertheless,
        we regard the function as pure unless explicitly annotated otherwise.
        
        Of course, this convention is not really "correct", but the alternative
        is flow graphs with too many false positive mutations. In addition,
        even if we assumed mutating semantics by default, we don't have the
        complicated machinery to track downstream objects that may modify the
        original object, as in the following example:
        
            df = pandas.DataFrame(...)
            x = df.values
            x[:,0] = ...    # Also a mutation of `df`
        
        In view of these difficulties, we are basically punting on tracking
        object mutations. In the future we could consider adding
        object-specific heuristics to detect mutations, e.g., for data frames
        check the column names and dtypes or even, if the data is small enough,
        a hash of the underlying data.
        """
        # Special case: certain methods are never pure.
        func_name = event.qual_name.split('.')[-1]
        mutating_methods = ('__init__', '__setattr__', '__setitem__')
        if func_name in mutating_methods and arg_name == 'self':
            return False
        
        # Default: pure unless explicitly annotated otherwise!
        codomain = annotation.get('codomain', [])
        return not any(arg_name == obj['slot'] for obj in codomain)
    
    # Protected interface
    
    @default('graph')
    def _create_graph(self):
        """ Create an empty flow graph.
        """
        graph = nx.MultiDiGraph()
        graph.graph.update({
            'object_annotations': {},
            'source': {},
            'sink': {},
        })
        return graph
            
    def _push_call_event(self, event):
        """ Push a call event onto the stack.
        """
        # Create node for call.
        if self._stack:
            item = self._stack[-1]
            graph = item.graph.node[item.node]['graph']
        else:
            graph = self.graph
        node = self._add_call_node(event, graph)
        
        # Add edges for function arguments.
        annotation = self.annotator.notate_function(event.function) or {}
        object_tracker = event.tracer.object_tracker
        for arg_name, arg in event.arguments.items():
            is_pure = self.is_pure(event, annotation, arg_name)
            self._add_call_in_edge(event, graph, node, arg_name, arg,
                                   is_pure=is_pure)
            for value in self._hidden_referents(object_tracker, arg):
                self._add_call_in_edge(event, graph, node, arg_name, value,
                                       is_pure=is_pure)
        
        # If the call is not atomic, we have entered a new scope.
        # Push a new graph and attach it to this node.
        if not event.atomic:
            graph.node[node]['graph'] = self._create_graph()
        
        # Push call onto stack.
        self._stack.append(_CallItem(call=event, node=node, graph=graph))
        
    def _push_return_event(self, event):
        """ Push a return event and pop the corresponding call from the stack.
        """
        # Pop matching call event from stack.
        try:
            item = self._stack.pop()
        except IndexError:
            item = None
        if not (item and item.call.full_name == event.full_name):
            # Sanity check
            raise RuntimeError("Mismatched trace events")
        graph, node = item.graph, item.node
        data = graph.node[node]
                
        # Add explicitly annotated function outputs.
        annotation = self.annotator.notate_function(event.function) or {}
        data['outputs'] = self._create_slots_data(
            event,
            _IOSlots(event),
            annotation.get('outputs', {}))
        
        # Set annotation and sink for return value.
        return_id = event.tracer.object_tracker.get_id(event.return_value)
        if return_id:
            sink = graph.graph['sink']
            sink[return_id] = (node, '__return__')
            
            object_notes = graph.graph['object_annotations']
            if return_id not in object_notes:
                note = self.annotator.notate_object(event.return_value)
                object_notes[return_id] = self._annotation_key(note)
    
    def _add_call_node(self, event, graph):
        """ Add a new node for a call event.
        """
        annotation = self.annotator.notate_function(event.function) or {}
        node = node_name(graph, event.qual_name)
        data = {
            'annotation': self._annotation_key(annotation),
            'module': event.module,
            'qual_name': event.qual_name,
            'inputs': self._create_slots_data(
                event,
                _IOSlots(event),
                annotation.get('inputs', {})
            ),
        }
        graph.add_node(node, **data)
        return node
    
    def _add_call_in_edge(self, event, graph, node, arg_name, arg, is_pure=True):
        """ Add an incoming edge to a call node.
        """
        object_notes = graph.graph['object_annotations']
        source, sink = graph.graph['source'], graph.graph['sink']
        
        # Only proceed if the argument is tracked.
        arg_id = event.tracer.object_tracker.get_id(arg)
        if not arg_id:
            return
        if arg_id not in object_notes:
            note = self.annotator.notate_object(arg)
            object_notes[arg_id] = self._annotation_key(note)
        
        # Add edge if the argument has a known sink.
        if arg_id in sink:
            pred, pred_port = sink[arg_id]
            graph.add_edge(pred, node, id=arg_id,
                           sourceport=pred_port, targetport=arg_name)
        
        # Otherwise, mark the argument as a source.
        # Special case: Treat `self` in object initializer as return value.
        # This is semantically correct, though inconsistent with the
        # Python implementation.
        elif not (event.atomic and event.qual_name.endswith('__init__') and
                  arg_name == 'self'):
            source_nodes = source.setdefault(arg_id, [])
            source_nodes.append((node, arg_name))
    
        # Update sink if this call is atomic and mutating.
        if event.atomic and not is_pure:
            sink[arg_id] = (node, arg_name)
    
    def _create_slots_data(self, event, slot_obj, slots):
        """ Create data for slots on an object.
        
        The `slots` argument is mapping from names to slots.
        """
        result = {}
        for name, slot in slots.items():
            try:
                slot_value = get_slot(slot_obj, slot)
            except AttributeError:
                continue
            result[name] = self._create_slot_data(event, slot_value, slot_value)
        return result
    
    def _create_slot_data(self, event, slot_obj, slot_value, note=None):
        """ Create data for a single slot on an object.
        """
        data = {}
        
        # Add data for Python object.
        obj = slot_value
        if obj is not None:
            # Add ID if the object is trackable.
            if ObjectTracker.is_trackable(obj):
                obj_id = event.tracer.object_tracker.get_id(obj)
                if not obj_id:
                    obj_id = event.tracer.track_object(obj)
                data['id'] = obj_id
            
            # Add value if the object is primitive.
            if self.is_primitive(obj):
                data['value'] = deepcopy(obj)
        
            # Get annotation if we don't already have one.
            if not note:
                note = self.annotator.notate_object(obj)
                
        # Add annotation, if it exists.
        if note:
            data['annotation'] = self._annotation_key(note)
            
        # Add slots if the object has any, recursively invoking this function.
        if note and 'slots' in note:
            data['slots'] = self._create_slots_data(
                event, slot_obj, note['slots'])
        
        return data
    
    def _annotation_key(self, note):
        """ Get a key identifying an annotation.
        """
        if note:
            keys = ('language', 'package', 'id')
            return '/'.join(note[key] for key in keys)
        return None
    
    def _hidden_referents(self, tracker, obj):
        """ Get "hidden" referents of an object.
        
        The Python container types `tuple`, `list`, and `dict` are not
        weak-referenceable and hence not trackable by `ObjectTracker`. In fact,
        not even subclasses of `tuple` are weak-referenceable! Moreover,
        `Tracer` does not produce trace events for `tuple`, `list`, `dict`, and
        `set` literals or comprehensions (because `sys.settrace` does not).
        Consequently the objects belonging to (referenced by) these containers
        are "hidden" from our system.
        
        This method uses the Python garbage collector to find tracked objects
        referred to by untrackable containers.
        
        See also `Tracker.is_trackable()`.
        """
        # FIXME: Should we find referents recursively?
        if isinstance(obj, (tuple, list, dict, set, frozenset)):
            for referent in gc.get_referents(obj):
                if tracker.is_tracked(referent):
                    yield referent


class _CallItem(HasTraits):
    """ Internal state for FlowGraphBuilder.
    """
    # The trace call for this call stack item.
    call = Instance(TraceCall)
    
    # Name of graph node created for call.
    node = Unicode()
    
    # Graph containing the node.
    graph = Instance(nx.MultiDiGraph)


class _IOSlots(object):
    """ Implementation detail of FlowGraphBuilder. 
    """

    def __init__(self, event):
        self.__event = event
    
    def __getattr__(self, name):
        event = self.__event
        if name == '__return__':
            return event.return_value
        try:
            return event.arguments[name]
        except KeyError:
            raise AttributeError("No slot %r" % name)
    
    def __getitem__(self, index):
        event = self.__event
        argument_names = list(event.arguments.keys())
        return event.arguments[argument_names[index]]
