R = QQ[x, y, z]
I = monomialIdeal matrix {{x*y^3 * z, x*y^2 * z^2 , y^3 * z^2 , y^2 * z^3}}
J = ideal gens I
J' = ideal matrix entries gens I
mingens J
mingens J'
assert ( mingens J == mingens J' )
-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/test monideal3.out"
-- End:

