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

module RDFUtils
export owl_list, owl_inputs_outputs, rdfs_labels

using Serd

const R = RDF.Resource


""" Convert sequence of RDF nodes into an OWL list.

OWL doesn't officially support lists, but it's straightforward to implement a
singly linked list (chain of cons cells). See the `list` schema for more info.

Note: We don't use the builtin RDF List because OWL doesn't support RDF Lists.
"""
function owl_list(cell_content::Function, cell_node::Function, n::Int;
    index::Bool=false)
  stmts = RDF.Statement[]
  for i in 1:n
    cell = cell_node(i)
    rest = cell_node(i+1)
    append!(stmts, [
      [ RDF.Triple(cell, R("rdf","type"), R("list","OWLList")) ];
      cell_content(cell, i);
      [ RDF.Triple(cell, R("list","hasNext"), rest) ];
      index ?
        [ RDF.Triple(cell, R("list","index"), RDF.Literal(i)) ] : [];
    ])
  end
  nil = cell_node(n+1)
  push!(stmts, RDF.Triple(nil, R("rdf","type"), R("list","EmptyList")))
  stmts
end

""" Create RDF/OWL lists for the inputs and outputs of a function-like node.
"""
function owl_inputs_outputs(cell_content::Function, node::RDF.Node,
    cell_node::Function, nin::Int, nout::Int; index::Bool=false)
  input_cell = i -> cell_node("in$i")
  output_cell = i -> cell_node("out$i")
  RDF.Statement[
    [
      RDF.Triple(node, R("monocl","inputs"), input_cell(1)),
      RDF.Triple(node, R("monocl","outputs"), output_cell(1)),
    ];
    [ RDF.Triple(node, R("monocl","hasInput"), input_cell(i)) for i in 1:nin ];
    [ RDF.Triple(node, R("monocl","hasOutput"), output_cell(i)) for i in 1:nout ];
    owl_list(input_cell, nin, index=index) do cell, i
      cell_content(cell, true, i)
    end;
    owl_list(output_cell, nout, index=index) do cell, i
      cell_content(cell, false, i)
    end;
  ]
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
