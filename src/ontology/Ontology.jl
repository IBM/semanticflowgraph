module Ontology
export Annotation, AnnotationID, ObAnnotation, HomAnnotation

using AutoHashEquals
using Reexport

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

# Modules
#########

include("OntologyJSON.jl")
include("OntologyDBs.jl")

@reexport using .OntologyJSON
@reexport using .OntologyDBs

end
