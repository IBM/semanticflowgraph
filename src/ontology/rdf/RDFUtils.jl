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
export owl_list, rdfs_labels

using Serd

const R = RDF.Resource


""" Convert sequence of RDF nodes into an OWL list.

OWL doesn't officially support lists, but it's straightforward to implement a
singly linked list (chain of cons cells). See the `list` schema for more info.

Note: We don't use the builtin RDF List because OWL doesn't support RDF Lists.
"""
function owl_list(nodes::Vector{<:RDF.Node}, cell_node::Function; index::Bool=false)
  stmts = RDF.Statement[]
  for (i, node) in enumerate(nodes)
    cell = cell_node(i)
    rest = cell_node(i+1)
    append!(stmts, [
      RDF.Triple(cell, R("rdf","type"), R("list","OWLList")),
      RDF.Triple(cell, R("list","hasContent"), node),
      RDF.Triple(cell, R("list","hasNext"), rest),
    ])
    if index
      push!(stmts, RDF.Triple(cell, R("list","index"), RDF.Literal(i)))
    end
  end
  nil = cell_node(length(nodes) + 1)
  push!(stmts, RDF.Triple(nil, R("rdf","type"), R("list","EmptyList")))
  stmts
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
