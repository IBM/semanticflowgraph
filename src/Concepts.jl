module Concepts
export presentation_from_json

using Catlab
using ..Doctrine

# Serialization
###############

""" Load Monocl ontology from JSON documents.
"""
function presentation_from_json(docs)::Presentation
  presentation = Presentation(String)
  docs = filter(doc -> doc["schema"] == "concept", docs)
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
  
  for name in get(doc, "subconcept", [])
    super_ob = Ob(Monocl, name)
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
    otimes([ generator(pres, doc["object"]) for doc in docs ])
  end
end

end
