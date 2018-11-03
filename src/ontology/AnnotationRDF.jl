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

module AnnotationRDF
export annotation_to_rdf, annotation_rdf_node

using Serd
using Catlab, Catlab.Diagram.Wiring

using ...Doctrine, ...Ontology
using ..WiringRDF
using ..ConceptRDF: generator_rdf_node

# Constants
###########

const language_properties = Dict(
  :class => "code-class",
  :function => "code-function",
  :method => "code-method",
)

rdf_type(::Type{ObAnnotation}) = "ObAnnotation"
rdf_type(::Type{HomAnnotation}) = "HomAnnotation"

# RDF
#####

""" Generate RDF for annnotation.
"""
function annotation_to_rdf(annotation::Annotation, prefix::RDF.Prefix)
  node = annotation_rdf_node(annotation, prefix)
  stmts = RDF.Statement[
    RDF.Triple(
      node,
      RDF.Resource("rdf","type"),
      RDF.Resource("monocl", rdf_type(typeof(annotation)))
    )
  ]
  append!(stmts, annotation_language_to_rdf(annotation, node, prefix))
  
  if head(annotation.definition) == :generator
    push!(stmts, RDF.Triple(
      node,
      RDF.Resource("monocl","code-meaning"),
      generator_rdf_node(annotation.definition, prefix)
    ))
  end
  if isa(annotation, HomAnnotation)
    diagram = to_wiring_diagram(annotation.definition)
    graph = RDF.Resource(prefix.name, "$(node.name):diagram")
    push!(stmts, RDF.Triple(node, RDF.Resource("monocl","code-meaning"), graph))
    append!(stmts, annotation_diagram_to_rdf(diagram, graph, prefix))
  end
  
  return stmts
end

""" Generate RDF for language-specific data in annotation.
"""
function annotation_language_to_rdf(
    annotation::Annotation, node::RDF.Node, prefix::RDF.Prefix)
  stmts = RDF.Statement[
    RDF.Triple(
      node,
      RDF.Resource("monocl","code-language"),
      RDF.Literal(annotation.name.language)
    ),
    RDF.Triple(
      node,
      RDF.Resource("monocl","code-package"),
      RDF.Literal(annotation.name.package)
    ),
  ]
  for key in intersect(keys(language_properties), keys(annotation.language))
    value = annotation.language[key]
    values = isa(value, AbstractArray) ? value : [ value ]
    append!(stmts, [ RDF.Triple(
      node,
      RDF.Resource("monocl", language_properties[key]),
      RDF.Literal(value)
    ) for value in values ])
  end
  stmts
end

""" Generate RDF for annotation wiring diagram.
"""
function annotation_diagram_to_rdf(
    diagram::WiringDiagram, graph::RDF.Node, prefix::RDF.Prefix)
  wiring_diagram_to_rdf(diagram;
    graph = graph,
    box_value_to_rdf = (args...) -> annotation_box_to_rdf(args..., prefix),
    port_value_to_rdf = (args...) -> annotation_port_to_rdf(args..., prefix))
end

function annotation_box_to_rdf(expr::Monocl.Hom, node::RDF.Node,
                               graph::RDF.Node, prefix::RDF.Prefix)
  type_node = if head(expr) == :generator
    generator_rdf_node(expr, prefix)
  else
    # FIXME: Discards constructor parameters when head == :construct.
    RDF.Resource("monocl", string(head(expr)))
  end
  [ RDF.Quad(node, RDF.Resource("cat","type"), type_node, graph) ]
end

function annotation_port_to_rdf(expr::Monocl.Ob, node::RDF.Node,
                                graph::RDF.Node, prefix::RDF.Prefix)
  type_node = generator_rdf_node(expr, prefix)
  [ RDF.Quad(node, RDF.Resource("cat","type"), type_node, graph) ]
end

""" Create RDF node for annotation.
"""
function annotation_rdf_node(annotation::Annotation, prefix::RDF.Prefix)::RDF.Node
  name = annotation.name
  node_name = join(["annotation", name.language, name.package, name.id], ":")
  RDF.Resource(prefix.name, node_name)
end

end
