from __future__ import absolute_import

from traitlets import HasTraits

# Constants.
wrapper_descriptor_type = type(object.__getattribute__)


class AttributeTracer(HasTraits):
    """ Enable attribute tracing of Python objects.
    
    The system trace function only traces Python functions, not functions
    implemented at the C level. To reliably trace attribute accesses, we replace
    the default C implementations of `__getattr__` and `__setattr__` with dummy
    Python implementations that call them.
    
    This class is intended for use with `Tracer`.
    """
    
    def install(self, obj):
        """ Configure an object for attribute tracing.
        """
        # XXX: We are replacing the methods at the class level!
        # (It's not possible to replace __getattribute__ at the instance level.)
        cls = obj.__class__
        
        # For old-style classes (only relevant in Python 2), we can't do this.
        if not issubclass(cls, object):
            return
        
        self._install_getattr(cls)
        self._install_setattr(cls)
    
    def _install_getattr(self, cls):
        """ Replace __getattribute__ with a dummy Python wrapper.
        """
        if type(cls.__getattribute__) is not wrapper_descriptor_type:
            # No need to replace.
            return
        
        # Create dummy attribute getter.
        def __getattribute__(self, name):
            return super(cls, self).__getattribute__(name)
        __getattribute__.__module__ = cls.__module__
        __getattribute__.__qualname__ = cls.__name__ + '.__getattribute__'
        
        # The assignment will fail for builtin types (such as list and dict)
        # and C extension types (such as np.ndarray).
        # FIXME: Can I check for this explicitly?
        try:
            cls.__getattribute__ = __getattribute__
        except TypeError:
            pass

    def _install_setattr(self, cls):
        """ Replace __setattr__ with a dummy Python wrapper.
        """
        if type(cls.__setattr__) is not wrapper_descriptor_type:
            # No need to replace.
            return

        # Create dummy attribute getter.
        def __setattr__(self, name, value):
            return super(cls, self).__setattr__(name, value)
        __setattr__.__module__ = cls.__module__
        __setattr__.__qualname__ = cls.__name__ + '.__setattr__'
        
        # See above.
        try:
            cls.__setattr__ = __setattr__
        except TypeError:
            pass
