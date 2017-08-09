from __future__ import absolute_import

import six
import uuid
import types
import weakref

from traitlets import HasTraits, Dict


class ObjectTracker(HasTraits):
    """ Allow object lookup by ID without creating references to the object.
    
    The IDs are strings that uniquely identify the object. Unlike the integer
    IDs returned by Python's `id` function, these IDs are unique for all time.
    """
    
    # Map: memory address -> object ID.
    _mem_map = Dict()

    # Map: object ID -> weakref.
    # Semantically, we would prefer a WeakValueDictionary, but it requires
    # its contents to be hashable.
    _ref_map = Dict()

    def get_object(self, obj_id):
        """ Look up an object by ID.
        
        Returns None if the object is not being tracked or has been garbage
        collected.
        """
        ref = self._ref_map.get(obj_id)
        return ref() if ref else None
    
    def get_id(self, obj):
        """ Get the ID of a tracked object.
        
        Returns None if the object is not tracked.
        """
        if not self.is_trackable(obj):
            return None
        return self._mem_map.get(id(obj))
    
    def is_tracked(self, obj):
        """ Is the given object currently being tracked?
        """
        if not self.is_trackable(obj):
            return False
        return id(obj) in self._mem_map
    
    @classmethod
    def is_trackable(cls, obj):
        """ Is it possible to track the given object?
        
        Most importantly, primitive scalar types are not trackable.
        """
        # We never track function objects, even though they are weakref-able.
        if isinstance(obj, (types.FunctionType, types.MethodType)):
            return False
        
        # FIXME: Is there another way to check if an object is weakref-able?
        try:
            weakref.ref(obj)
        except TypeError:
            return False
        return True
    
    def track(self, obj):
        """ Start tracking an object.
        
        Returns an ID for the object.
        """
        if not self.is_trackable(obj):
            raise TypeError("Cannot track object of type %r" % type(obj))
        
        # Check if object is already being tracked.
        obj_addr = id(obj)
        if obj_addr in self._mem_map:
            return self._mem_map[obj_addr]
        
        # Generate a new object ID.
        obj_id = uuid.uuid4().hex
        
        def obj_gc_callback(ref):
            del self._mem_map[obj_addr]
            del self._ref_map[obj_id]
        self._mem_map[obj_addr] = obj_id
        self._ref_map[obj_id] = weakref.ref(obj, obj_gc_callback)
        
        return obj_id
