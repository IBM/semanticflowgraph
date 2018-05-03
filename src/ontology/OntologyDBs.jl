# Copyright 2018 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module OntologyDBs
export OntologyDB, OntologyError,
  concept, concept_document, concepts, has_concept,
  annotation, annotation_document, annotations, has_annotation,
  load_concept, load_concepts, load_annotation, load_annotations,
  load_ontology_file

using DataStructures: OrderedDict
import JSON

using Catlab
using ..Ontology

# FIXME: This default configuration should not be hard-coded here.
const default_config = Dict(
  :database_url => "https://d393c3b5-9979-4183-98f4-7537a5de15f5-bluemix.cloudant.com",
  :database_name => "data-science-ontology",
)

# Data types
############

""" Ontology database, containing concepts and annotations.
"""
mutable struct OntologyDB
  config::Dict{Symbol,Any}
  concepts::Presentation
  concept_docs::OrderedDict{String,Associative}
  annotations::OrderedDict{String,Annotation}
  annotation_docs::OrderedDict{String,Associative}
  
  function OntologyDB(config)
    new(config, Presentation(String), OrderedDict(), OrderedDict(), OrderedDict())
  end
end
OntologyDB(; kw...) = OntologyDB(merge(default_config, Dict(kw)))

struct OntologyError <: Exception
  message::String
end

# Ontology accessors
####################

function concept(db::OntologyDB, id::String)
  if !has_generator(db.concepts, id)
    throw(OntologyError("No concept named '$id'"))
  end
  generator(db.concepts, id)
end

concept_document(db::OntologyDB, id::String) = db.concept_docs[id]
has_concept(db::OntologyDB, id::String) = has_generator(db.concepts, id)

concepts(db::OntologyDB) = db.concepts
concepts(db::OntologyDB, ids) = [ concept(db, id) for id in ids ]

function annotation(db::OntologyDB, id)
  doc_id = annotation_document_id(id)
  if !haskey(db.annotations, doc_id)
    throw(OntologyError("No annotation named '$id'"))
  end
  db.annotations[doc_id]
end

function annotation_document(db::OntologyDB, id)
  db.annotation_docs[annotation_document_id(id)]
end

function has_annotation(db::OntologyDB, id)
  haskey(db.annotations, annotation_document_id(id))
end

annotations(db::OntologyDB) = values(db.annotations)
annotations(db::OntologyDB, ids) = [ annotation(db, id) for id in ids ]

function annotation_document_id(id::String)
  startswith(id, "annotation/") ? id : "annotation/$id"
end
function annotation_document_id(id::AnnotationID)
  join(["annotation", id.language, id.package, id.id], "/")
end

# Local file
############

""" Load concepts/annotations from a list of JSON documents.
"""
function load_documents(db::OntologyDB, docs)
  concept_docs = filter(doc -> doc["schema"] == "concept", docs)
  merge_presentation!(db.concepts, presentation_from_json(concept_docs))
  merge!(db.concept_docs, OrderedDict(doc["id"] => doc for doc in concept_docs))
  
  annotation_docs = filter(doc -> doc["schema"] == "annotation", docs)
  load_reference = id -> load_concept(db, id)
  for doc in annotation_docs
    db.annotations[doc["_id"]] = annotation_from_json(doc, load_reference)
    db.annotation_docs[doc["_id"]] = doc
  end
end

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

# Remote database
#################

""" Load concepts in ontology from remote database.
"""
function load_concepts(db::OntologyDB; ids=nothing)
  query = Dict{String,Any}("schema" => "concept")
  if ids != nothing
    query["id"] = Dict("\$in" => collect(ids))
  end
  load_documents(db, CouchDB.find(db, query))
end

""" Load single concept from remote database, if it's not already loaded.
"""
function load_concept(db::OntologyDB, id::String)
  if has_concept(db, id)
    return concept(db, id)
  end
  doc_id = "concept/$id"
  doc = CouchDB.get(db, doc_id)
  if get(doc, "error", nothing) == "not_found"
    throw(OntologyError("No concept named '$id'"))
  end
  load_documents(db, [doc])
  concept(db, id)
end

""" Load annotations in ontology from remote database.
"""
function load_annotations(db::OntologyDB; language=nothing, package=nothing)
  query = Dict{String,Any}("schema" => "annotation")
  if language != nothing
    query["language"] = language
  end
  if package != nothing
    query["package"] = package
  end
  load_documents(db, CouchDB.find(db, query))
end

""" Load single annotation from remote database, if it's not already loaded.
"""
function load_annotation(db::OntologyDB, id)::Annotation
  if has_annotation(db, id)
    return annotation(db, id)
  end
  
  doc_id = annotation_document_id(id)
  doc = CouchDB.get(db, doc_id)
  if get(doc, "error", nothing) == "not_found"
    throw(OntologyError("No annotation named '$id'"))
  end
  load_documents(db, [doc])
  annotation(db, id)
end

# CouchDB client
################

module CouchDB
  import JSON, HTTP

  """ CouchDB endpoint: /{db}/{docid}
  """
  function get(url::String, db::String, doc_id::String)
    response = HTTP.get("$url/$db/$(HTTP.escapeuri(doc_id))")
    JSON.parse(String(response.body))
  end

  """ CouchDB endpoint: /{db}/_find
  """
  function find(url::String, db::String, selector::Associative; kwargs...)
    request = Dict{Symbol,Any}(:selector => selector)
    merge!(request, Dict(kwargs))
    headers = Dict("Content-Type" => "application/json")
    body = JSON.json(request)
    
    response = HTTP.post("$url/$db/_find", headers=headers, body=body)
    body = JSON.parse(String(response.body))
    body["docs"]
  end
end


function CouchDB.get(db::OntologyDB, doc_id::String)
  conf = db.config
  CouchDB.get(conf[:database_url], conf[:database_name], doc_id)
end

function CouchDB.find(db::OntologyDB, selector::Associative; kwargs...)
  conf = db.config
  CouchDB.find(conf[:database_url], conf[:database_name], selector; kwargs...)
end

end
