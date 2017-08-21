module Annotations
export Annotation, AnnotationID, ObAnnotation, HomAnnotation,
  annotation_from_json

using AutoHashEquals

using Catlab
using ..Doctrine

# Data types
############

""" Semantic annotation of computer program.

This type is agnostic to the programming language of the computer program. All
language-specific information is stored in the `language` dictionary.
"""
abstract type Annotation end

""" Unique identifer of annotation.
"""
@auto_hash_equals struct AnnotationID
  language::String
  package::String
  id::String
end

struct ObAnnotation <: Annotation
  name::AnnotationID
  language::Dict{Symbol,Any}
  definition::Monocl.Ob
end

struct HomAnnotation <: Annotation
  name::AnnotationID
  language::Dict{Symbol,Any}
  definition::Monocl.Hom
end

# Serialization
###############

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
