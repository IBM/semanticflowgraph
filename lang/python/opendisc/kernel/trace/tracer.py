from __future__ import absolute_import

import sys

from traitlets import HasTraits, Bool, Dict, Instance, Int, List, Unicode

from .attribute_tracer import AttributeTracer
from .frame_util import get_frame_module, get_frame_func, get_frame_arguments,\
    get_func_module, get_func_qual_name
from .object_tracker import ObjectTracker
from .trace_event import TraceEvent, TraceCall, TraceReturn


class Tracer(HasTraits):
    """ Execution tracer for Open Discovery kernel.
    
    This class provides a user-friendly wrapper around the system trace 
    function (see `sys.settrace`). Its outputs (trace events) are consumed by
    the flow graph builder.
    """
    
    # The most recent trace event. Read-only.
    # XXX: In Enthought traits, this would be an Event trait.
    event = Instance(TraceEvent, allow_none=True)
    
    # The trace call event stack. Read-only.
    stack = List(Instance(TraceCall))
    
    # Only function calls made in these modules will be traced.
    # (The function itself can be defined in other modules.)
    modules = List(Unicode(), ['__main__'])
    
    # Controls the tracing of attribute getters and setters.
    # If this is disabled, whether attribute accesses are traced will depend
    # on implementation details of the object, such as whether the attribute
    # is a @property or, more generally, invokes Python-level code.
    attribute_tracer = Instance(AttributeTracer, args=(), allow_none=True)
    
    # Tracks objects using weak references.
    object_tracker = Instance(ObjectTracker, args=())
    
    # Tracer interface

    def enable(self):
        """ Enable the tracer.
        
        Warning: this disables any other trace function that may be enabled,
        such as a debugger or profiler.
        """
        self.event = None
        self.stack = []
        sys.settrace(self._trace_function)
    
    def disable(self):
        """ Disable the tracer.
        """
        sys.settrace(None)
    
    def track_object(self, obj):
        """ Start tracking an object.
        """
        if self.attribute_tracer:
            self.attribute_tracer.install(obj)
        return self.object_tracker.track(obj)
    
    # Context manager interface
    
    def __enter__(self):
        self.enable()
        
    def __exit__(self, type, value, traceback):
        self.disable()
    
    # Protected interface

    def _trace_function(self, frame, event, arg):
        """ Official trace function called by Python interpreter.
        """
        if event != 'call':
            return
        
        # If we're inside an atomic function call, abort immediately.
        # See `TestTracer.test_atomic_higher_order_call` and
        #     `TestFlowGraphBuilder.test_higher_order_function`
        # for cases where this makes a difference.
        if self.stack and self.stack[-1].atomic:
            return
        
        # Make sure the function has been called from a white-listed module.
        if get_frame_module(frame.f_back) not in self.modules:
            return
        
        # Get the function object for called function.
        try:
            # Multiple matches can occur for dynamically created functions,
            # but we treat them as interchangeable.
            func = get_frame_func(frame, raise_on_ambiguous=False)
        except ValueError:
            # It is possible for `get_frame_func` to fail. If so, just exit.
            # FIXME: Log this failure?
            return
        
        # One last filter before dispatching the event.
        module, qual_name = get_func_module(func), get_func_qual_name(func)
        atomic = module not in self.modules
        if not self._trace_filter(module, qual_name):
            return
            
        # Track every argument that is trackable.
        args = get_frame_arguments(frame)
        for arg in args.values():
            if self.object_tracker.is_trackable(arg):
                self.track_object(arg)
        
        # Push the call event.
        self.event = TraceCall(tracer=self, function=func, atomic=atomic,
                               module=module, qual_name=qual_name,
                               arguments=args)
        self.stack.append(self.event)
        
        # Return a local trace function to handle the 'return' event.
        
        def local_trace_function(frame, event, value):
            if event != 'return':
                return
            
            # Track the return value, if possible.
            if self.object_tracker.is_trackable(value):
                self.track_object(value)
            
            # Create a return event and pop the corresponding call event.
            self.event = TraceReturn(tracer=self, function=func, atomic=atomic,
                                     module=module, qual_name=qual_name,
                                     arguments=args, return_value=value)
            self.stack.pop()
        
        return local_trace_function
    
    def _trace_filter(self, module, qual_name):
        """ Whether to trace a call to the given function.
        """        
        # Don't trace calls to hidden modules in Python implementation.
        # A common appearance here is `_frozen_importlib`.
        if module.startswith('_'):
            return False
        
        # No interference from this package.
        # Calls that can be picked up include:
        #   - Tracer.__exit__
        #   - Garbage collection callback from ObjectTracker
        if module.startswith('opendisc.kernel.trace') and not 'tests' in module:
            return False
        
        # By default, trace the function.
        return True
