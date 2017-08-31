module OntologyDBs
export OntologyDB, OntologyError, concept, concepts, annotation, annotations,
  load_ontology_file, load_concepts, load_annotation, load_annotations

using DataStructures: OrderedDict
import JSON

using Catlab
using ..Ontology

# FIXME: Store these somewhere else?
const default_db_url = "https://d393c3b5-9979-4183-98f4-7537a5de15f5-bluemix.cloudant.com"
const default_db_name = "data-science-ontology"

# Data types
############

""" Ontology database, containing concepts and annotations.
"""
mutable struct OntologyDB
  url::String
  db::String
  concepts::Presentation
  annotations::OrderedDict{String,Annotation}
  
  function OntologyDB(; url=default_db_url, db=default_db_name)
    new(url, db, Presentation(), OrderedDict{String,Annotation}())
  end
end

struct OntologyError <: Exception
  message::String
end

concepts(db::OntologyDB) = db.concepts
annotations(db::OntologyDB) = values(db.annotations)

function concept(db::OntologyDB, name::String)
  if !has_generator(db.concepts, name)
    throw(OntologyError("No concept named '$name'"))
  end
  generator(db.concepts, name)
end

function annotation(db::OntologyDB, id::String)
  if !haskey(db.annotations, id)
    throw(OntologyError("No annotation named '$id'"))
  end
  db.annotations[id]
end
annotation(db::OntologyDB, id::AnnotationID) = annotation(db, db_id(id))

db_id(id::AnnotationID) = "annotation/$(id.language)/$(id.package)/$(id.id)"

# Local file
############

""" Load concepts/annotations from a local JSON file.
"""
function load_ontology_file(db::OntologyDB, filename::String)
  open(filename) do file
    load_ontology_file(db, file)
  end
end
function load_ontology_file(db::OntologyDB, io::IO)
  load_documents(db, JSON.parse(io)::Vector)
end

""" Load concepts/annotations from a list of JSON documents.
"""
function load_documents(db::OntologyDB, docs)
  concept_docs = filter(doc -> doc["schema"] == "concept", docs)
  if !isempty(concept_docs)
    db.concepts = presentation_from_json(concept_docs)
  end
  
  annotation_docs = filter(doc -> doc["schema"] == "annotation", docs)
  for doc in annotation_docs
    db.annotation[doc["_id"]] = annotation_from_json(doc, db.concepts)
  end
end

# Remote database
#################

""" Load all concepts in ontology from remote database.

Note the concepts cannot be loaded incrementally because concepts may depend
upon each other in complicated ways.
"""
function load_concepts(db::OntologyDB)
  query = Dict("schema" => "concept")
  docs = CouchDB.find(db.url, db.db, query)
  db.concepts = presentation_from_json(docs)
end

""" Load annotations in ontology from remote database.
"""
function load_annotations(db::OntologyDB; language=nothing, package=nothing)
  query = Dict("schema" => "annotation")
  if language != nothing
    query["language"] = language
  end
  if package != nothing
    query["package"] = package
  end
  docs = CouchDB.find(db.url, db.db, query)
  for doc in docs
    db.annotations[doc["_id"]] = annotation_from_json(doc, db.concepts)
  end
end

""" Load single annotation from remote database, if it's not available locally.
"""
function load_annotation(db::OntologyDB, id::String)::Annotation
  if haskey(db.annotations, id)
    return db.annotations[id]
  end
  
  doc = CouchDB.get(db.url, db.db, id)
  if get(doc, "error", nothing) == "not_found"
    throw(OntologyError("No annotation named '$id'"))
  end
  db.annotations[doc["_id"]] = annotation_from_json(doc, db.concepts)
end
load_annotation(db::OntologyDB, id::AnnotationID) = load_annotation(db, db_id(id))

# CouchDB client
################

module CouchDB
  import JSON, HTTP

  """ CouchDB endpoint: /{db}/{docid}
  """
  function get(url::String, db::String, docid::String)
    response = HTTP.get("$url/$db/$(HTTP.escape(docid))")
    JSON.parse(response.body)
  end

  """ CouchDB endpoint: /{db}/_find
  """
  function find(url::String, db::String, selector::Associative; kwargs...)
    request = Dict{Symbol,Any}(:selector => selector)
    merge!(request, Dict(kwargs))
    body = JSON.json(request)
    
    response = HTTP.post("$url/$db/_find", body=body)   
    body = JSON.parse(response.body)
    body["docs"]
  end
  
end

end
