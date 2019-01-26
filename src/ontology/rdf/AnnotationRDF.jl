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
using ..ConceptRDF: generator_rdf_node
using ..WiringRDF

const R = RDF.Resource

# Constants
###########

const language_properties = Dict(
  :class => "annotatedClass",
  :function => "annotatedFunction",
  :method => "annotatedMethod",
)

# RDF
#####

""" Convert annotation into triples for RDF/OWL ontology.
"""
function annotation_to_rdf(annotation::ObAnnotation, prefix::RDF.Prefix; kw...)
  node = annotation_rdf_node(annotation, prefix)
  stmts = RDF.Statement[
    [ RDF.Triple(node, R("rdf","type"), R("monocl","TypeAnnotation")) ];
    annotation_name_to_rdf(annotation, prefix);
    annotation_language_to_rdf(annotation, prefix);
  ]

  # Definition as expression, assuming it's a basic object.
  gen_node = generator_rdf_node(annotation.definition, prefix)
  push!(stmts, RDF.Triple(node, R("monocl","codeDefinition"), gen_node))

  # Slot annotations.
  for (i, hom) in enumerate(annotation.slots)
    slot = annotation.language[:slots][i]["slot"]
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
                           include_provenance::Bool=true,
                           include_wiring_diagrams::Bool=true)
  node = annotation_rdf_node(annotation, prefix)
  stmts = RDF.Statement[
    [ RDF.Triple(node, R("rdf","type"), R("monocl","FunctionAnnotation")) ];
    annotation_name_to_rdf(annotation, prefix);
    annotation_language_to_rdf(annotation, prefix);
    annotation_domain_to_rdf(annotation, prefix);
  ]

  # Definition as expression, if it's a basic morphism.
  if head(annotation.definition) == :generator
    gen_node = generator_rdf_node(annotation.definition, prefix)
    push!(stmts, RDF.Triple(node, R("monocl","codeDefinition"), gen_node))
  end

  # Definition as wiring diagram.
  if include_wiring_diagrams
    diagram = to_wiring_diagram(annotation.definition)
    diagram_name = "$(node.name):diagram"
    root_node, diagram_stmts = semantic_graph_to_rdf(diagram,
      expr -> generator_rdf_node(expr, prefix);
      box_rdf_node = box -> R(prefix.name, "$diagram_name:$box"),
      port_rdf_node = (box, port) -> R(prefix.name, "$diagram_name:$box:$port"),
      wire_rdf_node = wire -> R(prefix.name, "$diagram_name:$wire"),
      include_provenance = include_provenance)
    append!(stmts, [
      [ RDF.Triple(node, R("monocl","codeDefinition"), root_node) ];
      diagram_stmts;
    ])
  end

  stmts
end

""" Convert annotation's name to RDF.
"""
function annotation_name_to_rdf(annotation::Annotation, prefix::RDF.Prefix)
  node = annotation_rdf_node(annotation, prefix)
  name = annotation.name
  RDF.Statement[
    RDF.Triple(node, R("monocl","annotatedLanguage"), RDF.Literal(name.language)),
    RDF.Triple(node, R("monocl","annotatedPackage"), RDF.Literal(name.package)),
    RDF.Triple(node, R("monocl","id"), RDF.Literal(name.id)),
  ]
end

""" Convert annotation's language-specific data to RDF.
"""
function annotation_language_to_rdf(annotation::Annotation, prefix::RDF.Prefix)
  node = annotation_rdf_node(annotation, prefix)
  stmts = RDF.Statement[]
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
  cell_node = name -> R(prefix.name, "$(node.name):$name")
  inputs, outputs = annotation.language[:inputs], annotation.language[:outputs]
  nin, nout = length(inputs), length(outputs)
  owl_inputs_outputs(node, cell_node, nin, nout, index=true) do cell, is_input, i
    data = (is_input ? inputs : outputs)[i]
    slot = data["slot"]
    [ RDF.Triple(cell, R("monocl","codeSlot"), RDF.Literal(slot)) ]
  end
end

""" Create RDF node for annotation.
"""
function annotation_rdf_node(annotation::Annotation, prefix::RDF.Prefix)::RDF.Node
  name = annotation.name
  node_name = join([name.language, name.package, name.id], ":")
  R(prefix.name, node_name)
end

end
