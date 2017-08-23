from __future__ import absolute_import

import json
from pathlib2 import Path

import blitzdb
from blitzdb import fields
import sqlalchemy
from traitlets import HasTraits, Dict, Instance, List, Unicode, default


class AnnotationDB(HasTraits):
    """ An in-memory JSON database of object and function annotations.
    
    This class contains no Python-specific annotation logic. For that,
    see `opendisc.kernel.trace.annotator`.
    """
    
    # Search path for package annotations.
    search_path = List(Unicode())
    
    # Private traits.
    _db = Instance(blitzdb.backends.base.Backend)
    
    def load_package(self, language, package):
        """ Load annotations for the given language and package.
        """
        paths = []
        for lang_dir in self._language_dirs(language):
            paths.extend(lang_dir.glob(package + '.json'))
            paths.extend(lang_dir.glob(package + '/**/*.json'))
        for path in paths:
            self._load_json(path)             
    
    def load_all_packages(self, language):
        """ Load annotations for all packages for the given language.
        """
        paths = []
        for lang_dir in self._language_dirs(language):
            paths.extend(lang_dir.glob('**/*.json'))
        for path in paths:
            self._load_json(path)

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
    
    def _language_dirs(self, language):
        for search_dir in map(Path, self.search_path):
            lang_dir = search_dir.joinpath(language)
            if lang_dir.is_dir():
                yield lang_dir
    
    def _load_json(self, path):
        with Path(path).open('r') as f:
            notes = json.load(f)
        for note in notes:
            self._db.save(Annotation(note))
    
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
    
    @default('search_path')
    def _search_path_default(self):
        # FIXME: Search path only works on developer installs.
        import opendisc
        pkg_dir = Path(opendisc.__file__).parent
        note_dir = pkg_dir.joinpath('..', 'annotations').resolve()
        return [ str(note_dir) ]


class Annotation(blitzdb.Document):
    """ Partial schema for annotation.
    
    Treat as an implementation detail of AnnotationDB.
    """    
    language = fields.CharField(nullable=False, indexed=True)
    package = fields.CharField(nullable=False, indexed=True)
    id = fields.CharField(nullable=False, indexed=True)
    kind = fields.EnumField(['object', 'morphism'], nullable=False, indexed=True)
    
    function = fields.CharField(nullable=True, indexed=True)
    method = fields.CharField(nullable=True, indexed=True)
