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

module OntologyRDF
export ontology_to_rdf, presentation_to_rdf, annotation_to_rdf,
  wiring_diagram_to_rdf

using Serd
using Catlab

using ..OntologyDBs

# RDF Utilties
##############

""" Convert sequence of RDF nodes into an OWL list.

OWL doesn't officially support lists, but it's straightforward to implement a
singly linked list (chain of cons cells).

Note: We don't use the builtin RDF List because OWL doesn't support RDF Lists.
"""
function owl_list(nodes::Vector{<:RDF.Node}, prefix::String; graph=nothing)
  stmts = RDF.Statement[]
  nil = RDF.Blank("$(prefix)$(length(nodes)+1)")
  for (i, node) in enumerate(nodes)
    blank = RDF.Blank("$(prefix)$i")
    rest = i < length(nodes) ? RDF.Blank("$(prefix)$(i+1)") : nil
    append!(stmts, [
      RDF.Edge(blank, RDF.Resource("list","hasContent"), node, graph),
      RDF.Edge(blank, RDF.Resource("list","hasNext"), rest, graph),
    ])
  end
  push!(stmts, RDF.Edge(
    nil, RDF.Resource("rdf","type"), RDF.Resource("list","EmptyList"), graph))
  (stmts[1].subject, stmts)
end

# Submodules
############

include("WiringRDF.jl")
include("ConceptRDF.jl")
include("AnnotationRDF.jl")

using .WiringRDF
using .ConceptRDF
using .AnnotationRDF

# Ontology RDF
##############

""" Convert ontology (both concepts and annotations) to RDF graph.
"""
function ontology_to_rdf(db::OntologyDB, prefix::RDF.Prefix;
                         include_wiring_diagrams::Bool=true)::Vector{<:RDF.Statement}
  # Create RDF statements for ontology concepts.
  function concept_labels(expr, node::RDF.Node)::Vector{<:RDF.Statement}
    # Add RDFS labels for concept.
    doc = concept_document(db, first(expr))
    rdfs_labels(doc, node)
  end
  stmts = presentation_to_rdf(concepts(db), prefix;
    extra_rdf=concept_labels, wiring_rdf=include_wiring_diagrams)
  
  # Create RDF statements for ontology annotations.
  for note in annotations(db)
    append!(stmts, annotation_to_rdf(note, prefix;
      include_wiring_diagrams=include_wiring_diagrams))
    
    # Add RDFS labels for annotation.
    doc = annotation_document(db, note.name)
    node = annotation_rdf_node(note, prefix)
    append!(stmts, rdfs_labels(doc, node))
  end
  
  return stmts
end

""" Create RDFS label/comment from document name/description.
"""
function rdfs_labels(doc, node::RDF.Node)::Vector{<:RDF.Statement}
  stmts = RDF.Statement[]
  if haskey(doc, "name")
    push!(stmts, RDF.Triple(
      node,
      RDF.Resource("rdfs", "label"),
      RDF.Literal(doc["name"])
    ))
  end
  if haskey(doc, "description")
    push!(stmts, RDF.Triple(
      node,
      RDF.Resource("rdfs", "comment"),
      RDF.Literal(doc["description"])
    ))
  end
  stmts
end

end
