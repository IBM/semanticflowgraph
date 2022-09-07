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

""" Datatypes and post-processing for raw flow graphs.
"""
module RawFlowGraphs
export RawNode, RawPort, RawNodeAnnotationKind,
  FunctionAnnotation, ConstructAnnotation, SlotAnnotation,
  rem_literals, rem_unused_ports

using Catlab.WiringDiagrams

@enum(RawNodeAnnotationKind,
  FunctionAnnotation = 0,
  ConstructAnnotation = 1,
  SlotAnnotation = 2)

function Base.convert(::Type{RawNodeAnnotationKind}, s::String)
  if (s == "function") FunctionAnnotation
  elseif (s == "construct") ConstructAnnotation
  elseif (s == "slot") SlotAnnotation
  else error("Unknown annotation kind \"$s\"") end
end

@Base.kwdef struct RawNode
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Union{String,Nothing} = nothing
  annotation_index::Union{Int,Nothing} = nothing
  annotation_kind::RawNodeAnnotationKind = FunctionAnnotation
end

function Base.:(==)(n1::RawNode, n2::RawNode)
  n1.language == n2.language &&
  isequal(n1.annotation, n2.annotation) &&
  isequal(n1.annotation_index, n2.annotation_index) &&
  n1.annotation_kind == n2.annotation_kind
end

@Base.kwdef struct RawPort
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Union{String,Nothing} = nothing
  annotation_index::Union{Int,Nothing} = nothing
  value::Any = nothing
end

function Base.:(==)(p1::RawPort, p2::RawPort)
  p1.language == p2.language &&
  isequal(p1.annotation, p2.annotation) &&
  isequal(p1.annotation_index, p2.annotation_index) &&
  isequal(p1.value, p2.value)
end

# Graph post-processing
#######################

""" Remove literals from raw flow graph.

Removes all nodes that are literal value constructors. (Currently, such nodes
occur in raw flow graphs for R, but not Python.)
"""
function rem_literals(d::WiringDiagram)
  nonliterals = filter(box_ids(d)) do v
    kind = get(box(d,v).value.language, "kind", "function")
    kind != "literal"
  end
  induced_subdiagram(d, nonliterals)
end

""" Remove input and output ports with no connecting wires.

This simplification is practically necessary to visualize raw flow graphs
because scientific computing functions often have dozens of keyword arguments
(which manifest as input ports).
"""
function rem_unused_ports(diagram::WiringDiagram)
  result = WiringDiagram(input_ports(diagram), output_ports(diagram))
  for v in box_ids(diagram)
    # Note: To ensure that port numbers on wires remain valid, we only remove 
    # unused ports beyond the last used port.
    b = box(diagram, v)
    last_used_input = maximum([0; [wire.target.port for wire in in_wires(diagram, v)]])
    last_used_output = maximum([0; [wire.source.port for wire in out_wires(diagram, v)]])
    unused_inputs = input_ports(b)[1:last_used_input]
    unused_outputs = output_ports(b)[1:last_used_output]
    @assert add_box!(result, Box(b.value, unused_inputs, unused_outputs)) == v
  end
  add_wires!(result, wires(diagram))
  result
end

end
