using .PyCall

@pyimport flowgraph.core.record as PyFlowGraph

function record_file(inpath::String, outpath::String, args::Dict, ::Val{:python})
  PyFlowGraph.record_script(
    inpath, out=outpath, cwd=dirname(inpath),
    graph_outputs=args["graph-outputs"], store_slots=false)
end
