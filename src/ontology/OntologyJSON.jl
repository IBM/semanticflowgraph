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
  # Be careful about load order because:
  # - To add a morphism, the domain/codomain objects must be added
  # - To add a subobject, the domain/codomain objects must already be added
  # - To add a submorphism, the domain/codomain morphisms must already be added
  presentation = Presentation(String)
  ob_docs = filter(doc -> doc["kind"] == "type", docs)
  hom_docs = filter(doc -> doc["kind"] == "function", docs)
  for doc in ob_docs
    add_ob_generator_from_json!(presentation, doc)
  end
  for doc in ob_docs
    add_subob_generators_from_json!(presentation, doc)
  end
  for doc in hom_docs
    add_hom_generator_from_json!(presentation, doc)
  end
  for doc in hom_docs
    add_subhom_generators_from_json!(presentation, doc)
  end
  presentation
end

""" Add object from JSON document to presentation.
"""
function add_ob_generator_from_json!(pres::Presentation, doc::AbstractDict)
  ob = Ob(Monocl, doc["id"])
  add_generator!(pres, ob)
end

""" Add subobjects from JSON document to presentation.
"""
function add_subob_generators_from_json!(pres::Presentation, doc::AbstractDict)
  ob = generator(pres, doc["id"])::Monocl.Ob
  names = get(doc, "is-a", [])
  names = isa(names, AbstractString) ? [ names ] : names
  for super_name in names
    super_ob = generator(pres, super_name)::Monocl.Ob
    add_generator!(pres, SubOb(ob, super_ob))
  end
end

""" Add morphism from JSON document to presentation.
"""
function add_hom_generator_from_json!(pres::Presentation, doc::AbstractDict)
  dom_ob = domain_ob_from_json(pres, doc["inputs"])
  codom_ob = domain_ob_from_json(pres, doc["outputs"])
  hom = Hom(doc["id"], dom_ob, codom_ob)
  add_generator!(pres, hom)
end

""" Add submorphisms from JSON document to presentation.
"""
function add_subhom_generators_from_json!(pres::Presentation, doc::AbstractDict)
  hom = generator(pres, doc["id"])::Monocl.Hom
  names = get(doc, "is-a", [])
  names = isa(names, AbstractString) ? [ names ] : names
  for super_name in names
    super_hom = generator(pres, super_name)::Monocl.Hom
    # FIXME: Do basic type inference to check these subobject relations hold.
    subob_dom = SubOb(dom(hom), dom(super_hom))
    subob_codom = SubOb(codom(hom), codom(super_hom))
    add_generator!(pres, SubHom(hom, super_hom, subob_dom, subob_codom))
  end
end

function domain_ob_from_json(pres::Presentation, docs)::Monocl.Ob
  if isempty(docs)
    munit(Monocl.Ob)
  else
    otimes([ generator(pres, doc["type"]) for doc in docs ])
  end
end

# Annotations
#############

const language_keys = [
  "class", "function", "method", "inputs", "outputs", "slots",
]

""" Load annotation from JSON document.
"""
function annotation_from_json(doc::AbstractDict, load_ref::Function)::Annotation
  parse_def = sexpr -> parse_json_sexpr(Monocl, sexpr;
    symbols=false, parse_head=parse_json_sexpr_term, parse_reference=load_ref)
  name = AnnotationID(doc["language"], doc["package"], doc["id"])
  lang = Dict{Symbol,Any}(
    Symbol(key) => doc[key] for key in language_keys if haskey(doc, key)
  )
  definition = parse_def(doc["definition"])
  if doc["kind"] == "type"
    slots = [ parse_def(slot["definition"]) for slot in get(doc, "slots", []) ]
    ObAnnotation(name, lang, definition, slots)
  elseif doc["kind"] == "function"
    HomAnnotation(name, lang, definition)
  else
    error("Invalid kind of annotation: $(doc["kind"])")
  end
end
function annotation_from_json(doc::AbstractDict, pres::Presentation)
  annotation_from_json(doc, name -> generator(pres, name))
end

""" Replace term names (S-exp head) in JSON S-expression.

Translates PLT terminology into category theory terminology.
"""
function parse_json_sexpr_term(x::String)
  get(json_sexpr_term_table, x, x)
end

const json_sexpr_term_table = Dict(
  "Type" => "Ob",
  "Function" => "Hom",
  "Subtype" => "SubOb",
  "Subfunction" => "SubHom",
  "product" => "otimes",
  "unit" => "munit",
  "swap" => "braid",
  "copy" => "mcopy",
  "apply" => "pair",
)

end
