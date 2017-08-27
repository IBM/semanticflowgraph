from __future__ import absolute_import

import six
from six.moves import reduce
import types


def get_slots(obj, slots):
    """ Get slots on the given object.
    
    A slot is generalized attribute. See `get_slot` for details.
    """
    if isinstance(slots, dict):
        return { key: get_slots(obj, value) for key, value in slots.items() }
    elif isinstance(slots, list):
        return [ get_slots(obj, value) for value in slots ]
    elif isinstance(slots, six.integer_types + six.string_types):
        return get_slot(obj, slots)
    else:
        raise TypeError("`slots` must be dict, list, string, or integer")


def get_slot(obj, slot):
    """ Get a slot on the given object.
    
    A slot is generalized attribute ala Django's variable lookup in HTML
    templates. We support:
        - Attributes
        - Bound methods (with no arguments)
        - Dictionary lookup
        - List indexing
    
    Raises an AttributeError if the slot cannot be retrieved.
    """
    if isinstance(slot, six.string_types):
        keys = slot.split('.')
        return reduce(_get_single_slot, keys, obj)
    elif isinstance(slot, six.integer_types):
        return obj[slot]
    else:
        raise TypeError("`slot` must be string or integer")

def _get_single_slot(obj, key):
    try:
        value = getattr(obj, key)
    except AttributeError:
        try:
            key = int(key)
        except ValueError:
            pass
        try:
            return obj[key]
        except:
            raise AttributeError("Cannot retrieve slot %r" % key)
    else:
        if isinstance(value, types.MethodType):
            if not value.__self__ is obj:
                raise AttributeError(
                    "Cannot retrieve method slot %r: method not bound to object" % key)
            if six.get_function_code(value).co_argcount > 1:
                raise AttributeError(
                    "Cannot retrieve method slot %r: too many arguments" % key)
            return value()
        else:
            return value
