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
  load_concepts, load_annotation, load_annotations, load_ontology_file

using DataStructures: OrderedDict
import JSON, HTTP

using Catlab
using ..Ontology

const api_url_default = "https://api.datascienceontology.org"

# Data types
############

""" Ontology database, containing concepts and annotations.
"""
mutable struct OntologyDB
  api_url::String
  concepts::Presentation
  concept_docs::OrderedDict{String,AbstractDict}
  annotations::OrderedDict{String,Annotation}
  annotation_docs::OrderedDict{String,AbstractDict}
  
  function OntologyDB(api_url)
    new(api_url, Presentation(String), OrderedDict(), OrderedDict(), OrderedDict())
  end
end
OntologyDB() = OntologyDB(api_url_default)

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
  load_reference = id -> concept(db, id)
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

""" Load all concepts in ontology from remote database.
"""
function load_concepts(db::OntologyDB; ids=nothing)
  load_documents(db, api_get(db, "/concepts"))
end

""" Load annotations in ontology from remote database.
"""
function load_annotations(db::OntologyDB; language=nothing, package=nothing)
  endpoint = if isnothing(language)
    "/annotations"
  elseif isnothing(package)
    "/annotations/$language"
  else
    "/annotations/$language/$package"
  end
  load_documents(db, api_get(db, endpoint))
end

""" Load single annotation from remote database, if it's not already loaded.
"""
function load_annotation(db::OntologyDB, id)::Annotation
  if has_annotation(db, id)
    return annotation(db, id)
  end
  doc = try
    api_get(db, "/$(annotation_document_id(id))")
  catch err
    if isa(err, HTTP.StatusError) && err.status == 404
      throw(OntologyError("No annotation named '$id'"))
    end
    rethrow()
  end
  load_documents(db, [doc])
  annotation(db, id)
end

# REST API client
#################

function api_get(api_url::String, endpoint::String)
  response = HTTP.get(string(api_url, endpoint))
  JSON.parse(String(response.body), dicttype=OrderedDict)
end

api_get(db::OntologyDB, endpoint::String) = api_get(db.api_url, endpoint)

end
