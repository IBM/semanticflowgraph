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
export wiring_diagram_to_rdf

using Parameters
using Serd
using Catlab
using Catlab.WiringDiagrams, Catlab.WiringDiagrams.WiringDiagramSerialization

using ..RDFUtils

const R = RDF.Resource

# Configuration
###############

default_box_rdf_node(name::String) = RDF.Blank(name)
default_port_rdf_node(name::String, port::String) = RDF.Blank("$name:$port")
default_wire_rdf_node(name::String) = RDF.Blank(name)

function default_value_to_rdf(node::RDF.Node, value)
  if value == nothing
    RDF.Statement[]
  else
    [ RDF.Triple(node, R("monocl","value"), RDF.Literal(string(value))) ]
  end
end

@with_kw struct RDFConfig
  box_rdf_node::Function = default_box_rdf_node
  port_rdf_node::Function = default_port_rdf_node
  wire_rdf_node::Function = default_wire_rdf_node
  box_value_to_rdf::Function = default_value_to_rdf
  port_value_to_rdf::Function = default_value_to_rdf
  wire_value_to_rdf::Function = default_value_to_rdf
end

# RDF
#####

""" Translate wiring diagram to RDF, possibly as a named graph.
"""
function wiring_diagram_to_rdf(diagram::WiringDiagram; kw...)
  config = RDFConfig(; kw...)
  node, stmts = box_to_rdf(config, diagram, Int[])
  stmts
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
  port_rdf_node = port::Port -> config.port_rdf_node(
    box_id(diagram, [path; port.box]),
    port_name(diagram, port)
  )
  for (i, wire) in enumerate(wires(diagram))
    wire_node = config.wire_rdf_node(wire_id(path, i))
    src_node = port_rdf_node(wire.source)
    tgt_node = port_rdf_node(wire.target)
    append!(stmts, [
      RDF.Triple(node, R("monocl","hasWire"), wire_node),
      RDF.Triple(wire_node, R("rdf","type"), R("monocl","Wire")),
      RDF.Triple(wire_node, R("monocl","source"), src_node),
      RDF.Triple(wire_node, R("monocl","target"), tgt_node),
      RDF.Triple(src_node, R("monocl","wire"), tgt_node),
    ])
    append!(stmts, config.wire_value_to_rdf(wire_node, wire.value))
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
    [
      [ RDF.Triple(cell, R("rdf","type"), R("monocl","Port")) ];
      config.port_value_to_rdf(cell, port_value);
    ]
  end
end

end
