""" Utilities for working with frame objects.
"""
from collections import OrderedDict
import gc
import inspect
import sys
import types


def get_class_module(typ):
    """ Get name of module in which type was defined.
    """
    return _apply_spec(typ.__module__)

def get_class_qual_name(typ):
    """ Get qualified name of class.
    
    See PEP 3155: "Qualified name for classes and functions"
    """
    if sys.version_info[0] >= 3 and sys.version_info[1] >= 3:
        return typ.__qualname__
    else:
        # Not possible on older versions of Python. Just give up.
        return typ.__name__

def get_class_full_name(typ):
    """ Get the full name of a class.
    """
    return get_class_module(typ) + '.' + get_class_qual_name(typ)


def get_func_module(func):
    """ Get name of module in which the function object was defined.
    """
    return _apply_spec(func.__module__)

def get_func_qual_name(func):
    """ Get the qualified name of a function object.
    
    See PEP 3155: "Qualified name for classes and functions"
    """
    # Python 2 implementation
    if sys.version_info[0] == 2:
        name = func.__name__
        if isinstance(func, types.MethodType):
            if type(func.im_self) is type(object):
                # Case 1: class method
                return func.im_self.__name__ + '.' + name
            else:
                # Case 2: instance method
                return func.im_class.__name__ + '.' + name
        else:
            # Case 3: ordinary function
            return name
    
    # Python 3 implementation
    elif sys.version_info[0] >= 3 and sys.version_info[1] >= 3:
        return func.__qualname__
    
    else:
        raise NotImplementedError("Only implemented for Python 2 and 3.3+")

def get_func_full_name(func):
    """ Get the full name of a function object.
    """
    return get_func_module(func) + '.' + get_func_qual_name(func)


def get_frame_module(frame):
    """ Get name of module containing the frame code.
    
    Returns None if the module cannot be identified.
    """
    try:
        name = frame.f_globals['__name__']
    except KeyError:
        # Some frames, e.g. calls of IPython magics, belong to no module.
        name = None
    return _apply_spec(name)

def get_frame_func(frame, raise_on_ambiguous=True):
    """ Get the function/method object of the called function in a frame.
    """
    code = frame.f_code
    meth = None
    # Special case 1: Instance method
    if code.co_argcount > 0 and code.co_varnames[0] == 'self':
        meth = getattr(frame.f_locals['self'], code.co_name, None)
    # Special case 2: Class method
    elif code.co_argcount > 0 and code.co_varnames[0] == 'cls':
        meth = getattr(frame.f_locals['cls'], code.co_name, None)
    if isinstance(meth, types.MethodType):
        return meth
    # The general case is not useful here since it will return the underlying
    # function of the bound method, i.e., `meth.__func__`.
    
    # General case: fish the function out of the garbage collector.
    # XXX: This is a terrible hack, but I don't know a better way.
    funcs = [ ref for ref in gc.get_referrers(code)
              if isinstance(ref, (types.FunctionType, types.LambdaType)) ]
    if len(funcs) == 0:
        raise ValueError("Could not find function object for frame")
    elif len(funcs) > 1 and raise_on_ambiguous:
        raise ValueError("Ambiguous function object for frame")
    return funcs[0]

def get_frame_arguments(frame):
    """ Get all arguments of the called function in a frame.

    Returns an OrderedDict whose keys are argument names and values are 
    argument values.
    """
    try:
        info = inspect.getargvalues(frame)
    except TypeError:
        # Inspection will fail for C extension functions. In that case,
        # fall back to simpler logic which ignores * and ** arguments.
        names = frame.f_code.co_varnames[:frame.f_code.co_argcount]
        return OrderedDict((name, frame.f_locals[name]) for name in names)
    
    # Get all arguments, including * and ** arguments.
    args = OrderedDict((name, info.locals[name]) for name in info.args)
    if info.varargs:
        varargs = info.locals[info.varargs]
        args.update(('__vararg%i__' % i, arg) for i, arg in enumerate(varargs))
    if info.keywords:
        keywords = info.locals[info.keywords]
        args.update((name, keywords[name]) for name in sorted(keywords))
    return args


def _apply_spec(name):
    """ Hack to replace __main__ with correct module name.
    
    See PEP 451: "A ModuleSpec Type for the Import System"
    """
    if name == '__main__':
        spec = getattr(sys.modules['__main__'], '__spec__', None)
        if spec is not None:
            name = spec.name
    return name
