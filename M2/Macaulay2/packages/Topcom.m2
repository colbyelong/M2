-- TODO:
--   1. how to check if a triangulation is correct?
--   2. generate the (oriented) circuits of a point set
--   3. Perhaps: add in a type "Chirotope" to facilitate the computation of circuits
--   4. find the lower hull of a polytope (maybe in Polyhedra? Where?)
--   5. check that going from a regular fine triangulation to a regular star fine triangulation 
--       (in the reflexive case) works.
--   6. generate (parts of) the flip graph, at least for regular triangulations.
--   7. topcom uses symmetry, place that into the interface here too
-- possible bugs:
--   why are the regular triangulation weights sometimes coming out negative?
--   need to be able to check that weights are correct.
newPackage(
        "Topcom",
        Version => "0.5", 
        Date => "6 May 2018",
        Authors => {{
                Name => "Mike Stillman", 
                Email => "mike@math.cornell.edu", 
                HomePage=>"http://www.math.cornell.edu/~mike"
                }},
        Headline => "interface to a small part of topcom",
        Configuration => {
            "path" => ""
            },
        DebuggingMode => true
        )

export {
    "chirotope",
    "isRegularTriangulation",
    "naiveChirotope",
    "orientedCircuits",
    "orientedCocircuits",
    "regularFineTriangulation",
    "regularTriangulationWeights",
    "allTriangulations",
    "Homogenize"
    }

exportMutable {
    "topcompath"
    }

topcompath = Topcom#Options#Configuration#"path"
if topcompath == "" then topcompath = prefixDirectory | currentLayout#"programs"

augment = (A) -> (
    -- A is a matrix over ZZ
    -- add in a last row of 1's.
    n := numColumns A;
    ones := matrix {{n : 1}};
    A || ones
    )

topcomPoints = method(Options=>{Homogenize=>true})
topcomPoints Matrix := opts -> (A) -> (
    A1 := if opts.Homogenize then augment A else A;
    new Array from for a in entries transpose A1 list new Array from a
    )

-- Workhorse function for calling topcom.
-- command: one of the commands of topcom, with command line arguments included.
-- inputs: a list of objects that are in the format for topcom to understand.
-- output: 2 file names, one for the stdout, one for stderr.
-- If the executable fails, what happens?
-- debugLevel: set to 0 - 7 for varying verbose output
callTopcom = method()
callTopcom(String, List) := (command, inputs) -> (
    filename := temporaryFileName();
    infile := filename|".in";
    outfile := filename|".out";
    errfile := filename|".err";
    -- now create the output file
    F := openOut(infile);
    for f in inputs do (
        F << f << endl;
    );
    F << close;
    executable := topcompath|command|" <"|infile|" 1>"|outfile|" 2>"|errfile;
    
    if debugLevel >= 1 then (
        << "-- calling topcom" << endl;
        << "-- " << command << ": using temporary file prefix " << filename << endl;
        );
    if debugLevel >= 7 then << "-- " << command << ": input = " << net get infile << endl;
    if debugLevel >= 2 then << "-- " << command << ": executing " << executable << endl;

    run executable;

    if debugLevel >= 5 then << "-- " << command << ": output = " << net get outfile << endl;
    if debugLevel >= 6 then << "-- " << command << ": stderr = " << net get errfile << endl;    

    (outfile, errfile)
    )

isRegularTriangulation = method(Options=>{Homogenize=>true})
isRegularTriangulation(Matrix, List) := opts -> (A, tri) -> (
    -- now create the output file
    (outfile, errfile) := callTopcom("checkregularity --checktriang -v", {topcomPoints(A, opts), [], tri });
    match("Checked 1 triangulations, 0 non-regular so far", get errfile)
    )

regularTriangulationWeights = method(Options => options isRegularTriangulation)
regularTriangulationWeights(Matrix, List) := opts -> (A, tri) -> (
    -- returns null if the triangulation is not regular.
    -- otherwise returns a list of rational numbers which are the 
    -- heights that result in the triangulation.
    (outfile, errfile) := callTopcom("checkregularity --heights", {topcomPoints(A, opts), [], tri });
    output := get outfile;
    if match("non-regular", output) then return null;
    result := value first lines output;
    return if instance(result, Number) then {result} else toList result
    )

regularFineTriangulation = method(Options => options isRegularTriangulation)
regularFineTriangulation Matrix := opts -> (A) -> (
    (outfile,errfile) := callTopcom("points2finetriang --regular", {topcomPoints(A, opts)});
    value get outfile
    )

chirotope = method(Options => options isRegularTriangulation)
chirotope Matrix := opts -> A -> (
    (outfile,errfile) := callTopcom("points2chiro", {topcomPoints(A, opts)});
    get outfile
    )

naiveChirotope = method(Options => options chirotope)
naiveChirotope Matrix := opts -> A -> (
    A1 := if opts.Homogenize then augment A else A;
    n := numColumns A1;
    d := numRows A1;
    chiroHeader := (toString n) | "," | (toString d) | ":\n";
    subs := sort subsets(n,d);
    subs1 := pack(subs, 100);
    chiroHeader | concatenate for s in subs1 list (
        concatenate (for s1 in s list (
                d := det A1_s1;
                if d > 0 then "+" else if d == 0 then "0" else "-"
                )) | "\n"
        )
    )

orientedCircuits = method(Options => {Homogenize=>true})
orientedCircuits String := opts -> (chiro) -> (
    (outfile,errfile) := callTopcom("chiro2circuits", {chiro});
    s := lines get outfile;
    -- remove first 2 lines, and last line:
    s = drop(drop(s, 2), -1);
    circs := s/(x -> toList value x);
    -- now sort it all
    circs/sort//sort
    )
orientedCircuits Matrix := opts -> A -> orientedCircuits chirotope(A, opts)

orientedCocircuits = method(Options => {Homogenize=>true})
orientedCocircuits String := opts -> (chiro) -> (
    (outfile,errfile) := callTopcom("chiro2cocircuits", {chiro});
    s := lines get outfile;
    s = drop(drop(s, 2), -1);
    s/(x -> toList value x)
    )
orientedCocircuits Matrix := opts -> A -> orientedCocircuits chirotope(A, opts)

allTriangulations = method(Options => {RegularOnly => true, Fine => false})
allTriangulations Matrix := opts -> (A) -> (
    executable := if opts.Fine then "points2allfinetriangs " else "points2alltriangs ";
    args := if opts.Regular then "--regular" else "";
    (outfile, errfile) := callTopcom("executable | args", {topcomPoints(A, opts)});
    (outfile, errfile)
    )

beginDocumentation()

doc ///
Key
  Topcom
Headline
  interface to selected functions from topcom package
Description
  Text
    Topcom @HREF{"http://www.rambau.wm.uni-bayreuth.de/TOPCOM/"}@ is mathematical software written by Jorg Rambau for 
    computing and manipulating triangulations of polytopes and chirotopes.
    
    This package implements two key functions from the topcom package
    @TO "isRegularTriangulation"@  checks whether a triangulation of a point set is a regular triangulation,
    and @TO "regularFineTriangulation"@ computes a triangulation which involves all lattice points of a polytope.
Caveat
  There are many other functions available in Topcom.  If you wish any of these implemented, or you would like to contribute
  such an implementation, please contact the author.
SeeAlso
  "CohomCalg::CohomCalg"
  "ReflexivePolytopesDB::ReflexivePolytopesDB"
///

doc ///
Key
  isRegularTriangulation
  (isRegularTriangulation,Matrix,List)
Headline
  determine if a given triangulation is a regular triangulation
Usage
  isRegularTriangulation(C, tri)
Inputs
  C:Matrix
    A matrix over ZZ.  Each column represents one of the points
    which can be used in a triangulation
  tri:List
    A triangulation of the point set C
Outputs
  :Boolean
    whether the given triangulation is regular
Description
  Text
    The following example is one of the simplest examples of a non-regular
    triangulation.  Notice that {\tt tri} is a triangulation of the 
    polytope which is the convex hull of the columns of $A$, which are 
    the only points allowed in the triangulation.
  Example
    A = transpose matrix {{0,3},{0,1},{-1,-1},{1,-1},{-4,-2},{4,-2}}
    tri = {{0,1,2}, {1,3,5}, {2,3,4}, {0,1,5}, 
        {0,2,4}, {3,4,5}, {1,2,3}}
    isRegularTriangulation(A,tri)
  Text
    Setting debugLevel to either 1,2, or 5 will give more detail about
    what files are written to Topcom, and what the executable is.
    Setting debugLevel to 0 means that the function will run silently.
Caveat
  Do we check that the triangulation is actually welll defined?
SeeAlso
  regularFineTriangulation  
///

TEST ///
-*
  restart
  debug needsPackage "Topcom"
*-
  -- test of isRegularTriangulation
  A = transpose matrix {{-1,-1,1},{-1,1,1},{1,-1,1},{1,1,1},{0,0,1}}
  regularFineTriangulation(A, Homogenize=>false)
  tri = {{0, 2, 4}, {2, 3, 4}, {0, 1, 4}, {1, 3, 4}}
  assert isRegularTriangulation(A,tri)
  assert(regularTriangulationWeights(A,tri,Homogenize=>false) == {1,1,0,0,0})
///

TEST ///
  needsPackage "Topcom"
  -- test of isRegularTriangulation
  A = transpose matrix {{0,3},{0,1},{-1,-1},{1,-1},{-4,-2},{4,-2}}
  tri = {{0,1,2}, {1,3,5}, {2,3,4},
         {0,1,5}, {0,2,4}, {3,4,5},
         {1,2,3}}
  assert not isRegularTriangulation(A,tri)
  assert(null === regularTriangulationWeights(A,tri))
  
  A = transpose matrix {{0,3},{0,1},{-1,-1},{1,-1},{-4,-2},{7,-2}}
  tri = {{0,1,2}, {1,3,5}, {2,3,4},
         {0,1,5}, {0,2,4}, {3,4,5},
         {1,2,3}}
  assert isRegularTriangulation(A,tri)
  regularTriangulationWeights(A,tri) -- Question: how to test that this is correct
    -- TODO: need a function which takes a point set, weights, and creates the lift (easy)
    --       compute the lower hull of this polytope.

  assert(chirotope A == naiveChirotope A)
  orientedCircuits A
  orientedCocircuits A
  A = transpose matrix {{1,0},{0,1}}
  tri = {{0,1}}
  assert isRegularTriangulation(A,tri)
  regularTriangulationWeights(A,tri) == {0,1} -- TODO: check that this is the correct answer
  
  A = transpose matrix {{0}}
  tri = {{0}}
  assert isRegularTriangulation(A,tri)
  regularTriangulationWeights(A,tri) == {1}
///

///
-- TODO: This test needs to be made to assert correct statements
-- How to test that triangulations are correct?  What I thought worked does not.
  needsPackage "Topcom"
  A = transpose matrix{{-1,-1},{-1,1},{1,-1},{1,1},{0,0}}
  regularFineTriangulation A  
  tri = {{0, 2, 4}, {2, 3, 4}, {0, 1, 4}, {1, 3, 4}}
  tri = {{0, 2, 4}, {2, 3, 4}, {0, 1, 4}, {1, 2, 3}}
  isRegularTriangulation(A, tri) -- Wrong!!

  badtri = {{0, 2, 4}, {2, 3, 4}, {0, 1, 4}, {1, 2, 3}}
  debugLevel = 6
  isRegularTriangulation(A,badtri) -- this should fail! But it doesn't seem to do so. BUG in something!!!
  debugLevel = 0
  -- hmmm, we can make non-sensical triangulations, without it noticing.
  -- this should be a bug?  
  A = transpose matrix {{0,0},{0,1},{1,0},{1,1}}
  tri = {{0,1,2},{0,2,3}}
  assert isRegularTriangulation(A,tri)  
  tri = {{0,1,2},{1,2,3}}
  assert isRegularTriangulation(A,tri) 
///

TEST ///  
  needsPackage "Topcom"
  needsPackage "Polyhedra"
  
  A = transpose matrix {{-1,-1,2},{-1,0,1},{-1,1,1},{0,-1,2},{0,1,1},{1,-1,3},{1,0,-1},{1,1,-2}}
  debugLevel = 0
  tri = regularFineTriangulation A
  assert isRegularTriangulation(A, tri)
  assert(regularTriangulationWeights(A, tri) =!= null)

  A = transpose matrix {{-1, 0, -1, -1}, {-1, 0, 0, -1}, {-1, 1, 2, -1}, {-1, 1, 2, 0}, {1, -1, -1, -1}, {1, -1, -1, 1}, {1, 0, -1, 2}, {1, 0, 1, 2}}
  P2 = polar convexHull A
  C = matrix {latticePoints P2}
  tri = regularFineTriangulation C
  assert isRegularTriangulation(C, tri)
  regularTriangulationWeights(C, tri) -- is this correct?  Some weights have negative values??
///


TEST ///
-- simple example of chirotope
-*
  restart
  debug needsPackage "Topcom"
*-
  A = transpose matrix {{-1,-1},{-1,1},{1,-1},{1,1},{0,0}}
  tri = {{0, 2, 4}, {2, 3, 4}, {0, 1, 4}, {1, 3, 4}}
  ch1 = chirotope A
  ch2 = naiveChirotope A
  assert(ch1 == ch2)
///

end----------------------------------------------------

restart
uninstallPackage "Topcom"
restart
check "Topcom"
restart
installPackage "Topcom"
needsPackage "Topcom"


TEST /// 
  -- points2chiro
  toppath = "/Users/mike/src/M2-master/M2/BUILD/dan/builds.tmp/as-mth-indigo.local-master/libraries/topcom/build/topcom-0.17.8/src/"
  A = transpose matrix {{-1,-1,1},{-1,1,1},{1,-1,1},{1,1,1},{0,0,1}}
  tri = {{0, 2, 4}, {2, 3, 4}, {0, 1, 4}, {1, 3, 4}}
  run (toppath|"/points2chiro"|" -h")
  "topcomfoo.in" << topcomPoints(A, Homogenize=>false) << endl << close;
  chiro = get ("!"|toppath|"/points2chiro"|" <topcomfoo.in")
  #chiro
  chiro2 = "5,3:\n" | (concatenate for s in sort subsets(5,3) list (
      d := det A_s;
      if d > 0 then "+" else if d == 0 then "0" else "-"
      )) | "\n"
  chiro == chiro2
  -- notes: a chirotope for topcom:
  --  5,3:  (number of vertices, dim)
  --  a string of "-","+","0", maybe cut over a number of lines.
  -- should we make a type out of this (so we can read and write it to a file)

  -- chiro2circuits
  "topcomfoo.in" << chiro << endl << [] << endl << close;
  circs = get ("!"|toppath|"/chiro2circuits"|"  <topcomfoo.in")
  cocircs = get ("!"|toppath|"/chiro2cocircuits"|"  <topcomfoo.in")
  drop(drop(circs, 2), -1)
  oo/value

chiro = "5, 3:"

r12'chiro = "12, 4:
-+--+++---++---++-+---++-+++-----++--++-++++--++---+++-+++--+---++---++--++-++++
--+---++-+++--+++--++--+----+-+++--+++--++--+----+---++--++-++++-++--+-----+----
-++---++---+++-+++--+---++---++--++-++++--+---++-+++--+++--++--+----+-+++--+++--
++--+----+---++--++-++++---++-+++++-+++++--++++---++-+++--+++--++--+----+-+++--+
++--++--+----+---++--++-++++---++-+++++-+++++--+++---++---++--++-++++-+++--++--+
----+++--+-----+-----++--+++--++--+----+++--+-----+-----++----++-+++++-+++++--++
--------++--++-
"
  chiro = r12'chiro
  -- chiro2alltriangs, chiro2nalltriangs
  "topcomfoo.in" << "5, 3:" << endl << chiro << endl << [] << endl << close;
  "topcomfoo.in" << chiro << [] << endl << close;
  get ("!"|toppath|"/chiro2placingtriang"|" -v <topcomfoo.in")
  get ("!"|toppath|"/chiro2circuits"|" <topcomfoo.in")
  get ("!"|toppath|"/chiro2cocircuits"|" <topcomfoo.in")
  get ("!"|toppath|"/chiro2alltriangs"|" <topcomfoo.in")
  get ("!"|toppath|"/chiro2ntriangs"|" <topcomfoo.in")
  get ("!"|toppath|"/chiro2finetriang"|" <topcomfoo.in")
  get ("!"|toppath|"/chiro2finetriangs"|" <topcomfoo.in") -- what is the format of the output here??
  get ("!"|toppath|"/chiro2nfinetriangs"|" -v <topcomfoo.in")
  
///

TEST ///
  restart
  debug needsPackage "Topcom"
  needsPackage "ReflexivePolytopesDB"
  needsPackage "StringTorics"
  str = getKreuzerSkarke(50, Limit=>10);
  polytopes = parseKS str
  tope = polytopes_5_1
  A = matrixFromString tope
  P = convexHull A
  P2 = polar P
  A = matrix{latticePoints P2}

  LP = drop(latticePointList P2, -1);
  A = transpose matrix LP;
  debugLevel = 6
  elapsedTime tri = regularFineTriangulation A;
  
  -- XXX
  augment A
  "topcomfoo.in" << topcomPoints(augment A, Homogenize=>false) << endl << close;
  chiro = get ("!"|toppath|"/points2chiro"|" <topcomfoo.in")

  "topcomfoo.in" << chiro << "[]" << endl << close;
  get ("!"|toppath|"/chiro2circuits"|" <topcomfoo.in")
  get ("!"|toppath|"/chiro2ntriangs"|" <topcomfoo.in")
  --get ("!"|toppath|"/chiro2alltriangs"|"  <topcomfoo.in")
  get ("!"|toppath|"/chiro2cocircuits"|" <topcomfoo.in")    
///

TEST ///
-- how to check a triangulation?  I don't think that Topcom has this implemented for general use.
-*
  restart
  debug needsPackage "Topcom"
*-
  -- test of isRegularTriangulation
  toppath = "/Users/mike/src/M2-master/M2/BUILD/dan/builds.tmp/as-mth-indigo.local-master/libraries/topcom/build/topcom-0.17.8/src/"
  A = transpose matrix {{-1,-1,1},{-1,1,1},{1,-1,1},{1,1,1},{0,0,1}}
  badtri = {{0, 2, 4}, {2, 3, 4}, {0, 1, 4}, {1, 2}}
  debugLevel = 6

  -- a regular triangulation
  A = transpose matrix {{0,3},{0,1},{-1,-1},{1,-1},{-4,-2},{7,-2}}
  tri = {{0,1,2}, {1,3,5}, {2,3,4},
         {0,1,5}, {0,2,4}, {3,4,5},
         {1,2,3}}
  "topcomfoo.in" << topcomPoints(A, Homogenize=>true) << endl << "[]" << endl << tri << endl << close;
  run (topcompath|"checkregularity"|" --heights <topcomfoo.in >topcomfoo.out")  

  -- points2chiro
  "topcomfoo.in" << topcomPoints(A, Homogenize=>false) << endl << "[]" << endl << badtri << endl << close;
  print (toppath|"/points2alltriangs"|" --checktriang -v <topcomfoo.in") 


  A = transpose matrix {{0,3},{0,1},{-1,-1},{1,-1},{-4,-2},{4,-2}}
  tri = {{0,1,2}, {1,3,5}, {2,3,4},
         {0,1,5}, {0,2,4}, {3,4,5},
         {1,2,3}}
  "topcomfoo.in" << topcomPoints(A, Homogenize=>true) << endl << "[]" << endl << tri << endl << close;
  run (topcompath|"checkregularity"|" --heights <topcomfoo.in >topcomfoo.out")
  assert not isRegularTriangulation(A,tri)

///




end--

restart
uninstallPackage "Topcom"
restart
needsPackage "Topcom"
installPackage "Topcom"
restart
check "Topcom"
viewHelp

///
-- generate examples to use for this package
-- from reflexive polytopes of dim 4
  restart
  needsPackage "StringTorics"

  str = getKreuzerSkarke(10, Limit=>5)
  str = getKreuzerSkarke(20, Limit=>5)
  str = getKreuzerSkarke(30, Limit=>5)
  polytopes = parseKS str
  tope = polytopes_4_1
  A = matrixFromString tope
  P = convexHull A
  P2 = polar P
  LP = drop(latticePointList P2, -1)
  A1 = transpose matrix LP
  A2 = transpose matrix latticePointList P2
  tri = regularFineTriangulation A1
  tri2 = regularFineTriangulation A2
  #tri
  #tri2
  elapsedTime chiro1 = chirotope A1;
  elapsedTime chiro2 = chirotope A2;
  elapsedTime # orientedCircuits chiro1
  elapsedTime # orientedCircuits chiro2
  elapsedTime # orientedCocircuits chiro1
  elapsedTime # orientedCocircuits chiro2
  (select(orientedCocircuits A2, f -> #f#0 == 0 or #f#1 == 0))/first
  netList annotatedFaces P2  
  tri2
  -- fine:
  assert(sort unique flatten tri2 == toList (0..14))
  walls = tri2/(x -> subsets(x, #x-1))//flatten
  nfacets = tally walls
  facs = (select((annotatedFaces P2), x -> x_0 == 3))/(x -> x#2)
  walls = partition(k -> nfacets#k, keys nfacets)
  for w in walls#1 list (
      # select(facs, f -> isSubset(w, f))
      )
  for w in walls#2 list (
      # select(facs, f -> isSubset(w, f))
      )
  -- check overlaps of elements of tri2:
  C = orientedCircuits A2;
  elapsedTime for c in C list (
      val1 := select(tri2, x -> isSubset(c_0, x));
      val2 := select(tri2, x -> isSubset(c_1, x));
      if #val1 > 0 and #val2 > 0 then print (c, val1, val2);
      (c, #val1, #val2));
  
  tri_0
  
///
  
doc ///
Key
Headline
Usage
Inputs
Outputs
Consequences
Description
  Text
  Example
  Code
  Pre
Caveat
SeeAlso
///

