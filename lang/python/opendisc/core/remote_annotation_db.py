from __future__ import absolute_import

from pathlib2 import Path

import couchdb
from traitlets import Bool, Dict, Instance, Unicode, default
from traitlets.config import Configurable, PyFileConfigLoader

import opendisc
from .annotation_db import AnnotationDB


class RemoteAnnotationDB(AnnotationDB, Configurable):
    """ An in-memory annotation database that pulls from a remote server.
    
    This local database pulls the annotation documents from a remote CouchDB
    database, but supports efficient in-memory queries to avoid repeatedly
    hitting the remote server.
    
    The class contains no Python-specific annotation logic. For that,
    see `opendisc.kernel.trace.annotator`.
    """
    
    # URL of CouchDB (or Cloudant) server hosting the annotations.
    database_url = Unicode().tag(config=True)
    
    # Name of CouchDB (or Cloudant) database containing the annotations.
    database_name = Unicode().tag(config=True)
    
    # Private traits.
    _couchdb = Instance(couchdb.Database)
    _initialized = Bool(False)
    _loaded = Dict()
    
    @classmethod
    def from_library_config(cls):
        """ Create annotation DB with library config file.
        """
        config_path = Path(opendisc.__file__).parent.joinpath("config.py")
        config = PyFileConfigLoader(str(config_path)).load_config()
        return cls(config=config)

    def load_package(self, language, package):
        """ Load annotations for the given language and package.
        
        If the package has already been loaded or does not exist in the remote
        database, then this method is a no-op (no request is made to the remote
        server). Thus, it is safe to call this method often.
        
        Returns whether annotations were load from the server.
        """
        if not self._prepare_load() or self._loaded.get((language,package), True):
            return False
        
        query = {
            "selector": {
                "schema": "annotation",
                "language": language,
                "package": package
            }
        }
        self.load_documents(self._couchdb.find(query))
        self._loaded[(language,package)] = True
        return True
    
    def load_all_packages(self, language):
        """ Load annotations for all packages for the given language.
        
        Similarly to `load_package`, if the language has already been loaded
        or does not exist in remote database, then this method is a no-op.
        
        Returns whether annotations were loaded from the server.
        """
        if not self._prepare_load() or self._loaded.get(language, True):
            return False
        
        query = {
            "selector": {
                "schema": "annotation",
                "language": language
            }
        }
        self.load_documents(self._couchdb.find(query))
        self._loaded[language] = True
        return True
    
    # Private interface
    
    def _initialize(self):
        """ Initialize the annotation database by fetching the list of
        languages and packages from the remote server.
        
        Returns whether the languages and packages were fetched.
        """
        self._loaded = {}
        if not (self.database_url and self.database_name):
            return False
        
        for row in self._couchdb.view('query/annotation_index', group=True):
            schema, language, package = row.key
            self._loaded[language] = False
            self._loaded[(language,package)] = False
        
        self._initialized = True
        return True
    
    def _prepare_load(self):
        """ Prepare to load annotations from the remote database.
        """
        return self._initialized or self._initialize()
    
    # Trait initializers

    @default("_couchdb")
    def _couchdb_default(self):
        server = couchdb.Server(self.database_url)
        db = server[self.database_name]
        return db
