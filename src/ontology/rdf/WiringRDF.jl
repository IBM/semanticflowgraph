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

module WiringRDF
export wiring_diagram_to_rdf, semantic_graph_to_rdf

using Compat
using Serd

using Catlab
using Catlab.WiringDiagrams, Catlab.WiringDiagrams.WiringDiagramSerialization
using ...Doctrine
using ..RDFUtils

const R = RDF.Resource

# Configuration
###############

default_box_rdf_node(box::String) = RDF.Blank(box)
default_port_rdf_node(box::String, port::String) = RDF.Blank("$box:$port")
default_wire_rdf_node(wire::String) = RDF.Blank(wire)

function default_value_to_rdf(node::RDF.Node, value)
  if isnothing(value)
    RDF.Statement[]
  else
    [ RDF.Triple(node, R("monocl","value"), RDF.Literal(string(value))) ]
  end
end

@Base.kwdef struct RDFConfig
  box_rdf_node::Function = default_box_rdf_node
  port_rdf_node::Function = default_port_rdf_node
  wire_rdf_node::Function = default_wire_rdf_node
  box_value_to_rdf::Function = default_value_to_rdf
  port_value_to_rdf::Function = default_value_to_rdf
  wire_value_to_rdf::Function = default_value_to_rdf
  include_provenance::Bool = false
end

# Wiring diagrams
#################

""" Convert a wiring diagram to RDF.
"""
function wiring_diagram_to_rdf(diagram::WiringDiagram; kw...)
  config = RDFConfig(; kw...)
  box_to_rdf(config, diagram, Int[])
end

function box_to_rdf(config::RDFConfig, diagram::WiringDiagram, path::Vector{Int})
  node = config.box_rdf_node(box_id(path))
  stmts = RDF.Statement[
    [ RDF.Triple(node, R("rdf","type"), R("monocl","WiringDiagram")) ];
    ports_to_rdf(config, diagram, path);
  ]

  # Add RDF for boxes.
  for v in box_ids(diagram)
    box_node, box_stmts = box_to_rdf(config, box(diagram, v), [path; v])
    push!(stmts, RDF.Triple(node, R("monocl","hasBox"), box_node))
    append!(stmts, box_stmts)
  end

  # Add RDF for wires.
  box_rdf_node = port::Port -> config.box_rdf_node(
    box_id(diagram, [path; port.box]))
  port_rdf_node = port::Port -> config.port_rdf_node(
    box_id(diagram, [path; port.box]), port_name(diagram, port))
  
  for (i, wire) in enumerate(wires(diagram))
    wire_node = config.wire_rdf_node(wire_id(path, i))
    src_port_node = port_rdf_node(wire.source)
    tgt_port_node = port_rdf_node(wire.target)
    append!(stmts, [
      RDF.Triple(node, R("monocl","hasWire"), wire_node),
      RDF.Triple(wire_node, R("rdf","type"), R("monocl","Wire")),
      RDF.Triple(wire_node, R("monocl","source"), src_port_node),
      RDF.Triple(wire_node, R("monocl","target"), tgt_port_node),
      RDF.Triple(src_port_node, R("monocl","wire"), tgt_port_node),
    ])
    append!(stmts, config.wire_value_to_rdf(wire_node, wire.value))
    if config.include_provenance
      src_box_node = box_rdf_node(wire.source)
      tgt_box_node = box_rdf_node(wire.target)
      append!(stmts, [
        RDF.Triple(tgt_box_node, R("prov","wasInformedBy"), src_box_node),
        RDF.Triple(tgt_port_node, R("prov","wasDerivedFrom"), src_port_node),
      ])
    end
  end

  (node, stmts)
end

function box_to_rdf(config::RDFConfig, box::Box, path::Vector{Int})
  node = config.box_rdf_node(box_id(path))
  stmts = RDF.Statement[
    [ RDF.Triple(node, R("rdf","type"), R("monocl","Box")) ];
    config.box_value_to_rdf(node, box.value);
    ports_to_rdf(config, box, path);
  ]
  (node, stmts)
end

function ports_to_rdf(config::RDFConfig, box::AbstractBox, path::Vector{Int})
  name = box_id(path)
  node = config.box_rdf_node(name)
  port_node = port -> config.port_rdf_node(name, port)
  inputs, outputs = input_ports(box), output_ports(box)
  nin, nout = length(inputs), length(outputs)
  owl_inputs_outputs(node, port_node, nin, nout, index=true) do cell, is_input, i
    port_value = (is_input ? inputs : outputs)[i]
    RDF.Statement[
      [ RDF.Triple(cell, R("rdf","type"), R("monocl","Port")) ];
      config.port_value_to_rdf(cell, port_value);
      if config.include_provenance
        if is_input
          [ RDF.Triple(node, R("prov","used"), cell) ]
        else
          [ RDF.Triple(cell, R("prov","wasGeneratedBy"), node) ]
        end
      else [] end;
    ]
  end
end

# Semantic flow graphs
######################

""" Convert a semantic flow graph to RDF.
"""
function semantic_graph_to_rdf(diagram::WiringDiagram, concept_rdf_node::Function;
    include_provenance::Bool=false, kw...)

  function box_expr_to_rdf(node::RDF.Node, expr::Monocl.Hom)
    concept = if head(expr) == :generator
      concept_rdf_node(expr)
    elseif head(expr) == :construct
      concept_rdf_node(codom(expr))
    else
      error("Cannot serialize Monocl morphism of type: ", head(expr))
    end
    RDF.Statement[
      [ RDF.Triple(node, R("monocl","isConcept"), concept) ];
      include_provenance && head(expr) == :generator ?
        [ RDF.Triple(node, R("rdf","type"), concept) ] : [];
    ]
  end

  function port_expr_to_rdf(node::RDF.Node, expr::Monocl.Ob)
    concept = concept_rdf_node(expr)
    RDF.Statement[
      [ RDF.Triple(node, R("monocl","isConcept"), concept) ];
      include_provenance ?
        [ RDF.Triple(node, R("rdf","type"), concept) ] : [];
    ]
  end

  wiring_diagram_to_rdf(diagram;
    box_value_to_rdf = box_expr_to_rdf,
    port_value_to_rdf = port_expr_to_rdf,
    include_provenance = include_provenance,
    kw...)
end

end
