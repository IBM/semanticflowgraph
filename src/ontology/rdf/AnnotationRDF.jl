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
using Catlab, Catlab.WiringDiagrams

using ...Doctrine, ...Ontology
using ..RDFUtils
using ..ConceptRDF: generator_rdf_node, function_domain_to_rdf
using ..WiringRDF

const R = RDF.Resource

# Constants
###########

const language_properties = Dict(
  :class => "codeClass",
  :function => "codeFunction",
  :method => "codeMethod",
)

# RDF
#####

""" Convert annotation into triples for RDF/OWL ontology.
"""
function annotation_to_rdf(annotation::ObAnnotation, prefix::RDF.Prefix; kw...)
  # Annotation RDF node.
  node = annotation_rdf_node(annotation, prefix)
  stmts = RDF.Statement[
    RDF.Triple(node, R("rdf","type"), R("monocl","TypeAnnotation"))
  ]

  # Language-specific data.
  append!(stmts, annotation_language_to_rdf(annotation, prefix))

  # Definition as expression, assuming it's a basic object.
  gen_node = generator_rdf_node(annotation.definition, prefix)
  push!(stmts, RDF.Triple(node, R("monocl","codeDefinition"), gen_node))

  # Slot annotations.
  for (i, hom) in enumerate(annotation.slots)
    slot = annotation.language[:slots][i]["slot"]
    #slot_name = occursin(r"^[a-zA-Z0-9_]*$", slot) ? slot : "$i"
    slot_node = R(prefix.name, "$(node.name):slot$i")
    append!(stmts, [
      RDF.Triple(node, R("monocl","annotatedSlot"), slot_node),
      RDF.Triple(slot_node, R("rdf","type"), R("monocl","SlotAnnotation")),
      RDF.Triple(slot_node, R("monocl","codeSlot"), RDF.Literal(slot)),
    ])
    if head(hom) == :generator
      gen_node = generator_rdf_node(hom, prefix)
      push!(stmts, RDF.Triple(slot_node, R("monocl","codeDefinition"), gen_node))
    end
  end

  stmts
end

function annotation_to_rdf(annotation::HomAnnotation, prefix::RDF.Prefix;
                           include_wiring_diagrams::Bool=true)
  # Annotation RDF node.
  node = annotation_rdf_node(annotation, prefix)
  stmts = RDF.Statement[
    RDF.Triple(node, R("rdf","type"), R("monocl","FunctionAnnotation"))
  ]

  # Language-specific data.
  append!(stmts, annotation_language_to_rdf(annotation, prefix))
  append!(stmts, annotation_domain_to_rdf(annotation, prefix))
  
  # Definition as expression, if it's a basic morphism.
  if head(annotation.definition) == :generator
    gen_node = generator_rdf_node(annotation.definition, prefix)
    push!(stmts, RDF.Triple(node, R("monocl","codeDefinition"), gen_node))
  end

  # Definition as wiring diagram.
  if include_wiring_diagrams
    diagram = to_wiring_diagram(annotation.definition)
    graph = R(prefix.name, "$(node.name):diagram")
    push!(stmts, RDF.Triple(node, R("monocl","codeDefinition"), graph))
    append!(stmts, annotation_diagram_to_rdf(diagram, graph, prefix))
  end

  stmts
end

""" Convert annotation's language-specific data to RDF.
"""
function annotation_language_to_rdf(annotation::Annotation, prefix::RDF.Prefix)
  node = annotation_rdf_node(annotation, prefix)
  name = annotation.name
  stmts = RDF.Statement[
    RDF.Triple(node, R("monocl","codeLanguage"), RDF.Literal(name.language)),
    RDF.Triple(node, R("monocl","codePackage"), RDF.Literal(name.package)),
  ]
  for key in intersect(keys(language_properties), keys(annotation.language))
    value = annotation.language[key]
    values = value isa AbstractArray ? value : [ value ]
    append!(stmts, [
      RDF.Triple(node, R("monocl", language_properties[key]), RDF.Literal(v))
      for v in values
    ])
  end
  stmts
end

""" Convert annotation's language-specific domain and codomain data to RDF.
"""
function annotation_domain_to_rdf(annotation::HomAnnotation, prefix::RDF.Prefix)
  node = annotation_rdf_node(annotation, prefix)
  make_cell = name -> R(prefix.name, "$(node.name):$name")
  stmts = RDF.Statement[]
  dom_nodes = map(enumerate(annotation.language[:inputs])) do (i, data)
    slot, slot_node = data["slot"], make_cell("input$i:content")
    push!(stmts,
      RDF.Triple(slot_node, R("monocl","codeSlot"), RDF.Literal(slot)))
    slot_node
  end
  codom_nodes = map(enumerate(annotation.language[:outputs])) do (i, data)
    slot, slot_node = data["slot"], make_cell("output$i:content")
    push!(stmts,
      RDF.Triple(slot_node, R("monocl","codeSlot"), RDF.Literal(slot)))
    slot_node
  end
  RDF.Statement[
    function_domain_to_rdf(node, make_cell, dom_nodes, codom_nodes, index=true);
    stmts;
  ]
end

""" Convert annotation's wiring diagram into RDF triples.
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
  gen_node = if head(expr) == :generator
    generator_rdf_node(expr, prefix)
  else
    # FIXME: Discards constructor parameters when head == :construct.
    R("monocl", string(head(expr)))
  end
  [ RDF.Quad(node, R("monocl","concept"), gen_node, graph) ]
end

function annotation_port_to_rdf(expr::Monocl.Ob, node::RDF.Node,
                                graph::RDF.Node, prefix::RDF.Prefix)
  gen_node = generator_rdf_node(expr, prefix)
  [ RDF.Quad(node, R("monocl","concept"), gen_node, graph) ]
end

""" Create RDF node for annotation.
"""
function annotation_rdf_node(annotation::Annotation, prefix::RDF.Prefix)::RDF.Node
  name = annotation.name
  node_name = join([name.language, name.package, name.id], ":")
  R(prefix.name, node_name)
end

end
