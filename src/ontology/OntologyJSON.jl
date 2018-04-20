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

module OntologyJSON
export presentation_from_json, annotation_from_json

using Catlab
using ...Doctrine
using ..Ontology

# Concepts
##########

""" Load Monocl concepts (as a presentation) from JSON documents.
"""
function presentation_from_json(docs)::Presentation
  presentation = Presentation(String)
  for doc in filter(doc -> doc["kind"] == "object", docs)
    add_ob_generator_from_json!(presentation, doc)
  end
  for doc in filter(doc -> doc["kind"] == "morphism", docs)
    add_hom_generator_from_json!(presentation, doc)
  end
  presentation
end

""" Add object from JSON document to presentation.
"""
function add_ob_generator_from_json!(pres::Presentation, doc::Associative)
  ob = Ob(Monocl, doc["id"])
  add_generator!(pres, ob)
  
  for super_name in get(doc, "subconcept", [])
    super_ob = Ob(Monocl, super_name)
    add_generator!(pres, SubOb(ob, super_ob))
  end
end

""" Add morphism from JSON document to presentation.
"""
function add_hom_generator_from_json!(pres::Presentation, doc::Associative)
  dom_ob = domain_ob_from_json(pres, doc["domain"])
  codom_ob = domain_ob_from_json(pres, doc["codomain"])
  hom = Hom(doc["id"], dom_ob, codom_ob)
  add_generator!(pres, hom)
end

function domain_ob_from_json(pres::Presentation, docs)::Monocl.Ob
  if isempty(docs)
    munit(Monocl.Ob)
  else
    otimes([ Ob(Monocl, doc["object"]) for doc in docs ])
  end
end

# Annotations
#############

const language_keys = [ "class", "function", "method", "domain", "codomain" ]

""" Load annotation from JSON document.
"""
function annotation_from_json(doc::Associative, load_ref::Function)::Annotation
  parse_def = sexpr ->
    parse_json_sexpr(Monocl, sexpr; symbols=false, parse_reference=load_ref)
  name = AnnotationID(doc["language"], doc["package"], doc["id"])
  lang = Dict{Symbol,Any}(
    Symbol(key) => doc[key] for key in language_keys if haskey(doc, key)
  )
  definition = parse_def(doc["definition"])
  if doc["kind"] == "object"
    slots = [ parse_def(slot["definition"]) for slot in get(doc, "slots", []) ]
    ObAnnotation(name, lang, definition, slots)
  elseif doc["kind"] == "morphism"
    HomAnnotation(name, lang, definition)
  else
    error("Invalid kind of annotation: $(doc["kind"])")
  end
end
function annotation_from_json(doc::Associative, pres::Presentation)
  annotation_from_json(doc, name -> generator(pres, name))
end

end
