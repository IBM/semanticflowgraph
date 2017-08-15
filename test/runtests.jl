using Base.Test

@testset "Doctrine" begin
  include("Doctrine.jl")
end

@testset "Diagram" begin
  include("Wiring.jl")
end
