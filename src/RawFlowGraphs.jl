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

""" Datatypes and IO for raw flow graphs.
"""
module RawFlowGraphs
export RawNode, RawPort, RawNodeAnnotationKind,
  FunctionAnnotation, ConstructAnnotation, SlotAnnotation,
  read_raw_graph, read_raw_graph_file

using AutoHashEquals, Parameters
import LightXML

using Catlab.Diagram

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

@with_kw struct RawNode
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  annotation_index::Nullable{Int} = Nullable()
  annotation_kind::RawNodeAnnotationKind = FunctionAnnotation
end

@with_kw struct RawPort
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  annotation_index::Nullable{Int} = Nullable()
  id::Nullable{String} = Nullable{String}()
  value::Nullable = Nullable()
end

# GraphML support.

""" Read raw flow graph from GraphML.
"""
function read_raw_graph(xdoc::LightXML.XMLDocument)
  GraphML.read_graphml(RawNode, RawPort, Void, xdoc)
end
read_raw_graph(xml::String) = read_raw_graph(LightXML.parse_string(xml))
read_raw_graph_file(args...) = read_raw_graph(LightXML.parse_file(args...))

function GraphML.convert_from_graphml_data(::Type{RawNode}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  annotation_index = Nullable{Int}(pop!(data, "annotation_index", nothing))
  annotation_kind_str = Nullable{String}(pop!(data, "annotation_kind", nothing))
  annotation_kind = isnull(annotation_kind_str) ? FunctionAnnotation :
    convert(RawNodeAnnotationKind, get(annotation_kind_str))
  RawNode(data, annotation, annotation_index, annotation_kind)
end

function GraphML.convert_from_graphml_data(::Type{RawPort}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  annotation_index = Nullable{Int}(pop!(data, "annotation_index", nothing))
  id = Nullable{String}(pop!(data, "id", nothing))
  value = pop!(data, "value", Nullable())
  RawPort(data, annotation, annotation_index, id, value)
end

# Graphviz support.

function GraphvizWiring.node_label(node::RawNode)
  # FIXME: "qual_name" is Python-specific. Standarize some of these attributes?
  lang = node.language
  get(lang, "qual_name", get(lang, "name", "?"))
end

function GraphvizWiring.edge_label(port::RawPort)
  lang = port.language
  get(lang, "qual_name", get(lang, "name", ""))
end

end
