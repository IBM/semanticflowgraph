from __future__ import absolute_import

from pathlib2 import Path
import unittest

from traitlets.config import PyFileConfigLoader

import opendisc
from ..remote_annotation_db import RemoteAnnotationDB


class TestRemoteAnnotationDB(unittest.TestCase):
    """ Test the in-memory annotation database connected to a remote database.
    """

    @classmethod
    def setUpClass(cls):
        config_path = Path(opendisc.__file__).parent.joinpath("config.py")
        config = PyFileConfigLoader(str(config_path)).load_config()
        cls.db = RemoteAnnotationDB(config=config)
    
    def test_load_package(self):
        """ Test loading annotations for a single package.
        """
        query = {
            "language": "python",
            "package": "pandas",
        }
        docs = list(self.db.filter(query))
        self.assertEqual(docs, [])
        
        self.assertTrue(self.db.load_package("python", "pandas"))
        docs = list(self.db.filter(query))
        self.assertGreater(len(docs), 0)
        
        ids = [ doc['id'] for doc in docs ]
        self.assertTrue('series' in ids)
        self.assertTrue('data-frame' in ids)
        
        # Don't load twice!
        self.assertFalse(self.db.load_package("python", "pandas"))
    
    def test_load_unannotated_package(self):
        """ Test that no requests are made for unannotated packages.
        """
        self.assertFalse(self.db.load_package("python", "XXX"))
