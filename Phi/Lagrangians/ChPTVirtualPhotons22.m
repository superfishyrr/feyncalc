(* *************************************************************** *)
(*                                                                 *)
(*                      ChPTVirtualPhotons22                       *)
(*                                                                 *)
(* *************************************************************** *)

(* 
   Author:              F.Orellana 2001

   Mathematica Version: 4.0 

   Requirements:        FeynCalc > 3, Phi 

   Summary:             Lagrangian for Phi

   Description:         The leading order ChPT lagrangian with 
                        electromagnetic couplings.
    
                        Taken from Marc Knecht and Res Urech
                        (1997), hep-ph/9709348
*)


Begin["HighEnergyPhysics`Phi`Objects`"];

ChPTVirtualPhotons22::"usage"=
   "\"ChPTVirtualPhotons22.m\" is the name of the file containing the definitions for \
Lagrangian[ChPTVirtualPhotons[2]], which is the leading order pionic \
SU(2) ChPT lagrangian with couplings to virtual photons. \
To evaluate use ArgumentsSupply";

GaugeFixingParameter::"usage"=
   "GaugeFixingParameter(=1/GaugeXi) is the gauge fixing parameter of QED in Lorentz gauge.  \
the usual choice is Feynman gauge, GaugeFixingParameter=1";

(* --------------------------------------------------------------- *)

Begin["`Private`"];

(* --------------------------------------------------------------- *)

(* Abbreviations *)

fcpd:=HighEnergyPhysics`FeynCalc`PartialD`PartialD;
fcli:=HighEnergyPhysics`FeynCalc`LorentzIndex`LorentzIndex;
fcqf:=HighEnergyPhysics`FeynCalc`QuantumField`QuantumField;

mu=(Global`\[Mu]);
nu=(Global`\[Nu]);

(* ---------------------------------------------------------------- *)

(* Box definitions *)

pt/:MakeBoxes[pt[a_],TraditionalForm]:=MakeBoxes[TraditionalForm[a]];
pt/:MakeBoxes[pt[],TraditionalForm]:="";
pt/:MakeBoxes[pt[RenormalizationState[1]],TraditionalForm]:="r";
pt/:MakeBoxes[pt[RenormalizationState[0]],TraditionalForm]:="";
    
HighEnergyPhysics`FeynCalc`CouplingConstant`CouplingConstant/:
  MakeBoxes[
    HighEnergyPhysics`FeynCalc`CouplingConstant`CouplingConstant[
  ChPTVirtualPhotons2[2],st___RenormalizationState,
      sc___RenormalizationScheme,qs___QuarkMassExpansionState],
    TraditionalForm]:=
  SuperscriptBox[MakeBoxes[StyleForm["C",FontSlant->"Italic"]][[1]],
    RowBox[Join[{MakeBoxes[TraditionalForm[pt[st]]]},{
          MakeBoxes[TraditionalForm[pt[sc]]]},{
          MakeBoxes[TraditionalForm[pt[qs]]]}]]];

GaugeFixingParameter/:
MakeBoxes[GaugeFixingParameter,TraditionalForm]:=
MakeBoxes[StyleForm["\[Lambda]",FontSlant->"Italic"]][[1]];


(* --------------------------------------------------------------- *)

SetAttributes[ChPTVirtualPhotons2,NumericFunction];

(* --------------------------------------------------------------- *)

HighEnergyPhysics`fctables`Lagrangian`Lagrangian[ChPTVirtualPhotons2[2]]:=

1/4*DecayConstant[Pion]^2*

(UTrace[ NM[CDr[MM,{mu}],Adjoint[CDr[MM,{mu}]]] ] +

UTrace[ NM[UChiMatrix,Adjoint[MM]]+NM[Adjoint[UChiMatrix],MM] ]) -

1/4*
NM[FieldStrengthTensor[fcli[mu],
fcqf[Particle[Photon],fcli[nu]]],
FieldStrengthTensor[fcli[mu],
fcqf[Particle[Photon],fcli[nu]]]]-

GaugeFixingParameter/2*
FDr[fcqf[Particle[Photon],fcli[mu]],{mu}]*
FDr[fcqf[Particle[Photon],fcli[nu]],{nu}]+

HighEnergyPhysics`FeynCalc`CouplingConstant`CouplingConstant[ChPTVirtualPhotons2[2]]*
UTrace[NM[UChiralSpurionRightMatrix, MM,
UChiralSpurionLeftMatrix, Adjoint[MM]]];
    
(* --------------------------------------------------------------- *)

FieldsSet[ChPTVirtualPhotons2[2]]:=
{IsoVector[fcqf[Particle[Pion]]],
fcqf[Particle[Photon]]};

Global`$Lagrangians=Union[Global`$Lagrangians,{ChPTVirtualPhotons2[2]}];

End[];

End[];