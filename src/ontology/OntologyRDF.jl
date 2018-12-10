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

const R = RDF.Resource

# RDF Utilties
##############

""" Convert sequence of RDF nodes into an OWL list.

OWL doesn't officially support lists, but it's straightforward to implement a
singly linked list (chain of cons cells).

Note: We don't use the builtin RDF List because OWL doesn't support RDF Lists.
"""
function owl_list(nodes::Vector{<:RDF.Node}, cell_node::Function; graph=nothing)
  stmts = RDF.Statement[]
  for (i, node) in enumerate(nodes)
    cell = cell_node(i)
    rest = cell_node(i+1)
    append!(stmts, [
      RDF.Edge(cell, R("rdf","type"), R("list","OWLList"), graph),
      RDF.Edge(cell, R("list","hasContent"), node, graph),
      RDF.Edge(cell, R("list","hasNext"), rest, graph),
    ])
  end
  nil = cell_node(length(nodes) + 1)
  push!(stmts, RDF.Edge(nil, R("rdf","type"), R("list","EmptyList"), graph))
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
