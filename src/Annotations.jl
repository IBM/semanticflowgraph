module Annotations
export Annotation, AnnotationID, annotation_from_json

using AutoHashEquals

using Catlab
using ..Doctrine

# Data types
############

""" Unique identifer of annotation.
"""
@auto_hash_equals struct AnnotationID
  language::String
  package::String
  id::String
end

""" Semantic annotation of computer program.

This type is agnostic to the programming language of the computer program. All
language-specific information is stored in the `language` dictionary.
"""
struct Annotation
  name::AnnotationID
  language::Dict{Symbol,Any}
  definition::Union{Monocl.Ob,Monocl.Hom}
end

# Serialization
###############

const language_keys = [ "class", "function", "method", "domain", "codomain" ]

""" Load annotation from JSON document.
"""
function annotation_from_json(doc::Associative, concepts::Presentation)::Annotation
  name = AnnotationID(doc["language"], doc["package"], doc["id"])
  lang = Dict{Symbol,Any}(
    Symbol(key) => doc[key] for key in language_keys if haskey(doc, key)
  )
  definition = expr_from_json(doc["definition"], concepts)
  Annotation(name, lang, definition)
end

""" Load compound expression from S-expression encoded in JSON.

FIXME: Belongs in `Catlab.Present`? Compare with `Catlab.Syntax.parse_json()`.
"""
function expr_from_json(sexpr::Vector, concepts::Presentation)
  name = Symbol(sexpr[1])
  args = if name in (:Ob, :Hom)
    [ sexpr[2]::String ; [ expr_from_json(x, concepts) for x in sexpr[3:end] ]]
  else
    [ expr_from_json(x, concepts) for x in sexpr[2:end] ]
  end
  invoke_term(Monocl, name, args...)
end
function expr_from_json(sexpr::String, concepts::Presentation)
  generator(concepts, sexpr)
end

end
