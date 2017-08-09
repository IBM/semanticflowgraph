from __future__ import absolute_import

from collections import OrderedDict

from traitlets import HasTraits, Any, Bool, Instance, Unicode


class TraceEvent(HasTraits):
    """ Event generated when tracing the execution of Python code.
    """
    
    # Tracer that created this event.
    tracer = Instance('opendisc.kernel.trace.tracer.Tracer')
    
    # The function object that was called.
    function = Any()
    
    # Name of module containing the definition of the called function.
    # E.g., 'collections' or 'opendisc.userlib.data.read_data'.
    module = Unicode()
    
    # Qualified name of the called function.
    # E.g., 'map' or 'OrderedDict.__init__'.
    qual_name = Unicode()
    
    # Whether the function call is "atomic", i.e., its body will not be traced.
    atomic = Bool()
    
    @property
    def full_name(self):
        """ Full name of the called function.
        """
        return self.module + '.' + self.qual_name


class TraceCall(TraceEvent):
    """ Event generated at the beginning of a function call.
    """
    
    # Map: argument name -> argument value.
    # The ordering of the arguments is that of the function definition.
    arguments = Instance(OrderedDict)


class TraceReturn(TraceEvent):
    """ Event generated when a function returns.
    """
    
    # Map: argument name -> argument value.
    # Warning: if an argument has pass-by-reference semantics (as most types
    # in Python do), the argument may be mutated from its state in the 
    # corresponding call event.
    arguments = Instance(OrderedDict)
    
    # Return value of function.
    return_value = Any()


# XXX: Trait change notifications for `return_value` can lead to FutureWarning
# from numpy: http://stackoverflow.com/questions/28337085
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)
