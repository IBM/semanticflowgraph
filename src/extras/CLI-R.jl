using .RCall

@rimport flowgraph as RFlowGraph

function record_file(inpath::String, outpath::String, args::Dict, ::Val{:r})
  RFlowGraph.record_file(
    inpath, out=outpath, cwd=dirname(inpath), annotate=true)
end
