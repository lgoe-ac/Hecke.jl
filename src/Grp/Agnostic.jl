################################################################################
#
#  Operation agnostic functionality
#
################################################################################

export closure, small_generating_set, find_identity

################################################################################
#
#  Find identity with respect to operation
#
################################################################################

# It is assumed that the elements have finite order with respect to op.
function find_identity(S, op, eq = ==)
  @assert length(S) > 0
  g = S[1]
  h = g
  while true
    hh = op(h, g)
    if eq(hh, g)
      return h
    end
    h = hh
  end
end

################################################################################
#
#  Small generating set
#
################################################################################

function small_generating_set(G, op)
  i = find_identity(G, op)
  return small_generating_set(G, op, i)
end

function _non_trivial_randelem(G, id)
  x = rand(G)::typeof(id)
  while x == id
    x = rand(G)::typeof(id)
  end
  return x
end

function small_generating_set(G::Vector, op, id)
  orderG = length(G)

  if length(G) == 1
    return G
  end

  firsttry = 10
  secondtry = 20
  thirdtry = 30

  # First try one element
  for i in 1:firsttry
    gen = _non_trivial_randelem(G, id)
    if length(closure([gen], op, id)) == orderG
      return [gen]
    end
  end

  for i in 1:secondtry
    gens = typeof(id)[_non_trivial_randelem(G, id), _non_trivial_randelem(G, id)]
    if length(closure(gens, op, id)) == orderG
      return unique(gens)
    end
  end

  for i in 1:thirdtry
    gens = typeof(id)[_non_trivial_randelem(G, id), _non_trivial_randelem(G, id), _non_trivial_randelem(G, id)]
    if length(closure(gens, op, id)) == orderG
      return unique(gens)
    end
  end

  # Now use that unconditionally log_2(|G|) elements generate G

  b = ceil(Int, log(2, orderG))
  @assert orderG <= 2^b

  j = 0
  while true
    if j > 2^20
      error("Something wrong with generator search")
    end
    j = j + 1
    gens = [_non_trivial_randelem(G, id) for i in 1:b]
    if length(closure(gens, op, id)) == orderG
      return unique(gens)
    end
  end
end

################################################################################
#
#  Computing closure under group operation
#
################################################################################

# It is assumed that S is nonempty and that the group generated by S under op
# is finite.
function closure(S, op; eq = ==)
  i = find_identity(S, op, eq)
  return closure(S, op, i; eq = eq)
end

function closure(S, op, id; eq = ==)
  if length(S) == 0
    return [id]
  elseif length(S) == 1
    return _closing_under_one_generator(S[1], op, id, eq = eq)
  else
    return _closing_under_generators_dimino(S, op, id, eq = eq)
  end
end

function _closing_under_generators_naive(S, op, id; eq = ==)
  list = push!(copy(S), id)
  stable = false
  while !stable
    stable = true
    for g in list
      for s in S
        m = op(g, s)
        if !(any(x -> eq(x, m), list))
          push!(list, m)
          stable = false
        end
      end
    end
  end
  return list
end

function _closing_under_one_generator(x, op, id; eq = ==)
  elements = [x]
  y = x
  while !(eq(y, id))
    y = op(y, x)
    push!(elements, y)
  end
  return elements
end

function _closing_under_generators_dimino(S, op, id; eq = ==)

  t = length(S)
  order = 1
  elements = [id]
  g = S[1]

  while !(eq(g, id))
    order = order +1
    push!(elements, g)
    g = op(g, S[1])
  end

  for i in 2:t
    if !(any(x -> eq(x, S[i]), elements))
      previous_order = order
      order = order + 1
      push!(elements, S[i])
      for j in 2:previous_order
        order = order + 1
        push!(elements, op(elements[j], S[i]))
      end

      rep_pos = previous_order + 1
      while rep_pos <= order
        for k in 1:i
          s = S[k]
          elt = op(elements[rep_pos], s)
          if !(any(x -> eq(x, elt), elements))
            order = order + 1
            push!(elements, elt)
            for j in 2:previous_order
              order = order + 1
              push!(elements, op(elements[j], elt))
            end
          end
        end
        rep_pos = rep_pos + previous_order
      end
    end
  end
  return elements
end

################################################################################
#
#  Multiplication table
#
################################################################################

# Construct multiplication table of G under op
function _multiplication_table(G, op)
  l = length(G)
  z = Matrix{Int}(undef, l, l)
  for i in 1:l
    for j in 1:l
      p = op(G[i], G[j])
      for k in 1:l
        if p == G[k]
          z[i, j] = k
          break
        end
      end
    end
  end
  return z
end

################################################################################
#
#  Discrete logarithm
#
################################################################################

function disc_log_bs_gs(a::T, b::T, o::ZZRingElem, op, inv, pow) where {T}
  _one = pow(a, 0)
  b == _one && return ZZRingElem(0)
  b == a && return ZZRingElem(1)
  @assert parent(a) === parent(b)
  if o < 100 #TODO: benchmark
    ai = inv(a)
    for g=1:Int(o)
      b = op(b, ai)
      b == _one && return ZZRingElem(g)
    end
    throw("disc_log failed")
  end
  r = isqrt(o) + 1
  baby = Dict{typeof(a), Int}()
  baby[_one] = 0
  baby[a] = 1
  ba = a
  for i=2:r-1
    ba = op(ba, a)
    baby[ba] = i
    ba == b && return ZZRingElem(i)
  end
  giant = op(ba, a)
  @assert giant == pow(a, r)
  b == giant && return ZZRingElem(r)
  giant = inv(giant)
  g = ZZRingElem(0)
  for i=1:r+1
    b = op(b, giant)
    g += r
    if haskey(baby, b)
      return ZZRingElem(baby[b] + g)
    end
  end
  throw("disc_log failed")
end

#@doc raw"""
#    disc_log_ph(a::T, b::T, o::ZZRingElem, r::Int)
#
#Tries to find $g$ s.th. $a^g == b$ under the assumption that $ord(a) | o^r$
#Uses Pohlig-Hellmann and Baby-Step-Giant-Step for the size($o$) steps.
#Requires $a$ to be invertible.
#"""
function disc_log_ph(a::T, b::T, o::ZZRingElem, r::Int, op, inv, pow) where {T}
  #searches for g sth. a^g = b
  # a is of order o^r
  # Pohlig-Hellmann a^g = b => (a^o)^g = b^g
  g = 0
  aa = pow(a, o^(r - 1))
  for s=r:-1:1
    bb = op(b, pow(inv(a), g))
    gg = disc_log_bs_gs(aa, pow(bb, o^(s-1)), o, op, inv, pow)
    g = g+o^(r-s)*gg
  end
  return g
end
