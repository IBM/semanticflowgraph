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

# Submodules
############

include("RDFUtils.jl")
include("WiringRDF.jl")
include("ConceptRDF.jl")
include("ConceptPROV.jl")
include("AnnotationRDF.jl")

using .RDFUtils
using .WiringRDF
using .ConceptRDF
using .ConceptPROV
using .AnnotationRDF

# Ontology RDF
##############

""" Convert ontology's concepts and annotations into RDF/OWL ontology.
"""
function ontology_to_rdf(db::OntologyDB, prefix::RDF.Prefix;
                         include_provenance::Bool=true,
                         include_wiring_diagrams::Bool=true)::Vector{<:RDF.Statement}
  # Create RDF triples for concepts.
  function concept_labels(expr, node::RDF.Node)::Vector{<:RDF.Statement}
    # Add RDFS labels for concept.
    doc = concept_document(db, first(expr))
    rdfs_labels(doc, node)
  end
  stmts = presentation_to_rdf(concepts(db), prefix; extra_rdf=concept_labels)
  
  # Create RDF triples for concept hierarchy based on PROV-O.
  if include_provenance
    append!(stmts, presentation_to_prov(concepts(db), prefix))
  end
  
  # Create RDF triples for annotations.
  for note in annotations(db)
    append!(stmts, annotation_to_rdf(note, prefix;
      include_provenance=include_provenance,
      include_wiring_diagrams=include_wiring_diagrams))
    
    # Add RDFS labels for annotation.
    doc = annotation_document(db, note.name)
    node = annotation_rdf_node(note, prefix)
    append!(stmts, rdfs_labels(doc, node))
  end
  
  return stmts
end

end
