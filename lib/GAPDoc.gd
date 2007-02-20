#############################################################################
##
#W  GAPDoc.gd                    GAPDoc                          Frank Lübeck
##
#H  @(#)$Id: GAPDoc.gd,v 1.4 2007-02-20 16:56:27 gap Exp $
##
#Y  Copyright (C)  2000,  Frank Lübeck,  Lehrstuhl D für Mathematik,  
#Y  RWTH Aachen
##  
##  The files GAPDoc.g{d,i} contain some utilities for trees returned by
##  ParseTreeXMLString applied to a GAPDoc document.
##  

DeclareGlobalFunction("CheckAndCleanGapDocTree");
DeclareGlobalFunction("AddParagraphNumbersGapDocTree");
DeclareGlobalFunction("AddPageNumbersToSix");
DeclareGlobalFunction("PrintSixFile");
DeclareGlobalFunction("TextM");

##  <#GAPDoc Label="InfoGAPDoc">
##  <ManSection >
##  <InfoClass Name="InfoGAPDoc" />
##  <Description>
##  The default level of this info class is 1. The converter functions
##  for &GAPDoc; documents are then 
##  printing some information. You can suppress this by setting the 
##  level of <Ref InfoClass="InfoGAPDoc"/> to 0. With level 2 there
##  may be some more information for debugging purposes.
##  </Description>
##  </ManSection>
##  <#/GAPDoc>
##  
# Info class with default level 1
BindGlobal("InfoGAPDoc", NewInfoClass("InfoGAPDoc"));
SetInfoLevel(InfoGAPDoc, 1);
if CompareVersionNumbers(GAPInfo.Version, "4.dev") then
  SetInfoHandler(InfoGAPDoc, function(cl, lev, l)
    CallFuncList(Print, l);
  end);
fi;

