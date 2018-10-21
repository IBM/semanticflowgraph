using .PyCall

@pyimport flowgraph.core.record as PyFlowGraph

function record_file(inpath::String, outpath::String, ::Val{:python})
  PyFlowGraph.record_script(inpath, out=outpath, store_slots=false)
end
