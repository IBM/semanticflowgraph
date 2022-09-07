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

module Ontology
export Annotation, AnnotationID, ObAnnotation, HomAnnotation

using Reexport
using StructEquality

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
@struct_hash_equal struct AnnotationID
  language::String
  package::String
  id::String
end

struct ObAnnotation <: Annotation
  name::AnnotationID
  language::Dict{Symbol,Any}
  definition::Monocl.Ob
  slots::Vector{Monocl.Hom}
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
include("rdf/OntologyRDF.jl")

@reexport using .OntologyJSON
@reexport using .OntologyDBs
@reexport using .OntologyRDF

end
