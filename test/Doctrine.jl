module TestDoctrine

using Base.Test
using OpenDiscCore.Doctrine

A0, A, B, C = Ob(Monocl, :A0, :A, :B, :C)
I = munit(Monocl.Ob)
f = Hom(:f, A, B)
g = Hom(:f, A, C)

# Coercion
@test coerce(A,A) == id(A)
@test compose(coerce(A,A), f) == f
@test compose(f, coerce(B,B)) == f

# Constructors
@test dom(construct(A)) == I
@test codom(construct(A)) == A
@test dom(construct(f)) == B
@test codom(construct(f)) == A

# Pair
@test dom(pair(f,g)) == A
@test codom(pair(f,g)) == otimes(B,C)
@test pair(f,g) == compose(mcopy(A), otimes(f,g))
@test dom(pair(A0,f,g)) == A0
@test codom(pair(A0,f,g)) == otimes(B,C)

end
