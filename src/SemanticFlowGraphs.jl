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

""" Datatypes and IO for semantic flow graphs.
"""
module SemanticFlowGraphs
export MonoclElem, read_semantic_graph, read_semantic_graph_file

using AutoHashEquals
import LightXML

using Catlab.Diagram
using ..Doctrine

""" Object in the Monocl category of elements.
"""
@auto_hash_equals struct MonoclElem
  ob::Nullable{Monocl.Ob}
  id::Nullable{String}
  value::Nullable
end
MonoclElem(ob; id=Nullable{String}(), value=Nullable()) = MonoclElem(ob, id, value)

# GraphML support.

""" Read semantic flow graph from GraphML.
"""
function read_semantic_graph(xdoc::LightXML.XMLDocument; elements::Bool=true)
  GraphML.read_graphml(
    Nullable{Monocl.Hom},
    !elements ? Nullable{Monocl.Ob} : MonoclElem,
    Void, xdoc)
end
function read_semantic_graph(xml::String; kw...)
  read_semantic_graph(LightXML.parse_string(xml); kw...)
end
function read_semantic_graph_file(args...; kw...)
  read_semantic_graph(LightXML.parse_file(args...); kw...)
end

function GraphML.convert_from_graphml_data(::Type{MonoclElem}, data::Dict)
  ob = haskey(data, "ob") ?
    parse_json_sexpr(Monocl, data["ob"]; symbols=false) : nothing
  id = get(data, "id", nothing)
  value = get(data, "value", Nullable())
  MonoclElem(ob, id, value)
end

function GraphML.convert_to_graphml_data(elem::MonoclElem)
  data = Dict{String,Any}()
  if (!isnull(elem.ob)) data["ob"] = to_json_sexpr(get(elem.ob)) end
  if (!isnull(elem.id)) data["id"] = get(elem.id) end
  if (!isnull(elem.value)) data["value"] = get(elem.value) end
  return data
end

end
