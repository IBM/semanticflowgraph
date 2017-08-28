from __future__ import absolute_import

from copy import deepcopy
import gc

from ipykernel.jsonutil import json_clean
import networkx as nx
from traitlets import HasTraits, Dict, Instance, List, Unicode, default

from opendisc.kernel.slots import get_slot
from opendisc.kernel.trace.annotator import Annotator
from opendisc.kernel.trace.object_tracker import ObjectTracker
from opendisc.kernel.trace.trace_event import TraceEvent, TraceCall, TraceReturn
from .graph_util import node_name
from .flow_graph import new_flow_graph


class FlowGraphBuilder(HasTraits):
    """ Build an object flow graph from a stream of trace events.
    
    A flow graph is a directed acyclic multigraph that describes the flow of
    objects through a program. Its nodes are function calls and its edges
    are (pointers to) objects. The incoming edges of a node are arguments to
    the function and outgoing edges are arguments or return values.
    (If the function is pure, the outgoing edges are only return values.)
    """
    
    # Annotator for Python objects and functions.
    annotator = Instance(Annotator, args=())
    
    # Private traits.
    _stack = List() # List(Instance(_CallContext))
    
    # Public interface
    
    def __init__(self, **traits):
        super(FlowGraphBuilder, self).__init__(**traits)
        self.reset()
    
    @property
    def graph(self):
        """ Top-level flow graph.
        """
        # Make a shallow copy.
        return nx.MultiDiGraph(self._stack[0].graph)
    
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
        # The bottom of the call stack does not correspond to a call event.
        # It simply contains the root flow graph and associated state.
        graph = new_flow_graph()
        self._stack = [ _CallContext(graph=graph) ]
    
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
            
    def _push_call_event(self, event):
        """ Push a call event onto the stack.
        """
        # Get graph from context of previous call.
        context = self._stack[-1]
        graph = context.graph
        
        # Create a new node for this call.
        node = self._add_call_node(event, graph)
        
        # Add edges for function arguments.
        annotation = self.annotator.notate_function(event.function) or {}
        object_tracker = event.tracer.object_tracker
        for arg_name, arg in event.arguments.items():
            is_pure = self.is_pure(event, annotation, arg_name)
            self._add_call_in_edge(event, context, node, arg_name, arg,
                                   is_pure=is_pure)
            for value in self._hidden_referents(object_tracker, arg):
                self._add_call_in_edge(event, context, node, arg_name, value,
                                       is_pure=is_pure)
        
        # If the call is not atomic, we will enter a new scope.
        # Create a nested flow graph for the node.
        nested = None
        if not event.atomic:
            nested = new_flow_graph()
            graph.node[node]['graph'] = nested
    
        # Push call context onto stack.
        self._stack.append(_CallContext(event=event, node=node, graph=nested))
        
    def _push_return_event(self, event):
        """ Push a return event and pop the corresponding call from the stack.
        """
        # Pop matching call event from stack to retrieve node.
        context = self._stack.pop()
        if not context.event.full_name == event.full_name:
            # Sanity check
            raise RuntimeError("Mismatched trace events")
        node = context.node
        
        # Get graph from context of previous call.
        context = self._stack[-1]
        graph = context.graph
        data = graph.node[node]
                
        # Add explicitly annotated function outputs.
        annotation = self.annotator.notate_function(event.function) or {}
        if 'codomain' in annotation:
            output_slots = [ obj['slot'] for obj in annotation['codomain'] ]
        else:
            output_slots = [ '__return__' ]
        ports = data.setdefault('ports', {})
        ports.update(self._create_slots_data(
            event.tracer,
            _IOSlots(event),
            output_slots,
            { 'portkind': 'output' },
        ))
        
        # Set output for return value.
        return_id = event.tracer.object_tracker.get_id(event.return_value)
        if return_id:
            self._set_object_output_node(context, return_id, node, '__return__')
    
    def _add_call_node(self, event, graph):
        """ Add a new node for a call event.
        """
        annotation = self.annotator.notate_function(event.function) or {}
        node = node_name(graph, event.qual_name)
        data = {
            'annotation': self._annotation_key(annotation),
            'module': event.module,
            'qual_name': event.qual_name,
            'ports': self._create_slots_data(
                event.tracer,
                _IOSlots(event),
                event.arguments.keys(),
                { 'portkind': 'input' },
            ),
        }
        graph.add_node(node, **data)
        return node
    
    def _add_call_in_edge(self, event, context, node, arg_name, arg, is_pure=True):
        """ Add an incoming edge to a call node.
        """
        # Only proceed if the argument is tracked.
        arg_id = event.tracer.object_tracker.get_id(arg)
        if not arg_id:
            return
        
        # Add edge if the argument has a known output node.
        graph = context.graph
        src, src_port = self._get_object_output_node(context, arg_id)
        if src is not None:
            graph.add_edge(src, node, id=arg_id,
                           sourceport=src_port, targetport=arg_name)
        
        # Otherwise, mark the argument as an unknown input.
        # Special case: Treat `self` in object initializer as return value.
        # This is semantically correct, though inconsistent with the
        # Python implementation.
        elif not (event.atomic and event.qual_name.endswith('__init__') and
                  arg_name == 'self'):
            self._add_object_input_node(context, arg_id, node, arg_name)
    
        # Update output node if this call is atomic and mutating.
        if event.atomic and not is_pure:
            self._set_object_output_node(context, arg_id, node, arg_name)
    
    def _add_object_input_node(self, context, obj_id, node, port):
        """ Add an object as an unknown input to a node.
        """
        graph = context.graph
        input_node = graph.graph['input_node']
        graph.add_edge(input_node, node, id=obj_id, targetport=port)
    
    def _get_object_output_node(self, context, obj_id):
        """ Get the node/port of which the object is an output, if any. 
        
        An object is an "output" of a call node if it is the last node to have
        created/mutated the object.
        """
        output_table = context.output_table
        return output_table.get(obj_id, (None, None))
    
    def _set_object_output_node(self, context, obj_id, node, port):
        """ Set an object as an output of a node.
        """
        graph, output_table = context.graph, context.output_table
        output_node = graph.graph['output_node']
        
        # Remove old output, if any.
        if obj_id in output_table:
            old, _ = output_table[obj_id]
            keys = [ key for key, data in graph.edge[old][output_node].items()
                     if data['id'] == obj_id ]
            assert len(keys) == 1
            graph.remove_edge(old, output_node, key=keys[0])
        
        # Set new output.
        output_table[obj_id] = (node, port)
        graph.add_edge(node, output_node, id=obj_id, sourceport=port)
    
    def _create_slots_data(self, tracer, slot_obj, slots, extra_data={}):
        """ Create data for slots on an object.
        """
        result = {}
        for slot in slots:
            try:
                slot_value = get_slot(slot_obj, slot)
            except AttributeError:
                continue
            data = self._create_slot_data(tracer, slot, slot_value)
            data.update(extra_data)
            result[slot] = data
        return result
    
    def _create_slot_data(self, tracer, slot, obj):
        """ Create data for a single slot value.
        """
        data = {}
        if obj is None:
            return data
        
        # Add ID if the object is trackable.
        if ObjectTracker.is_trackable(obj):
            obj_id = tracer.object_tracker.get_id(obj)
            if not obj_id:
                obj_id = tracer.track_object(obj)
            data['id'] = obj_id
        
        # Add value if the object is primitive.
        if self.is_primitive(obj):
            data['value'] = deepcopy(obj)
                
        # Add annotation, if it exists.
        note = self.annotator.notate_object(obj)
        if note:
            data['annotation'] = self._annotation_key(note)
        
        # Add slots if the object has any, recursively invoking this function.
        #if note and 'slots' in note:
        #    data['slots'] = self._create_slots_data(
        #        event, slot_obj, note['slots'])
        
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


class _CallContext(HasTraits):
    """ Context for a trace call event.
    
    Internal state for FlowGraphBuilder.
    """
    # The trace call event for this call stack item.
    event = Instance(TraceCall)
    
    # Name of graph node created for call.
    node = Unicode()
    
    # Graph nested in node, if any.
    graph = Instance(nx.MultiDiGraph, allow_none=True)
    
    # Output table for the graph.
    #
    # At any given time during execution, an object is the output of at most one
    # node, i.e., there is at most one incoming edge to the special output node
    # that carries a particular object. We maintain this mapping as an auxiliary
    # data structure called the "output table". It is logically superfluous--the
    # same information is captured by the graph topology--but improves
    # efficiency by allowing constant-time lookup.
    output_table = Dict()


class _IOSlots(object):
    """ Get slots of a function call or return event.
    
    Implementation detail of FlowGraphBuilder.
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
            raise AttributeError("No function slot %r" % name)
    
    def __getitem__(self, index):
        event = self.__event
        argument_names = list(event.arguments.keys())
        return event.arguments[argument_names[index]]
