from __future__ import absolute_import

import couchdb
from traitlets import Bool, Dict, Instance, Unicode, default
from traitlets.config import Configurable

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
    database_url = Unicode("http://localhost:5984").tag(config=True)
    
    # Name of CouchDB (or Cloudant) database containing the annotations.
    database_name = Unicode("annotations").tag(config=True)
    
    # Private traits.
    _couchdb = Instance(couchdb.Database)
    _initialized = Bool(False)
    _loaded = Dict()
    
    def initialize(self):
        """ Fetch the list of languages and packages from the remote server.
        """
        self._loaded = {}
        for row in self._couchdb.view('query/annotation_index', group=True):
            schema, language, package = row.key
            self._loaded[language] = False
            self._loaded[(language,package)] = False
        
        self._initialized = True

    def load_package(self, language, package):
        """ Load annotations for the given language and package.
        
        If the package has already been loaded, then this method is a no-op.
        Returns whether annotations were fetched from the server.
        """
        self._initialized or self.initialize()
        if self._loaded.get((language,package), True):
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
        
        If the language has already been loaded, then this method is a no-op.
        Returns whether annotations were fetched from the server.
        """
        self._initialized or self.initialize()
        if self._loaded.get(language, True):
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
    
    # Trait initializers

    @default("_couchdb")
    def _couchdb_default(self):
        server = couchdb.Server(self.database_url)
        db = server[self.database_name]
        return db
