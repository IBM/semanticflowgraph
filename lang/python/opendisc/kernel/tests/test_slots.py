from __future__ import absolute_import

import types
import unittest

from ipython_genutils.ipstruct import Struct

from ..slots import get_slot, get_slots


class TestSlotFunctions(unittest.TestCase):
    """ Test cases for slot retrieval functions.
    """
    
    def test_basic_slots(self):
        """ Can we retrieve top-level attributes, perhaps recursively?
        """
        obj = Struct({'x':1, 'y':2})
        self.assertEqual(get_slots(obj, 'x'), 1)
        self.assertEqual(get_slots(obj, ['x','y']), [1,2])
        self.assertEqual(get_slots(obj, {'x':'x', 'y':'y'}),
                         {'x':1, 'y': 2})
        self.assertEqual(get_slots(obj, {'letter': {'x':'x'}}),
                         {'letter': {'x':1}})
    
    def test_method_slot(self):
        """ Can we retrieve top-level methods?
        """
        obj = Struct()
        obj.getter = types.MethodType(lambda self: 0, obj)
        self.assertEqual(get_slot(obj, 'getter'), 0)
    
    def test_method_not_bound(self):
        """ Check that methods that not bound to the object are not called.
        """
        other = Struct()
        other.getter = types.MethodType(lambda self: 0, other)
        obj = Struct()
        obj.meth = other.getter
        self.assertRaises(AttributeError, lambda: get_slot(obj, 'meth'))
    
    def test_method_slot_args(self):
        """ Check that methods with required arguments are not called.
        """
        obj = Struct()
        obj.meth = types.MethodType(lambda self, x: x, obj)
        self.assertRaises(AttributeError, lambda: get_slot(obj, 'meth'))
    
    def test_nested_slot(self):
        """ Can we retrieve nested attributes?
        """
        obj = Struct()
        obj.outer = Struct({'inner': 'foo'})
        self.assertEqual(get_slot(obj, 'outer.inner'), 'foo')
    
    def test_list_slot(self):
        """ Can we retrieve list items?
        """
        self.assertEqual(get_slot([1,2,3], '0'), 1)
        
        obj = Struct({'objects': ['foo','bar']})
        self.assertEqual(get_slot(obj, 'objects.0'), 'foo')
    
    def test_list_integer_slot(self):
        """ Can we retrieve list items with an integer slot?
        """
        self.assertEqual(get_slot([1,2,3], 0), 1)
        self.assertEqual(get_slots([1,2,3], 0), 1)
    
    def test_dict_slot(self):
        """ Can we retrieve dictionary items?
        """
        obj = Struct({'objects': {'id1': 'foo', 'id2': 'bar'}})
        self.assertEqual(get_slot(obj, 'objects.id1'), 'foo')


if __name__ == '__main__':
    unittest.main()
