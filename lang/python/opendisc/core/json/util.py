""" Miscellaneous utility functions for JSON.
"""
from __future__ import absolute_import

from datetime import datetime
import math, numbers
import six
import types

next_attr_name = '__next__' if six.PY3 else 'next'


def json_clean(obj):
    """ Clean an object to ensure it's safe to encode in JSON.

    Atomic, immutable objects are returned unmodified.  Sets and tuples are
    converted to lists, lists are copied and dicts are also copied.

    Note: dicts whose keys could cause collisions upon encoding (such as a dict
    with both the number 1 and the string '1' as keys) will cause a ValueError
    to be raised.

    Parameters
    ----------
    obj : any Python object

    Returns
    -------
    out : object
      A version of the input which will not cause an encoding error when
      encoded as JSON.  Note that this function does not *encode* its inputs,
      it simply sanitizes it so that there will be no encoding errors later.
     
    References
    ----------
    Original source:
        https://github.com/ipython/ipykernel/blob/master/ipykernel/jsonutil.py
    """
    # types that are 'atomic' and ok in json as-is.
    atomic_ok = (six.text_type, type(None))

    # containers that we need to convert into lists
    container_to_list = (tuple, frozenset, set, types.GeneratorType)

    # Since bools are a subtype of Integrals, which are a subtype of Reals,
    # we have to check them in that order.

    if isinstance(obj, bool):
        return obj

    if isinstance(obj, numbers.Integral):
        # cast int to int, in case subclasses override __str__ (e.g. boost enum, #4598)
        return int(obj)

    if isinstance(obj, numbers.Real):
        # cast out-of-range floats to their reprs
        if math.isnan(obj) or math.isinf(obj):
            return repr(obj)
        return float(obj)
    
    if isinstance(obj, atomic_ok):
        return obj

    if isinstance(obj, bytes):
        return obj.decode('utf-8', 'replace')

    if isinstance(obj, container_to_list) or (
        hasattr(obj, '__iter__') and hasattr(obj, next_attr_name)):
        obj = list(obj)

    if isinstance(obj, list):
        return [json_clean(x) for x in obj]

    if isinstance(obj, dict):
        # First, validate that the dict won't lose data in conversion due to
        # key collisions after stringification.  This can happen with keys like
        # True and 'true' or 1 and '1', which collide in JSON.
        nkeys = len(obj)
        nkeys_collapsed = len(set(map(six.text_type, obj)))
        if nkeys != nkeys_collapsed:
            raise ValueError('dict cannot be safely converted to JSON: '
                             'key collision would lead to dropped values')
        # If all OK, proceed by making the new dict that will be json-safe
        out = {}
        for k,v in obj.items():
            out[six.text_type(k)] = json_clean(v)
        return out
    
    if isinstance(obj, datetime):
        return obj.strftime(ISO8601)
    
    # we don't understand it, it's probably an unserializable object
    raise ValueError("Can't clean for JSON: %r" % obj)
