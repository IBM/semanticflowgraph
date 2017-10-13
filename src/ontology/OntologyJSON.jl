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
function annotation_from_json(doc::Associative, pres::Presentation)::Annotation
  name = AnnotationID(doc["language"], doc["package"], doc["id"])
  lang = Dict{Symbol,Any}(
    Symbol(key) => doc[key] for key in language_keys if haskey(doc, key)
  )
  definition = expr_from_json(doc["definition"], pres)
  if doc["kind"] == "object"
    ObAnnotation(name, lang, definition)
  elseif doc["kind"] == "morphism"
    HomAnnotation(name, lang, definition)
  else
    error("Invalid kind of annotation: $(doc["kind"])")
  end
end

""" Load compound expression from S-expression encoded in JSON.

FIXME: Belongs in `Catlab.Present`? Compare with `Catlab.Syntax.parse_json()`.
"""
function expr_from_json(sexpr::Vector, pres::Presentation)
  name = Symbol(sexpr[1])
  args = if name in (:Ob, :Hom)
    [ sexpr[2]::String ; [ expr_from_json(x, pres) for x in sexpr[3:end] ]]
  else
    [ expr_from_json(x, pres) for x in sexpr[2:end] ]
  end
  invoke_term(Monocl, name, args...)
end
function expr_from_json(sexpr::String, pres::Presentation)
  generator(pres, sexpr)
end

end
