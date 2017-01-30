(* ::Package:: *)

(* ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ *)

(* :Title: DiracTrace														*)

(*
	This software is covered by the GNU General Public License 3.
	Copyright (C) 1990-2016 Rolf Mertig
	Copyright (C) 1997-2016 Frederik Orellana
	Copyright (C) 2014-2016 Vladyslav Shtabovenko
*)

(* :Summary:  Dirac trace calculation										*)

(* ------------------------------------------------------------------------ *)


DiracTrace::usage =
"DiracTrace[expr] is the head of Dirac traces. \
Whether the trace is  evaluated depends on the option \
DiracTraceEvaluate. See also TR. \
The argument expr may be a product of Dirac matrices or slashes \
separated by the Mathematica Dot \".\" (assuming DOT has been set to Dot).
The option Factoring determines the final function to be applied. If \
it is set to False no simplification is done. \
It might be set to, e.g., Factor or Factor2 to get simpler results. \
With the default setting Factoring -> Automatic factorization is performed on \
not too long (LeafCount[ ] < 5000 ) expressions.
";

DiracTrace::noncom =
"Wrong syntax! The Dirac trace of `1` contains Dirac matrices multiplied via \
Times (commutative multiplication) instead of DOT (non-commutative multiplication). \
Evaluation aborted!";

DiracTrace::ndranomaly =
"You are using naive dimensional regularization (NDR), such that in D dimensions \
gamma^5 anticommutes with all other Dirac matrices. In this scheme \
(without additional prescriptions) it is not possible to compute traces with an \
odd number of gamma^5 unambiguously. Evaluation aborted!";

DiracTrace::ilsch =
"The settings $BreitMaison=`1`, $Larin=`2` do not describe a valid \
scheme for treating gamma^5 in D dimensions. Evaluation aborted!.";

DiracTrace::failmsg =
"Error! DiracTrace has encountered a fatal problem and must abort the computation. \
The problem reads: `1`"

(* ------------------------------------------------------------------------ *)

Begin["`Package`"]
End[]

Begin["`DiracTrace`Private`"]

diTrVerbose::usage="";
west::usage="";
unitMatrixTrace::usage="";
traceNo5Fun::usage="";
trace5Fun::usage="";
noSpur::usage="";

Options[DiracTrace] = {
	Contract -> 400000,
	DiracTraceEvaluate-> False,
	EpsContract -> False,
	Expand -> True,
	FCVerbose -> False,
	Factoring -> Automatic,
	FeynCalcExternal -> False,
	FeynCalcInternal -> False,
	Mandelstam    -> {},
	PairCollect    -> False,
	Schouten-> 0,
	TraceOfOne -> 4,
	West -> True
};


DiracTrace /:
	MakeBoxes[DiracTrace[expr__, OptionsPattern[]], TraditionalForm]:=
	RowBox[{"tr","(",TBox[expr], ")"}]


(* gamma67backdef: reinsertion of gamma6 and gamm7 *)
gamma67back[x_] :=
	x/.DiracGamma[6]->( 1/2 + DiracGamma[5]/2 )/. DiracGamma[7]->( 1/2 - DiracGamma[5]/2 );

DiracTrace[0, OptionsPattern[]] :=
	0;

DiracTrace[a_ /; (FreeQ[a, DiracGamma] && !FreeQ[a, DiracGammaT]), b:OptionsPattern[]] :=
	DiracTrace[(a//Transpose)//Reverse, b];

DiracTrace[a:Except[_HoldAll]..., x_,y_, z___] :=
	DiracTrace[a,x.y,z]/;FCPatternFreeQ[{x,y},{Rule}];

DiracTrace[expr_, op:OptionsPattern[]] :=
	Block[ {diTres, ex, tr1,tr2,tr3,time,dsHead,diracObjects,diracObjectsEval,null1,null2,freePart,dsPart,repRule,diTr},


		If [OptionValue[FCVerbose]===False,
			diTrVerbose=$VeryVerbose,
			If[MatchQ[OptionValue[FCVerbose], _Integer?Positive | 0],
				diTrVerbose=OptionValue[FCVerbose]
			];
		];

		unitMatrixTrace = OptionValue[TraceOfOne];

		FCPrint[1, "DiracTrace. Entering.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrace: Entering with ", expr, FCDoControl->diTrVerbose];


		If[ OptionValue[FCI],
			ex = expr,
			ex = FCI[expr]
		];
		(*
		time=AbsoluteTime[];
		FCPrint[1, "DiracTrace. Checking the syntax.", FCDoControl->diTrVerbose];
		If [ !FreeQ2[ex,
			{
			(*Times instead of DOT between two Dirac or SU(N) matrices*)
			(DiracGamma | DiracGammaT)[a__]*(DiracGamma | DiracGammaT)[b__],
			SUNT[a__]*SUNT[b__],
			(*Two DOT objects multiplied with each other via Times, unless those are closed spinor chains*)
			DOT[a:Except[_Spinor]...,(DiracGamma | DiracGammaT )[b__],c:Except[_Spinor]...]*
			DOT[d:Except[_Spinor]...,(DiracGamma | DiracGammaT)[e__],f:Except[_Spinor]...],
			(*Open spinor chains*)
			DOT[a_Spinor,b:Except[_Spinor]...],
			(*DOT object multiplied by a Dirac or SU(N) matrix via Times*)
			DOT[a:Except[_Spinor]...,(DiracGamma | DiracGammaT)[b__],c:Except[_Spinor]...]*
			(DiracGamma | DiracGammaT)[d__]}],
			Message[DiracTrace::noncom, InputForm[ex]];
			Abort[]
		];
		FCPrint[1,"DiracTrace: Syntax check done, timing: ", N[AbsoluteTime[] - time, 4] , FCDoControl->diTrVerbose];
		*)

		(* Doing contractions can often simplify the underlying expression *)
		time=AbsoluteTime[];

		If[	OptionValue[Contract]=!=False,
			FCPrint[1, "DiracTrace. Applying Contract.", FCDoControl->diTrVerbose];
			ex = Contract[ex, Expanding->True, EpsContract-> OptionValue[EpsContract], Factoring->False];
			FCPrint[1,"DiracTrace: Contract done, timing: ", N[AbsoluteTime[] - time, 4] , FCDoControl->diTrVerbose]
		];



		(* 	First of all we need to extract all the Dirac structures inside the trace. *)
		ex = FCDiracIsolate[ex,FCI->True,Head->dsHead, Spinor->False, DiracTrace -> False, DiracSigmaExplicit->True];
		ex = ex /. DiracTrace -> diTr;


		{freePart,dsPart} = FCSplit[ex,{dsHead}];
		FCPrint[3,"DiracTrace: dsPart: ",dsPart , FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrace: freePart: ",freePart , FCDoControl->diTrVerbose];
		If [ dsPart=!=0,
			(* Check that there is only one dsHead per term and no nested dsHeads *)
			Scan[
				If[	!MatchQ[#, a_. dsHead[b_]/; (FreeQ[{a,b}, dsHead] && !FreeQ[b,DiracGamma])],
					Message[DiracTrace::failmsg, "Irregular trace structure in", InputForm[#]];
					Print[#];
					Abort[]
			]&, dsPart+dsHead[DiracGamma] ];
		];

		(* 	Now it is guaranteed that dsPart is of the form a*dsHead[x]+b*dsHead[y]+c*dsHead[z]+...
			So it is safe to extract all the dsHead objects and handle them separately	*)
		diracObjects = Cases[dsPart+null1+null2, dsHead[_], Infinity]//Union;

		time=AbsoluteTime[];
		FCPrint[1, "DiracTrace. Applying diracTraceEvaluate.", FCDoControl->diTrVerbose];

		(* Here we try to compute some very simple traces in a faster way *)
		diracObjectsEval = Map[diracTraceEvaluateFast[#]&, (diracObjects/.dsHead->Identity)] /. diracTraceEvaluateFast->Identity;

		diracObjectsEval = Map[diracTraceEvaluate[#, Flatten[Join[{op}, FilterRules[Options[DiracTrace], Except[{op}]]]]]&,
			diracObjectsEval];

		diracObjectsEval = diracObjectsEval/. noSpur[x__]:> diTr[DOT[x]]/unitMatrixTrace;

		repRule = MapThread[Rule[#1,#2]&,{diracObjects,diracObjectsEval}];
		FCPrint[3,"DiracTrace: repRule: ",repRule , FCDoControl->diTrVerbose];

		tr3 = (unitMatrixTrace freePart) + ( dsPart/.repRule);

		(* If the result should contain Mandelstam variables *)
		If[ Length[OptionValue[Mandelstam]] > 0,
			tr3 = TrickMandelstam @@ Prepend[{OptionValue[Mandelstam]}, tr3]
		];

		If [OptionValue[FeynCalcExternal],
			diTres = FCE[tr3],
			diTres = tr3
		];

		If[ !FreeQ[diTres/. diTr[_]:>1 ,DiracGamma],
			Message[DiracTrace::failmsg,"The output still contains Dirac matrices"];
			Abort[]
		];
		diTres = diTres/. diTr->DiracTrace;

		FCPrint[1, "DiracTrace: Leaving.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrace: Leaving with", diTres, FCDoControl->diTrVerbose];

		diTres
	]/; OptionValue[DiracTraceEvaluate];


diracTraceEvaluateFast[DOT[DiracGamma[l1_LorentzIndex].DiracGamma[l2_LorentzIndex]]]:=
	alreadyDone[unitMatrixTrace Pair[l1,l2]];

diracTraceEvaluate[alreadyDone[expr_],OptionsPattern[]] :=
	expr;

diracTraceEvaluate[expr_/; Head[expr]=!=alreadyDone,opts:OptionsPattern[]] :=
	Block[ { diractrres, tmp = expr, diractrfact,
		diractrcoll, schoutenopt,
		dtmp,dWrap,dtWrap,wrapRule,prepSpur,time,time2,contract,spurHeadList,spurHeadListChiral,spurHeadListNonChiral,
		gammaFree,gammaPart,
		traceListChiral,traceListNonChiral,repRule,null1,null2

		},

		wrapRule = {dWrap[5]->0, dWrap[6]->1/2, dWrap[7]->1/2, dWrap[LorentzIndex[_,_:4],___]->0,
					dWrap[_. Momentum[_,_:4]+_:0,___]->0};

		diractrfact = OptionValue[DiracTrace,{opts},Factoring];
		diractrcoll = OptionValue[DiracTrace,{opts},PairCollect];
		schoutenopt = OptionValue[DiracTrace,{opts},Schouten];
		contract  	= OptionValue[DiracTrace,{opts},Contract];
		west		= OptionValue[DiracTrace,{opts},West];

		If[ diractrfact === Automatic,
			diractrfact = Function[x, If[ LeafCount[x] <  5000,
										Factor[x],
										x
									]];
		];

		FCPrint[1,"DiracTrace: diracTraceEvaluate: Entering", FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrace: diracTraceEvaluate: Entering with: ",expr, FCDoControl->diTrVerbose];


		time=AbsoluteTime[];
		FCPrint[1,"DiracTrace: diracTraceEvaluate: Applying DiracTrick.", FCDoControl->diTrVerbose];
		tmp = DiracTrick[tmp, FCI -> True, InsideDiracTrace->True, FCDiracIsolate->False];
		FCPrint[1,"DiracTrace: diracTraceEvaluate: DiracTrick done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrace: diracTraceEvaluate: After DiracTrick: ", tmp, FCDoControl->diTrVerbose];


		time=AbsoluteTime[];
		If[ !FreeQ[tmp, DiracGamma],
			(*	If the output of DiracSimplify still contains Dirac matrices, apply DotSimplify and use DiracTrick again	*)
			(*	We need to consider standalone Dirac matrices separately: With the following all of them will  be wrapped inside dWrap or dtWrap	*)
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Calculating the trace.", FCDoControl->diTrVerbose];


			time2=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Applying Dotsimplify.", FCDoControl->diTrVerbose];
			tmp = DotSimplify[tmp, Expanding -> True];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Dotsimplify done, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->diTrVerbose];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: After Dotsimplify: ", tmp, FCDoControl->diTrVerbose];


			time2=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Applying DiracTrick.", FCDoControl->diTrVerbose];
			tmp = DiracTrick[tmp, FCI -> True, InsideDiracTrace->True];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: DiracTrick done, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->diTrVerbose];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: After DiracTrick: ", tmp, FCDoControl->diTrVerbose];


			tmp = tmp /.  {DiracGamma -> dWrap,DiracGammaT -> dtWrap} /. DOT -> prepSpur;
			tmp = tmp /. prepSpur[zzz__] :> spurHead@@({zzz} /. {dWrap -> DiracGamma,dtWrap->DiracGammaT});
			FCPrint[3,"DiracTrace: diracTraceEvaluate: Wrapped in spurHead: ",tmp, FCDoControl->diTrVerbose];
			(* Split chiral projectors here *)
			tmp = tmp /. {spurHead[x___,DiracGamma[6]] :> 1/2 spurHead[x] + 1/2 spurHead[x,DiracGamma[5]],
			spurHead[x___,DiracGamma[7]] :> 1/2 spurHead[x] - 1/2 spurHead[x,DiracGamma[5]]} /. spurHead[] -> 1;
			FCPrint[3,"DiracTrace: diracTraceEvaluate: Chiral projectors splitted: ",tmp, FCDoControl->diTrVerbose];

			If[!FreeQ2[tmp,{DiracGamma[6],DiracGamma[7]}],
				Message[DiracTrace::failmsg,"Trace still contains chiral projectors."];
				Abort[]
			];


			(*	Unknown non-commutative objects inside the trace prevent trace from being computed *)
			tmp = tmp/. spurHead[x__]/; !NonCommFreeQ[{x}/.DiracGamma->null1] :> noSpur[x];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: Trace contains unknown non-commutative objects: ", !FreeQ[tmp, noSpur], FCDoControl->diTrVerbose];

			(*	After all the simplifications we need to split terms that still containd Dirac matrices from those that don't.	*)
			{gammaFree,gammaPart} = FCSplit[tmp,{spurHead}];

			FCPrint[3,"DiracTrace: diracTraceEvaluate: gammaFree: ", gammaFree, FCDoControl->diTrVerbose];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: gammaPart: ", gammaPart, FCDoControl->diTrVerbose];

			If [ gammaPart=!=0,
				(* Check that there is only one spurHead per term and no nested spurHead *)
				Scan[
					If[	!MatchQ[#, a_. spurHead[b__]/; (FreeQ[{a,b}, spurHead] && !FreeQ[{b},DiracGamma])],
						Message[DiracTrace::failmsg, "Irregular trace structure in ", ToString[#,InputForm]];
						Abort[]
				]&, gammaPart+spurHead[DiracGamma]
				];
			];

			(*	Now it is guaranteed that gammaPart is of the form a*spurHead[x]+b*spurHead[y]+c*spurHead[z]+...
				So it is safe to extract all the spurHead objects and handle them separately	*)
			spurHeadList = Cases[gammaPart+null1+null2, spurHead[__], Infinity]//Union;
			FCPrint[3,"DiracTrace: diracTraceEvaluate: spurHeadList", spurHeadList, FCDoControl->diTrVerbose];

			(*	Separate chiral and non-chiral traces *)
			spurHeadListChiral = Select[spurHeadList,!FreeQ[#,DiracGamma[5]]&];
			spurHeadListNonChiral = Complement[spurHeadList,spurHeadListChiral];

			FCPrint[3,"DiracTrace: diracTraceEvaluate: spurHeadListChiral: ", spurHeadListChiral, FCDoControl->diTrVerbose];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: spurHeadListNonChiral: ", spurHeadListNonChiral, FCDoControl->diTrVerbose];

			If[spurHeadList =!= Union[Join[spurHeadListChiral,spurHeadListNonChiral]],
				Message[DiracTrace::failmsg,"Splitting between chiral and non-chiral traces failed"];
				Abort[]
			];

			(* One more check: Traces with mixed dimensions are forbidden in NDR and Larin's scheme, so we abort the computation if this is the case *)
			If [ !$BreitMaison,
				Scan[
					If[	Length[FCGetDimensions[#/.DiracGamma[5]->1]]=!=1,
						Message[DiracTrace::failmsg, "Traces with mixed dimensions are forbidden in this g^5 scheme."];
						Abort[]
					]&, spurHeadListChiral
				]
			];

			(* Check that chiral traces have the correct form *)
			Scan[
				If[	!MatchQ[#, spurHead[DiracGamma[_[_,___],___]...,DiracGamma[5]]],
					Message[DiracTrace::failmsg,"Chiral traces are not in the proper form."];
					Abort[]
			]&, spurHeadListChiral];

			(* Evaluate the traces *)
			time2=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Calculating non-chiral traces.", FCDoControl->diTrVerbose];

			traceListNonChiral = spurHeadListNonChiral/. spurHead-> spurNo5;
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Done calculating non-chiral traces, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->diTrVerbose];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: traceListNonChiral", traceListNonChiral, FCDoControl->diTrVerbose];

			(* Check that there are no uncomputed traces left *)
			If[	!FreeQ2[traceListNonChiral,{spurHead,DiracGamma}],
				Message[DiracTrace::failmsg, "Not all non-chiral traces were evaluated."];
				Abort[]
			];

			time2=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Calculating chiral traces.", FCDoControl->diTrVerbose];
			(* 	Purely 4 dimensional traces are always computed in the same way, regardless of the chosen scheme:
				Eq 2.18 of R. Mertig, M. Boehm, A. Denner. Comp. Phys. Commun., 64 (1991)) *)
			traceListChiral = spurHeadListChiral/. spurHead[x__]/;(FCGetDimensions[{x}]==={4}) :> spur5In4Dim[x];

			(*	Choice of the scheme for D-dimensional g^5	*)
			If[	!FreeQ[traceListChiral,spurHead],
				Which[
					(*	NDR	*)
					!$Larin && !$BreitMaison,
						Message[DiracTrace::ndranomaly];
						Abort[],
					(*	Larin	*)
					$Larin && !$BreitMaison,
						FCPrint[3,"DiracTrace: diracTraceEvaluate: Chiral traces will be computed using Larin's scheme", FCDoControl->diTrVerbose];
						traceListChiral = traceListChiral/. spurHead -> spur5Larin,
					(*	BMHV	*)
					!$Larin && $BreitMaison,
						If[	west,
							(* BMHV, West's trace formula *)
							traceListChiral = traceListChiral/. spurHead -> spur5BMHVWest,
							(* BMHV, standard (slow!) trace formula *)
							traceListChiral = traceListChiral/. spurHead -> spur5BMHVNoWest
						],
					(* Any other combination of $Larin and $BreitMaison doesn't describe a valid scheme *)
					True,
						Message[DiracTrace::ilsch, $BreitMaison, $Larin];
						Abort[]
				]
			];

			FCPrint[1,"DiracTrace: diracTraceEvaluate: Done calculating chiral traces, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->diTrVerbose];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: traceListChiral", traceListChiral, FCDoControl->diTrVerbose];

			(* Check that there are no uncomputed traces left *)
			If[	!FreeQ2[traceListChiral,{spurHead,DiracGamma,trace5}],
				Message[DiracTrace::failmsg, "Not all chiral traces were evaluated."];
				Abort[]
			];

			(* 	Expansion of scalar products. If some of the scalar products were arlready defined,
				they will be inserted here.	*)
			If[ OptionValue[DiracTrace,{opts},Expand],
				time2=AbsoluteTime[];
				FCPrint[1,"DiracTrace: diracTraceEvaluate: Expanding scalar products", FCDoControl->diTrVerbose];
				traceListNonChiral=Map[ExpandScalarProduct[#,FCI->False]&,traceListNonChiral];
				traceListChiral=Map[ExpandScalarProduct[#,FCI->False]&,traceListChiral];
				gammaFree=ExpandScalarProduct[gammaFree,FCI->False];
				gammaPart=ExpandScalarProduct[gammaPart,FCI->False];
				FCPrint[1,"DiracTrace: diracTraceEvaluate: Done expanding the result, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->diTrVerbose]
			];

			(* Create the substitution rule*)
			repRule = MapThread[Rule[#1,#2]&,{spurHeadListChiral,traceListChiral}];
			repRule = Join[repRule,MapThread[Rule[#1,#2]&,{spurHeadListNonChiral,traceListNonChiral}]];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: repRule: ", traceListChiral, FCDoControl->diTrVerbose];
			(* The trace of any standalone Dirac matrix is zero, g^6 and g^7 are of course special *)
			tmp = (gammaFree/. wrapRule) + (gammaPart/.repRule);

			FCPrint[3,"DiracTrace: diracTraceEvaluate: tmp: ", tmp, FCDoControl->diTrVerbose];

			If[	!FreeQ2[tmp /. noSpur[__]:>1,{spurHead,DiracGamma}],
				Message[DiracTrace::failmsg, "Something went wrong while substituting trace results."];
				Abort[]
			];

		];

		FCPrint[1,"DiracTrace: diracTraceEvaluate: Main part finished, timing:",N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];

		(*	At this point there should be no Dirac matrices left, by definition.
			The only allowed exception are objects wrapped into noSpur *)
		If[ !FreeQ[tmp /. noSpur[__]:>1 ,DiracGamma],
			Message[DiracTrace::failmsg,"The output still contains Dirac matrices"];
			Abort[]
		];

		(* If there are uncontracted Lorentz indices, try to contract them *)
		If[ (contract===True || (NumberQ[contract] && LeafCount[tmp] < contract)) && !FreeQ[tmp, LorentzIndex],
			time=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Contracting Lorentz indices. ", FCDoControl->diTrVerbose];
			tmp=Contract[tmp];
			FCPrint[3,"DiracTrace: diracTraceEvaluate: After Contract: ", tmp, FCDoControl->diTrVerbose];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Contract done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose]
		];


		(* Special expansion for expressions that contain Levi-Civita tensors*)
		If[ !FreeQ[tmp, Eps],
			time=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Treating Eps tensors.", FCDoControl->diTrVerbose];
			tmp = EpsEvaluate[tmp]//Expand;
			tmp = Contract[ tmp, EpsContract -> OptionValue[DiracTrace,{opts},EpsContract],
								Schouten->schoutenopt, Expanding -> False ];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Done with Eps tensors, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose]
		];

		(* Factor the result, if requested; This is where we put back the prefactor of 4. *)
		time=AbsoluteTime[];
		FCPrint[1,"DiracTrace: diracTraceEvaluate: Factoring the result.", FCDoControl->diTrVerbose];
		If[ diractrfact===True,
			diractrres = Factor2[unitMatrixTrace tmp],
			If[ diractrfact===False,
				diractrres = unitMatrixTrace tmp,
				diractrres = diractrfact[unitMatrixTrace tmp]
			]
		];
		FCPrint[3,"DiracTrace: diracTraceEvaluate: After factoring: ", tmp, FCDoControl->diTrVerbose];
		FCPrint[1,"DiracTrace: diracTraceEvaluate: Factoring done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];

		diractrpc[x__] :=
			Plus[x]/;FreeQ[{x},Pair];
		(* If the result should be collected w.r.t Pairs *)
		If[ diractrcoll===True,
			time=AbsoluteTime[];
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Collecting the result w.r.t Pairs.", FCDoControl->diTrVerbose];
			diractrpc[x__] :=
				Collect2[ Plus[x],Pair ,Factoring -> False];
			diractrres = diractrres/. Plus -> diractrpc;
			FCPrint[1,"DiracTrace: diracTraceEvaluate: Collecting done, timing", N[AbsoluteTime[] - time, 4],  FCDoControl->diTrVerbose];


		];

		FCPrint[1,"DiracTrace: diracTraceEvaluate: Leaving.", FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrace: diracTraceEvaluate: Leaving with: ", diractrres, FCDoControl->diTrVerbose];
		diractrres
	];


fastExpand[xx_] :=
	Replace[xx, p_. Times[a__, x_Plus] :> Distribute[p a*x, Plus], 1];

(* ------------------------------------------------------------------------ *)

spurNo5[x__DiracGamma]:=
	traceNo5Wrap[Sequence@@(First/@{x})]/; EvenQ[Length[{x}]];


(*	traceNo5Wrap is a higher level function that handles the computation of traces without gamma 5,
	all indices different.  The trick here 	is that as soon as we compute a trace for a given number of Dirac matrices,
	we define it is a function (traceNo5fun) so that the result can be retrieved very fast. Combined with the the fast expansion
	using fastExpand this provides a rather quick way to obtain Dirac traces. The bottlenecks here are the amount of RAM required
	for caching and the general slowness of Mathematica on very large expressions. Traces with up to 14 Dirac matrices should be fine,
	after that it becomes too slow *)
traceNo5Wrap[SI1_, SI2__] :=
	Block[{res, repRule, tab, set, SI, args, setDel, tmpRes, finalRes},

		tab = Table[ ToExpression["MySI" <> ToString[i]], {i, 1, Length[{SI1, SI2}]}];
		finalRes = traceNo5Fun @@ {SI1, SI2};

		If[Head[finalRes] === traceNo5Fun,
			(* The trace needs to be computed *)
			tmpRes = traceNo5 @@ tab;
			If[	($MemoryAvailable - MemoryInUse[]/1000000.) >1. ,
				(* If there is enough memory, we save the computed result as a function *)
				args = Sequence @@ (Pattern[#, _] & /@ tab);
				setDel[traceNo5Fun[args], fastExpand[tmpRes]] /. setDel -> SetDelayed;
				res = traceNo5Fun @@ {SI1, SI2},
				(* No memoization if we have not enough memory *)
				res = tmpRes /. Thread[Rule[tab, {SI1,SI2}]]

			],
			(* The trace has already been computed *)
			res = finalRes
		];

		res
	]/; EvenQ[Length[{SI1,SI2}]];

traceNo5Wrap[] =
	1;

(* 	traceNo5 is the lower level function that computes only indices of type S[1],S[2],... and
	remembers its values. It's based on Thomas Hahn's famous Trace4  function *)
traceNo5[SI1_, SI2__] :=
	Block[{head, s = -1, res},
		res = Plus @@ MapIndexed[((s = -s) Pair[SI1, #1] Drop[head[SI2], #2]) &, {SI2}];
		res = res /. head -> traceNo5Wrap;
		res
	]/; EvenQ[Length[{SI1,SI2}]];

(* ------------------------------------------------------------------------ *)

spur5In4Dim[x__DiracGamma, DiracGamma[5]]:=
	trace5Wrap[Sequence@@(First/@{x,DiracGamma[5]})]/; EvenQ[Length[{x}]];


(* 	trace5Wrap computes a 4-dimensional trace of Dirac matrices with one gamma 5 using
	similar tricks as traceNo5Wrap. *)
trace5Wrap[SI1__, 5] :=
	Block[{res, repRule, tab, set, args, setDel, tmpRes, realRes},
		tab = Table[ToExpression["MySI" <> ToString[i]], {i, 1, Length[{SI1}]}];

		realRes = trace5Fun @@ {SI1, 5};

		If[Head[realRes] === trace5Fun,
			(* The trace needs to be computed *)
			tmpRes = trace5 @@ (Join[tab, {5}]);
			If[	($MemoryAvailable - MemoryInUse[]/1000000.) >1. ,
				(* If there is enough memory, we save the computed result as a function *)
				args = Sequence @@ Join[(Pattern[#, _] & /@ tab), {5}];
				setDel[trace5Fun[args], fastExpand[tmpRes]] /. setDel -> SetDelayed;
				res = trace5Fun @@ {SI1, 5},
				(* No memoization if we have not enough memory *)
				res = tmpRes /. Thread[Rule[tab, {SI1}]]

			],
			(* The trace has already been computed *)
			res = realRes
		];
		res
	];

trace5[SI1_, SI2__, mu_, nu_, rho_, 5] :=
	Pair[mu, nu] trace5[SI1, SI2, rho, 5] -
	Pair[mu, rho] trace5[SI1, SI2, nu, 5] +
	Pair[nu, rho] trace5[SI1, SI2, mu, 5] -
	$LeviCivitaSign I traceEpsNo5[mu, nu, rho, SI1, SI2];


(* This is for output similar to FORM
trace5[mu_, nu_, rho_, SI1_, SI2__, 5] :=
	Pair[mu, nu] trace5[rho, SI1, SI2, 5] -
	Pair[mu, rho] trace5[nu, SI1, SI2, 5] +
	Pair[nu, rho] trace5[mu, SI1, SI2, 5] +
	$LeviCivitaSign I traceEpsNo5[mu, nu, rho, SI1, SI2]
*)

trace5[a_, b_, c_, d_, 5]:=
	$LeviCivitaSign I Eps[a, b, c, d];

traceEpsNo5[mu_, nu_, rho_, SI2__] :=
	Block[{head, s = -1, res},
		res = Plus @@ MapIndexed[((s = -s) Eps[mu, nu, rho, #1] Drop[head[SI2], #2]) &, {SI2}];
		res = res /. head -> traceNo5Wrap;
		res
	];


(* ------------------------------------------------------------------------ *)

spur5Larin[x__DiracGamma, y:DiracGamma[_[_,dim_],dim_], DiracGamma[5]]:=
	Block[{li1,li2,li3, res},
		{li1,li2,li3} = LorentzIndex[#,dim]& /@ Unique[{"larLia","larLib","larLic"}];
		If[ FCGetDimensions[{x}]=!={dim},
			Message[DiracTrace::failmsg, "Traces with mixed dimensions are forbidden in Larin's scheme."];
			Abort[]
		];
		res = I/6 $LeviCivitaSign Eps[y[[1]], li1, li2, li3,  Dimension->dim] spurNo5[x,DiracGamma[li1,dim],DiracGamma[li2,dim],	DiracGamma[li3,dim]];
		If[ FCGetDimensions[{res}]=!={dim},
			Message[DiracTrace::failmsg, "Something went wrong while computing trace in Larin's scheme."];
			Abort[]
		];
		res
	]/; EvenQ[Length[{x,y}]];

spur5BMHVWest[x__DiracGamma, DiracGamma[5]]:=
	Block[{spx = {x,DiracGamma[5]},spt,res},
		res = 2/(Length[spx]-5) Sum[(-1)^(i+j+1) FCUseCache[ExpandScalarProduct,{Pair[spx[[i]][[1]],spx[[j]][[1]]]},{FCI->False}] *
			spt@@Delete[spx,{{j},{i}}],	{i,2,Length[spx]-1},{j,1,i-1}];
		res = Expand[res]/.spt-> spur5BMHVWest;
		res
	]/; EvenQ[Length[{x}]] && Length[{x}]>4;

spur5BMHVWest[x_DiracGamma,y_DiracGamma,r_DiracGamma,z_DiracGamma, DiracGamma[5]] :=
	EpsEvaluate[$LeviCivitaSign I Eps[x[[1]],y[[1]],r[[1]],z[[1]]]];


spur5BMHVNoWest[x__DiracGamma, DiracGamma[5]]:=
	Block[{li1,li2,li3,li4, res},
		{li1,li2,li3,li4} = LorentzIndex/@ Unique[{"bmLia","bmLib","bmLic","bmLid"}];
		res =  I/24 $LeviCivitaSign Expand2[Eps[li1, li2, li3, li4] spurNo5[x,DiracGamma[li1],DiracGamma[li2],	DiracGamma[li3], DiracGamma[li4]],LorentzIndex]//FCFastContract;
		res
	]/; EvenQ[Length[{x}]];


FCPrint[1,"DiracTrace.m loaded."];
End[]
