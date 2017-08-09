from __future__ import absolute_import

import gc
import unittest

from opendisc.core.tests import objects
from ..object_tracker import ObjectTracker


class TestObjectTracker(unittest.TestCase):
    
    def test_is_trackable(self):
        """ Are objects correctly identified as trackable or not trackable?
        """
        is_trackable = ObjectTracker.is_trackable
        self.assertFalse(is_trackable(None))
        self.assertFalse(is_trackable(0))
        self.assertFalse(is_trackable('foo'))
        
        foo = objects.Foo()
        self.assertTrue(is_trackable(foo))
        self.assertFalse(is_trackable(foo.do_sum))

    def test_get_object(self):
        """ Can we get a tracked object by ID?
        """
        tracker = ObjectTracker()
        foo = objects.Foo()
        foo_id = tracker.track(foo)
        self.assertTrue(tracker.is_tracked(foo))
        self.assertEqual(tracker.get_object(foo_id), foo)
        
        other_id = tracker.get_id(foo)
        self.assertEqual(other_id, foo_id)
    
    def test_gc_cleanup(self):
        """ Does the tracker clean up when an object is garbage collected?
        """
        tracker = ObjectTracker()
        foo = objects.Foo()
        foo_id = tracker.track(foo)
        self.assertTrue(tracker.is_tracked(foo))
        
        del foo
        gc.collect()
        self.assertFalse(tracker.get_object(foo_id))
        

if __name__ == '__main__':
    unittest.main()
