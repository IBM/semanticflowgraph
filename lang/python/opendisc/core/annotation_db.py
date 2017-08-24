from __future__ import absolute_import

import json
from pathlib2 import Path

import blitzdb
from blitzdb import fields
import sqlalchemy
from traitlets import HasTraits, Instance, default


class AnnotationDB(HasTraits):
    """ An in-memory JSON database of object and function annotations.
    
    The class contains no Python-specific annotation logic. For that,
    see `opendisc.kernel.trace.annotator`.
    """
    
    # Private traits.
    _db = Instance(blitzdb.backends.base.Backend)
    
    def load_documents(self, notes):
        """ Load annotations from an iterable of JSON documents
        (JSON-able dictionaries).
        """
        for note in notes:
            self._db.save(Annotation(note))
    
    def load_file(self, filename):
        """ Load annotations from a JSON file.
        
        Typically annotations will be loaded from a remote database but this
        method is useful for local testing.
        """
        with Path(filename).open('r') as f:
            self.load_documents(json.load(f))

    def get(self, query):
        """ Get a single document matching the query.
        
        Returns the document or None if no document matches the query.
        Raises a LookupError if there are multiple matches.
        """
        notes = list(self.filter(query))
        if len(notes) > 1:
            raise LookupError("Multiple matches for query %r" % query)
        return notes[0] if notes else None
    
    def filter(self, query):
        """ Get all documents matching the query.
        
        Returns an iterable.
        """
        blitz_query = { key: query.pop(key) for key in list(query.keys())
                        if key in Annotation.fields.keys() or 
                           key.startswith('$') }
        blitz_result = self._db.filter(Annotation, blitz_query)
        return (doc.attributes for doc in blitz_result
                if self._query_json(query, doc.attributes))
    
    # Private interface
    
    def _query_json(self, query, obj):
        """ Recursively match a JSON query against a JSON object.
        """
        # XXX: This is a quick hack to work around the BlitzDB SQL backend's 
        # requirement that query fields be indexed and unstructured.
        # When BlitzDB is improved or replaced, this function should be deleted.
        if isinstance(query, dict):
            if not isinstance(obj, dict):
                return False
            for key in query.keys():
                if key.startswith('$'):
                    raise NotImplementedError("MongoDB operators not implemented")
                if not (key in obj and self._query_json(query[key], obj[key])):
                    return False
            return True
        else:
            return query == obj
    
    # Trait initializers
    
    @default('_db')
    def _db_default(self):
        """ Create SQL backend with in-memory SQLite database.
        """
        engine = sqlalchemy.create_engine('sqlite://') 
        backend = blitzdb.backends.sql.Backend(engine) 
        backend.register(Annotation)
        backend.init_schema()
        backend.create_schema()
        return backend


class Annotation(blitzdb.Document):
    """ Partial schema for annotation.
    
    Treat this class as an implementation detail of AnnotationDB.
    """    
    language = fields.CharField(nullable=False, indexed=True)
    package = fields.CharField(nullable=False, indexed=True)
    id = fields.CharField(nullable=False, indexed=True)
    kind = fields.EnumField(['object', 'morphism'], nullable=False, indexed=True)
    
    function = fields.CharField(nullable=True, indexed=True)
    method = fields.CharField(nullable=True, indexed=True)
