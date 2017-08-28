from __future__ import absolute_import

import inspect
import unittest
import sys

from opendisc.core.tests import objects
from ..frame_util import get_func_module, get_func_qual_name, \
    get_func_full_name, get_frame_module, get_frame_func


class TestFrameUtil(unittest.TestCase):
    """ Test cases for frame utility functions.
    """
    
    def test_get_func_module(self):
        """ Can we get the module in which a function object is defined?
        """
        module = objects.__name__
        self.assertEqual(get_func_module(objects.create_foo), module)
        self.assertEqual(get_func_module(objects.Foo.do_sum), module)
        self.assertEqual(get_func_module(objects.Foo().do_sum), module)
    
    def test_get_func_qual_name(self):
        """ Can we get the qualified name of a function object?
        """
        def assert_qual_name(func, name):
            self.assertEqual(get_func_qual_name(func), name)
        
        assert_qual_name(toplevel, 'toplevel')
        assert_qual_name(Toplevel().f, 'Toplevel.f')
        assert_qual_name(Toplevel.f_cls, 'Toplevel.f_cls')
        if sys.version_info[0] >= 3:
            # No Python 2 support for static methods
            assert_qual_name(Toplevel.f_static, 'Toplevel.f_static')
        assert_qual_name(lambda_f, '<lambda>')
    
    def test_get_func_full_name(self):
        """ Can we get the full name of a function object?
        """
        full_name = objects.__name__ + '.create_foo'
        self.assertEqual(get_func_full_name(objects.create_foo), full_name)
    
    def test_get_frame_module(self):
        """ Can we get the name of this module from a frame?
        """
        self.assertEqual(get_frame_module(inspect.currentframe()),
                         'opendisc.trace.tests.test_frame_util')
    
    def test_get_frame_func(self):
        """ Can we get the function object from a frame?
        """
        def assert_frame_func(frame, name):
            self.assertTrue(inspect.isframe(frame))
            self.assertEqual(get_frame_func(frame), name)
        
        assert_frame_func(toplevel(), toplevel)
        assert_frame_func(lambda_f(), lambda_f)
        
        inner = nested()
        assert_frame_func(inner(), inner)
        
        top = Toplevel()
        assert_frame_func(top.f(), top.f)
        assert_frame_func(Toplevel.f_cls(), Toplevel.f_cls)
        assert_frame_func(Toplevel().f_static(), Toplevel.f_static)
        
        inner = Nested()()
        assert_frame_func(inner.g(), inner.g)


# Test data

class Toplevel(object):
    
    def f(self):
        return inspect.currentframe()
    
    @classmethod
    def f_cls(cls):
        return inspect.currentframe()
    
    @staticmethod
    def f_static():
        return inspect.currentframe()

class Nested(object):
    
    class Inner(object):
        def g(self):
            return inspect.currentframe()
    
    def __call__(self):
        return Nested.Inner()

def toplevel():
    return inspect.currentframe()

def nested():
    def inner():
        return inspect.currentframe()
    return inner

lambda_f = lambda: inspect.currentframe()


if __name__ == '__main__':
    unittest.main()
