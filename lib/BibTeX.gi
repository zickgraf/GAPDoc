#############################################################################
##
#W  BibTeX.gi                    GAPDoc                          Frank Lübeck
##
#H  @(#)$Id: BibTeX.gi,v 1.24 2007-05-25 14:37:36 gap Exp $
##
#Y  Copyright (C)  2000,  Frank Lübeck,  Lehrstuhl D für Mathematik,  
#Y  RWTH Aachen
##  
##  The files BibTeX.g{d,i} contain a parser for BibTeX files and some
##  functions for printing BibTeX entries in different formats.
##  

##  normalize author/editor name lists: last-name, initial(s) of first
##  name(s) and ...
##  see Lamport: LaTeX App.B 1.2
BindGlobal("NormalizedNameAndKey", function(str)
  local   nbsp,  new,  pp,  p,  a,  i,  names,  norm,  keyshort,  
          keylong,  res;
  # do almost nothing if already list of strings (e.g., from BibXMLext tools
  if IsString(str) then
    # first normalize white space inside braces { ... } and change
    # spaces to non-breakable spaces
    nbsp := CHAR_INT(160);
    new := "";
    pp := 0;
    p := Position(str, '{');
    while p <> fail do
      Append(new, str{[pp+1..p-1]});
      pp := PositionMatchingDelimiter(str, "{}", p);
      a := NormalizedWhitespace(str{[p..pp]});
      for i in [1..Length(a)] do
        if a[i] = ' ' then
          a[i] := nbsp;
        fi;
      od;
      Append(new, a);
      p := Position(str, '{', pp);
    od;
    if Length(new)>0 then
      str := Concatenation(new, str{[pp+1..Length(str)]});
    fi;
    
    # split into names:
    names := [];
    pp := 0;
    p := PositionSublist(str, "and");
    while p <> fail do
      # "and" is only delimiter if surrounded by white space
      if not (str[p-1] in WHITESPACE and Length(str)>p+2 and str[p+3] in
                 WHITESPACE) then
        p := PositionSublist(str, "and", p);
      else
        Add(names, str{[pp+1..p-2]});
        pp := p+3;
        p := PositionSublist(str, "and", pp);
      fi;
    od;
    Add(names, str{[pp+1..Length(str)]});
    
    # normalize a single name
    norm := function(str)
      local   n,  i,  lnam,  j,  fnam, fnamfull;
      # special case "et. al."
      if str="others" then
        return ["others", "", ""];
      fi;
     
      # first some normalization on the string
      RemoveCharacters(str,"[]");
      str := SubstitutionSublist(str, "~", " ");
      str := SubstitutionSublist(str, ".", ". ");
      StripBeginEnd(str, WHITESPACE);
      n := SplitString(str, "", WHITESPACE);
      # check if in "lastname, firstname" notation
      # find last ","
      i := Length(n);
      while i>0 and n[i]<>"," and n[i][Length(n[i])] <> ',' do
        i := i-1;
      od;
      if i>0 then
        # last name
        lnam := "";
        for j in [1..i] do
          Append(lnam, n[j]);
          if j < i then
            Add(lnam, ' ');
          fi;
          lnam := Filtered(lnam, x-> x<>',');
        od;
        # first name initials   -  wrong for UTF-8!
        fnam := "";
        for j in [i+1..Length(n)] do
          Add(fnam, First(n[j], x-> not x in WHITESPACE and not x in "-."));
          Append(fnam, ". ");
        od;
        fnamfull := JoinStringsWithSeparator(n{[i+1..Length(n)]}, " ");
      else
        # last name is last including words not starting with
        # capital letters
        i := Length(n);
        while i>1 and First(n[i-1], a-> a in LETTERS) in SMALLLETTERS do
          i := i-1;
        od;
        # last name 
        lnam := "";
        for j in [i..Length(n)] do
          Append(lnam, n[j]);
          if j < Length(n) then
            Add(lnam, ' ');
          fi;
        od;
        # first name capitals
        fnam := "";
        for j in [1..i-1] do
          Add(fnam, First(n[j], x-> x in LETTERS));
          Append(fnam, ". ");
        od;
        fnamfull := JoinStringsWithSeparator(n{[1..i-1]}, " ");
      fi;
      while Length(fnam) > 0 and fnam[Length(fnam)] in WHITESPACE do
        fnam := fnam{[1..Length(fnam)-1]};
      od;
      return [lnam, fnam, fnamfull];
    end;
    
    names := List(names, norm);
  else
    names := str;
  fi;
  keyshort := "";
  keylong := "";
  res := "";
  for a in names do
    if Length(res)>0 then
      Append(res, " and ");
    fi;
    Append(res, a[1]);
    Append(res, ", ");
    Append(res, a[2]);
    if a[1] = "others" then
      Add(keyshort, '+');
    else
      p := 1;
      while p <= Length(a[1]) and not a[1][p] in CAPITALLETTERS do
        p := p+1;
      od;
      if p > Length(a[1]) then
        p := 1;
      fi;
      if a[1][p] in LETTERS then
        Add(keyshort, a[1][p]);
      else
        Add(keyshort, 'X');
      fi;
      Append(keylong, STRING_LOWER(Filtered(a[1]{[p..Length(a[1])]},
              x-> x in LETTERS)));
    fi;
  od;
  if Length(keyshort)>3 then
    keyshort := keyshort{[1,2]};
    Add(keyshort, '+');
  fi;
  return [res, keyshort, keylong, names];
end);

##  <#GAPDoc Label="ParseBibFiles">
##  <ManSection >
##  <Func Arg="bibfile" Name="ParseBibFiles" />
##  <Returns>list <C>[list of bib-records, list of abbrevs, list  of 
##  expansions]</C></Returns>
##  <Description>
##  This function parses a file <A>bibfile</A> (if this file does not
##  exist the  extension <C>.bib</C> is appended)  in &BibTeX; format
##  and returns a list  as follows: <C>[entries, strings, texts]</C>.
##  Here <C>entries</C>  is a  list of records,  one record  for each
##  reference  contained in  <A>bibfile</A>.  Then <C>strings</C>  is
##  a  list of  abbreviations  defined  by <C>@string</C>-entries  in
##  <A>bibfile</A> and <C>texts</C>  is a list which  contains in the
##  corresponding position  the full  text for such  an abbreviation.
##  <P/>
##  
##  The records in <C>entries</C> store key-value pairs of a &BibTeX;
##  reference in the  form <C>rec(key1 = value1,  ...)</C>. The names
##  of  the  keys are  converted  to  lower  case.  The type  of  the
##  reference (i.e.,  book, article,  ...) and  the citation  key are
##  stored as  components <C>.Type</C> and <C>.Label</C>. The records
##  also have a   <C>.From</C> field that says that the data are read 
##  from a &BibTeX; source.<P/>
##  
##  As an example consider the following &BibTeX; file.
##  
##  <Listing Type="doc/test.bib">
##  @string{ j  = "Important Journal" }
##  @article{ AB2000, Author=  "Fritz A. First and Sec, X. Y.", 
##  TITLE="Short", journal = j, year = 2000 }
##  </Listing> 
##  
##  <Example>
##  gap> bib := ParseBibFiles("doc/test.bib");
##  [ [ rec( From := rec( BibTeX := true ), Type := "article", 
##            Label := "AB2000", author := "Fritz A. First and Sec, X. Y."
##              , title := "Short", journal := "Important Journal", 
##            year := "2000" ) ], [ "j" ], [ "Important Journal" ] ]
##  </Example>
##  </Description>
##  </ManSection>
##  <#/GAPDoc>
##  
InstallGlobalFunction(ParseBibFiles, function(arg)
  local   file,  str,  stringlabels,  strings,  entries,  p,  r,  pb,  s,  
          ende,  comp,  pos;
  
  stringlabels := []; 
  strings := [];
  entries := [];
  
  for file in arg do
    str := StringFile(file);
    if str=fail then
      str := StringFile(Concatenation(file, ".bib"));
    fi;
    if str=fail then 
      Info(InfoBibTools, 1, "#W WARNING: Cannot find bib-file ", 
                                                      file, "[.bib]\n");
      return fail;
    fi;

    # find entries
    p := Position(str, '@');
    while p<>fail do
      r := rec();
      # type 
      pb := Position(str, '{', p);
      s := LowercaseString(StripBeginEnd(str{[p+1..pb-1]}, WHITESPACE));
      p := pb;
      if s = "string" then
        # a string is normalized and stored for later substitutions 
        pb := Position(str, '=', p);
        Add(stringlabels, 
            LowercaseString(StripBeginEnd(str{[p+1..pb-1]}, WHITESPACE)));
        p := pb;
        pb := PositionMatchingDelimiter(str, "{}", p);
        s := StripBeginEnd(str{[p+1..pb-1]}, WHITESPACE);
        if (s[1]='\"' and s[Length(s)]='\"') or
           (s[1]='{' and s[Length(s)]='}') then
          s := s{[2..Length(s)-1]};
        fi;
        Add(strings, s);
        p := pb;
      else
        # type and label of entry
        r := rec(From := rec(BibTeX := true), Type := s);
        # end of bibtex entry, for better recovery from errors
        ende := PositionMatchingDelimiter(str, "{}", p);
        pb := Position(str, ',', p);
        if not IsInt(pb) or pb > ende then 
          # doesn't seem to be a correct entry, ignore
          p := Position(str, '@', ende);
          continue;
        fi;
        r.Label := StripBeginEnd(str{[p+1..pb-1]}, WHITESPACE);
        p := pb;
        # get the components
        pb := Position(str, '=', p);
        while pb<>fail and pb < ende do
          comp := LowercaseString(StripBeginEnd(str{[p+1..pb-1]}, 
                          Concatenation(",", WHITESPACE)));
          pb := pb+1;
          while str[pb] in WHITESPACE do
            pb := pb+1;
          od;
          p := pb;
          if str[p] = '\"' then
            pb := Position(str, '\"', p);
            # if double quote is escaped, then go to next one
            while str[pb-1]='\\' do
              pb := Position(str, '\"', pb);
            od;
            r.(comp) := str{[p+1..pb-1]};
          elif str[p] = '{' then
            pb := PositionMatchingDelimiter(str, "{}", p);
            r.(comp) := str{[p+1..pb-1]};
          else 
            pb := p+1;
            while (not str[pb] in WHITESPACE) and str[pb] <> ',' and 
                       str[pb] <> '}' do
              pb := pb+1;
            od;
            s := str{[p..pb-1]};
            # number 
            if Int(s)<>fail then
              r.(comp) := s;
            else
              # abbrev string, look up and substitute
              s := LowercaseString(s);
              pos := Position(stringlabels, s);
              if pos=fail then
                r.(comp) := Concatenation("STRING-NOT-KNOWN: ", s);
              else
                r.(comp) := strings[pos];
              fi;  
            fi;
          fi;
          p := pb+1;
          pb := Position(str, '=', p);
        od;
        Add(entries, r);
      fi;
      p := Position(str, '@', p);
    od;
  od;
  return [entries, stringlabels, strings];
end);

##  <#GAPDoc Label="NormalizeNameAndKey">
##  <ManSection >
##  <Func Arg="namestr" Name="NormalizedNameAndKey" />
##  <Returns>list of strings and names as lists</Returns>
##  <Func Arg="r" Name="NormalizeNameAndKey" />
##  <Returns>nothing</Returns>
##  <Description>
##  The argument <A>namestr</A> must be a string describing an author or a list
##  of authors as described in the &BibTeX; documentation in <Cite  Key="La85"
##  Where="Appendix  B 1.2"/>. The function <Ref Func="NormalizedNameAndKey"
##  /> returns a list of the form [ normalized name string, short key, long
##  key, names as lists]. The first entry is a normalized form
##  of the input where names are written as <Q>lastname, first name
##  initials</Q>. The second and third entry are the name parts of a short and
##  long key for the bibliography entry, formed from the (initials of) last
##  names. The fourth entry is a list of lists, one for each name, where a 
##  name is described by three strings for the last name, the first name
##  initials and the first name(s) as given in the input. <P/>
##  
##  Note that the determination of the initials is limited to names where the
##  first letter is described by a single character (and does not contain some
##  markup, say for accents).<P/>
##  
##  The function <Ref Func="NormalizeNameAndKey"/> gets as argument <A>r</A> 
##  a record for a bibliography entry as returned by <Ref  Func="ParseBibFiles"
##  />. It substitutes  <C>.author</C> and <C>.editor</C> fields of <A>r</A> by
##  their normalized form, the original versions are stored in  fields
##  <C>.authororig</C> and <C>.editororig</C>.<P/> 
##  
##  Furthermore a short and a long citation key is generated and stored
##  in components <C>.printedkey</C> (only if no <C>.key</C> is already
##  bound) and <C>.keylong</C>.<P/> 
##  
##  We continue the example from <Ref  Func="ParseBibFiles"  />.
##  
##  <Example>
##  gap> bib := ParseBibFiles("doc/test.bib");;
##  gap> NormalizedNameAndKey(bib[1][1].author);
##  [ "First, F. A. and Sec, X. Y.", "FS", "firstsec", 
##    [ [ "First", "F. A.", "Fritz A." ], [ "Sec", "X. Y.", "X. Y." ] ] ]
##  gap> NormalizeNameAndKey(bib[1][1]);
##  gap> bib[1][1];
##  rec( From := rec( BibTeX := true ), Type := "article", 
##    Label := "AB2000", author := "First, F. A. and Sec, X. Y.", 
##    title := "Short", journal := "Important Journal", year := "2000", 
##    authororig := "Fritz A. First and Sec, X. Y.", printedkey := "FS00",
##    keylong := "firstsec2000" )
##  </Example>
##  </Description>
##  </ManSection>
##  <#/GAPDoc>
##  
InstallGlobalFunction(NormalizeNameAndKey, function(b)
  local   yy,  y,  names,  nn;
  if IsBound(b.year) then
    if IsInt(b.year) then
      yy := String(b.year);
      y := String(b.year mod 100);
    else
      yy := b.year;
      y := b.year{[Length(b.year)-1, Length(b.year)]};
    fi;
  else
    yy := "";
    y := "";
  fi;
  for names in ["author", "editor"] do
    if IsBound(b.(names)) then
      nn := NormalizedNameAndKey(b.(names));
      if nn[1] <> b.(names) then
        b.(Concatenation(names, "orig")) := b.(names);
        b.(names) := nn[1];
      fi;
      if not IsBound(b.key) then
        b.printedkey := Concatenation(nn[2], y);
      fi;
      if not IsBound(b.keylong) then
        b.keylong := Concatenation(nn[3], yy);
      fi;
    fi;
  od;
  if not IsBound(b.keylong) then
    b.keylong := "xxx";
  fi;
  if not (IsBound(b.key) or IsBound(b.printedkey)) then
    b.printedkey := "xxx";
  fi;
end);

# small utility
BindGlobal("AndToCommaNames", function(str)
  local n, p, i;
  str := NormalizedWhitespace(str);
  n := 0;
  p := PositionSublist(str, " and ");
  while p <> fail do
    n := n+1;
    p := PositionSublist(str, " and ", p);
  od;
  for i in [1..n-1] do
    str := SubstitutionSublist(str, " and ", ", ", false);
  od;
  return str;
end);
  

# print out a bibtex entry, the ordering of fields is normalized and
# type and field names are in lowercase, also some formatting is done
# arg: entry[, abbrevs, texts]    where abbrevs and texts are lists
#      of same length abbrevs[i] is string macro for texts[i]
InstallGlobalFunction(StringBibAsBib, function(arg)
  local r, abbrevs, texts, res, ind, fieldlist, pos, lines, comp;
  
  # scan arguments
  r := arg[1];
  if Length(arg)>2 then
    abbrevs := arg[2];
    texts := arg[3];
  else
    abbrevs := [];
    texts := [];
  fi;

  res := "";
  
  if not IsBound(r.Label) then
    Info(InfoBibTools, 1, "#W WARNING: no .Label in Bib-record");
    Info(InfoBibTools, 2, ":\n", r);
    Info(InfoBibTools, 1, "\n");
    
    return fail;
  fi;
  ind := RepeatedString(' ', 22);
  fieldlist := [
                "author",
                "editor",
                "booktitle",
                "title",
                "journal",
                "month",
                "organization",
                "publisher",
                "school",
                "edition",
                "series",
                "volume",
                "number",
                "address",
                "year",
                "pages",
                "chapter",
                "crossref",
                "note",
                "notes",
                "howpublished", 
                "key",
                "coden", 
                "fjournal", 
                "isbn", 
                "issn", 
                "location", 
                "mrclass", 
                "mrnumber", 
                "mrreviewer", 
                "organisation", 
                "reviews", 
                "source", 
                "url",
                "keywords" ];

  Append(res, Concatenation("@", r.Type, "{ ", r.Label));
  for comp in Concatenation(fieldlist,
          Difference(NamesOfComponents(r), Concatenation(fieldlist,
                ["From", "Type", "Label","authorAsList", "editorAsList"]) )) do
    if IsBound(r.(comp)) then
      Append(res, Concatenation(",\n  ", comp, " = ", 
                                  List([1..16-Length(comp)], i-> ' ')));
      pos := Position(texts, r.(comp));
      if pos <> fail then
        Append(res, abbrevs[pos]);
      else
        Append(res, "{");
        lines := FormatParagraph(r.(comp), 54, "both", [ind, ""]);
        Append(res, lines{[Length(ind)+1..Length(lines)-1]});
        Append(res, "}");
      fi;
    fi;
  od;
  Append(res, "\n}\n");
  return res;
end);
InstallGlobalFunction(PrintBibAsBib, function(arg)
  PrintFormattedString(CallFuncList(StringBibAsBib, arg));
end);

##  <#GAPDoc Label="WriteBibFile">
##  <ManSection >
##  <Func Arg="bibfile, bib" Name="WriteBibFile" />
##  <Returns>nothing</Returns>
##  <Description>
##  This  is   the  converse  of  <Ref  Func="ParseBibFiles"/>.  Here
##  <A>bib</A>  must  have  a  format  as  it  is  returned  by  <Ref
##  Func="ParseBibFiles"/>. A &BibTeX; file <A>bibfile</A> is written
##  and  the  entries are  formatted  in  a  uniform way.  All  given
##  abbreviations are used while writing this file.<P/>
##  
##  We continue the example from <Ref   Func="NormalizeNameAndKey"/>.
##  The command
##  
##  <Example>
##  gap> WriteBibFile("nicer.bib", bib);
##  </Example>
##  
##  produces a file <F>nicer.bib</F> as follows:
##  
##  <Listing Type="nicer.bib">
##  @string{j = "Important Journal" }
##  
##  @article{ AB2000,
##    author =           {First, F. A. and Sec, X. Y.},
##    title =            {Short},
##    journal =          j,
##    year =             {2000},
##    authororig =       {Fritz A. First and Sec, X. Y.},
##    keylong =          {firstsec2000},
##    printedkey =       {FS00}
##  }
##  </Listing>
##  </Description>
##  </ManSection>
##  <#/GAPDoc>
##  
InstallGlobalFunction(WriteBibFile, function(file, bib)
  local   p,  b3,  a,  b,  pos,  f;
  
  # collect abbrevs 
  p := [];
  SortParallel(bib[3], bib[2]);
  b3 := Immutable(bib[3]);
  IsSet(b3);
  for a in bib[1] do
    for b in NamesOfComponents(a) do
      pos := Position(b3, a.(b));
      if pos <> fail then
        Add(p, pos);
      fi;
    od;
  od;
  p := Set(p);
  
  f := function()
    local   i,  a;
    Print("\n\n");
    # the `string's
    for i in p do
      Print("@string{", bib[2][i], " = \"", b3[i], "\" }\n");
    od;        
    Print("\n\n");  
    for a in bib[1] do
      PrintBibAsBib(a, bib[2], b3);
    od;
  end;
  
  PrintTo1(file, f);
end);

# a utility for translating LaTeX macros for non ascii characters into
# HTML entities; also removing {}'s, and "\-" hyphenation hints.
BindGlobal("LaTeXToHTMLString", function(str)
  local trans_bs, trans_qq, i, pos;
  # macros for accents starting with '\', add new entries - somehow more
  # frequent ones first - as they become necessary
  trans_bs := [ ["\\\"a","&auml;"], ["\\\"o","&ouml;"], ["\\\"u","&uuml;"],
                ["\\\"{a}","&auml;"], ["\\\"{o}","&ouml;"], 
                ["\\\"{u}","&uuml;"], ["\\\"{s}","&szlig;"], 
                ["\\\"s","&szlig;"], ["\\3","&szlig;"], ["\\ss","&szlig;"],
                ["\\\"A","&Auml;"], ["\\\"O","&Ouml;"], ["\\\"U","&Uuml;"],
                ["\\'e","&eacute;"], ["\\`e","&egrave;"], 
                ["\\'E","&Eacute;"], ["\\`E","&Egrave;"],
                ["\\'a","&aacute;"], ["\\`a","&agrave;"],
                ["\\c{c}", "&ccedil;"], ["\\c c", "&ccedil;"], 
                # long Hungarian umlaut, substituted by unicode entity
                #    (see http://www.unicode.org/charts/)
                ["\\H{o}", "&#x0151;"], ["\\H o", "&#x0151;"],
                ["\\'A","&Aacute;"], ["\\'I","&Iacute;"], ["\\'O","&Oacute;"],
                ["\\'U","&Uacute;"], ["\\'i","&iacute;"],
                ["\\'o","&oacute;"], ["\\'u","&uacute;"],
                ["\\`A","&Agrave;"], ["\\`I","&Igrave;"], ["\\`O","&Ograve;"],
                ["\\`U","&Ugrave;"], ["\\`i","&igrave;"],
                ["\\`o","&ograve;"], ["\\`u","&ugrave;"] 
                ];
  # and some starting with '"' from 'german' styles
  trans_qq := [ ["\"a","&auml;"], ["\"o","&ouml;"], ["\"u","&uuml;"],
                ["\"s","&szlig;"],  ["\"A","&Auml;"], ["\"O","&Ouml;"], 
                ["\"U","&Uuml;"] ];
                
  i := 0; pos := Position(str, '\\');
  while pos <> fail and i < Length(trans_bs) do
    i := i + 1;
    str := ReplacedString(str, trans_bs[i][1], trans_bs[i][2]);
    pos := Position(str, '\\');
  od;
  i := 0; pos := Position(str, '\"');
  while pos <> fail and i < Length(trans_qq) do
    i := i + 1;
    str := ReplacedString(str, trans_qq[i][1], trans_qq[i][2]);
    pos := Position(str, '\"');
  od;
  # throw away {}'s and "\-"'s
  if Position(str, '{') <> fail then
    str := Filtered(str, c-> c <> '{' and c <> '}');
  fi;
  str := ReplacedString(str, "\\-", "");

  return str;
end);
                
##  arg: r[, escape]  (with escape = false it is assumed that entries are
##                     already HTML)
InstallGlobalFunction(StringBibAsHTML, function(arg)
  local   r,  i, str, res, esc, key;
  r := arg[1];
  if Length(arg)=2 then
    esc := arg[2];
  else
    if IsBound(r.From) and IsBound(r.From.BibXML) and r.From.BibXML = true then
      esc := false;
    else
      esc := true;
    fi;
  fi;
  
  if not IsBound(r.Label) then
    Info(InfoBibTools, 1, "#W WARNING: no .Label in Bib-record");
    Info(InfoBibTools, 2, ":\n", r);
    Info(InfoBibTools, 1, "\n");
    return fail;
  fi;

  res := "";

  # remove SGML markup characters in entries and translate
  # LaTeX macros for accented characters to HTML, remove {}'s
  if esc = true then
    r := ShallowCopy(r);
    for i in NamesOfComponents(r) do
      if IsString(r.(i)) then
        str := "";
        GAPDoc2HTMLProcs.PCDATAFILTER(rec(content := r.(i)), str);
        if str <> r.(i) then
          r.(i) := str;
        fi;
        r.(i) := LaTeXToHTMLString(r.(i));
        if i in ["title", "subtitle", "booktitle"] then
          r.(i) := Filtered(r.(i), x -> not x in "{}");
        fi;
      fi;
    od;
  fi;
  
  if IsBound(r.key) then
    key := r.key;
  elif IsBound(r.printedkey) then
    key := r.printedkey;
  else
    key := r.Label;
  fi;
  if IsBound(r.mrnumber) then
    Append(res, Concatenation(
      "<p class='Bib_entry'>\n[<span class='Bib_keyLink'><a href=\"http://www.ams.org/mathscinet-getitem?mr=",
      r.mrnumber{[1..9]}, "\">", key, "</a></span>]   "));
  else
    Append(res, Concatenation("<p class='Bib_entry'>\n[<span class='Bib_key' style=\"color: #8e0000;\">", 
                    key, "</span>]   "));
  fi;
  # we assume with the "," delimiters that at least one of .author,
  # .editor or .title exist
  if IsBound(r.author) then
    Append(res, Concatenation("<b class='Bib_author'>", AndToCommaNames(r.author),"</b> "));
  fi;
  if IsBound(r.editor) then
    Append(res, Concatenation("(<span class='Bib_editor'>", AndToCommaNames(r.editor), "</span>, Ed.)"));
  fi;
  if IsBound(r.title) then
#      if IsBound(r.author) or IsBound(r.editor) then
#        Append(str, ",\n ");
#      fi;
    Append(res, Concatenation("<i class='Bib_title'>", r.title, "</i>"));
  fi;
  if IsBound(r.booktitle) then
    if r.Type in ["inproceedings", "incollection"] then
      Append(res, " in ");
    fi;
    Append(res, Concatenation(",\n <i class='Bib_booktitle'>", r.booktitle, "</i>"));
  fi;
  if IsBound(r.subtitle) then
    Append(res, Concatenation(",\n <i class='Bib_subtitle'>&ndash;", r.subtitle, "</i>"));
  fi;
  if IsBound(r.journal) then
    Append(res, Concatenation(",\n <span class='Bib_journal'>", r.journal, "</span>"));
  fi;
  if IsBound(r.organization) then
    Append(res, Concatenation(",\n <span class='Bib_organization'>", r.organization, "</span>"));
  fi;
  if IsBound(r.publisher) then
    Append(res, Concatenation(",\n <span class='Bib_publisher'>", r.publisher, "</span>"));
  fi;
  if IsBound(r.school) then
    Append(res, Concatenation(",\n <span class='Bib_school'>", r.school, "</span>"));
  fi;
  if IsBound(r.edition) then
    Append(res, Concatenation(",\n <span class='Bib_edition'>", r.edition, "edition", "</span>"));
  fi;
  if IsBound(r.series) then
    Append(res, Concatenation(",\n <span class='Bib_series'>", r.series, "</span>"));
  fi;
  if IsBound(r.volume) then
    Append(res, Concatenation(",\n <em class='Bib_volume'>", r.volume, "</em>"));
  fi;
  if IsBound(r.number) then
    Append(res, Concatenation(" (<span class='Bib_number'>", r.number, ")", "</span>"));
  fi;
  if IsBound(r.address) then
    Append(res, Concatenation(",\n <span class='Bib_address'>", r.address, "</span>"));
  fi;
  if IsBound(r.year) then
    Append(res, Concatenation(",\n (<span class='Bib_year'>", r.year, ")", "</span>"));
  fi;
  if IsBound(r.pages) then
    Append(res, Concatenation(",\n <span class='Bib_pages'>p. ", r.pages, "</span>"));
  fi;
  if IsBound(r.chapter) then
    Append(res, Concatenation(",\n <span class='Bib_chapter'>Chapter ", r.chapter, "</span>"));
  fi;
  if IsBound(r.note) then
    Append(res, Concatenation("<br />\n(<span class='Bib_note'>", r.note, "</span>", ")<br />\n"));
  fi;
  if IsBound(r.notes) then
    Append(res, Concatenation("<br />\n(<span class='Bib_notes'>", r.notes, "</span>", ")<br />\n"));
  fi;
  if IsBound(r.howpublished) then
    Append(res, Concatenation(",\n<span class='Bib_howpublished'>", r.howpublished, "</span>", "\n"));
  fi;
 
  if IsBound(r.BUCHSTABE) then
    Append(res, Concatenation("<br />\nEinsortiert unter ", 
                                r.BUCHSTABE, ".<br />\n"));
  fi;
  if IsBound(r.LDFM) then
    Append(res, Concatenation("Signatur ", r.LDFM, ".<br />\n"));
  fi;
  if IsBound(r.BUCHSTABE) and i>=0 then
    Append(res, Concatenation("<a href=\"HTMLldfm", r.BUCHSTABE, ".html#", i, 
          "\"><span style=\"color: red;\">BibTeX Eintrag</span></a>\n<br />"));
  fi;
  Append(res, "</p>\n\n");
  return res;
end);

InstallGlobalFunction(PrintBibAsHTML, function(arg)
  PrintFormattedString(CallFuncList(StringBibAsHTML, arg));
end);

##  arg: r[, ansi]  (for link to BibTeX)
InstallGlobalFunction(StringBibAsText, function(arg)
  local r, ansi, str, txt, s, f, field;
  r := arg[1];
  ansi := rec(
    Bib_reset := TextAttr.reset,
    Bib_author := Concatenation(TextAttr.bold, TextAttr.1),
    Bib_editor := ~.Bib_author,
    Bib_title := TextAttr.4,
    Bib_subtitle := ~.Bib_title,
    Bib_journal := "",
    Bib_volume := TextAttr.4,
    Bib_Label := TextAttr.3,
    Bib_edition := ["", " edition"],
    Bib_year := [" (", ")"],
    Bib_note := ["(", ")"],
    Bib_chapter := ["Chapter ", ""],
  );
  if Length(arg) = 2  and arg[2] <> true then
    for f in RecFields(arg[2]) do
      ansi.(f) := arg[2].(f);
    od;
  elif IsBound(r.From) and IsBound(r.From.options) and
            IsBound(r.From.options.ansi) then
    for f in RecFields(r.From.options.ansi) do
      ansi.(f) := r.From.options.ansi.(f);
    od;
  else
    for f in RecFields(ansi) do
      ansi.(f) := "";
    od;
  fi;
  
  if not IsBound(r.Label) then
    Info(InfoBibTools, 1, "#W WARNING: no .Label in Bib-record");
    Info(InfoBibTools, 2, ":\n", r);
    Info(InfoBibTools, 1, "\n");
    return;
  fi;
  str := "";
  # helper adds markup
  txt := function(arg)
    local field, s, pp, pre, post;
    field := arg[1];
    if Length(arg) > 1 then
      s := arg[2];
    elif IsBound(r.(field)) then
      s := r.(field);
    else
      return;
    fi;
    if not IsBound(ansi.(Concatenation("Bib_", field))) then
      Append(str, s);
    else
      pp := ansi.(Concatenation("Bib_", field));
      if not IsString(pp) then
        pre := pp[1];
        post := pp[2];
      else
        pre := pp;
        post := ansi.Bib_reset;
      fi;
      Append(str, pre);
      Append(str, s);
      Append(str, post);
    fi;
  end;
  if IsBound(r.key) then
    s := r.key;
  elif IsBound(r.printedkey) then
    s := r.printedkey;
  else
    s := r.Label;
  fi;
  Add(str, '['); txt("Label", s); Append(str, "] ");

  # we assume with the "," delimiters that at least one of .author,
  # .editor or .title exist
  txt("author");
  if IsBound(r.editor) then
    Append(str, " ("); txt("editor"); Append(str, ", Ed.)");
  fi;
  if IsBound(r.title) then
    if IsBound(r.author) or IsBound(r.editor) then
      Append(str, ", ");
    fi;
    txt("title");
  fi;
  if IsBound(r.booktitle) then
    Append(str, ", ");
    if r.Type in ["inproceedings", "incollection"] then
      Append(str, " in ");
    fi;
    txt("booktitle");
  fi;
  if IsBound(r.subtitle) then
    Append(str, "--"); txt("subtitle");
  fi;

  for field in [ "journal", "organization", "publisher", "school",
                 "edition", "series", "volume", "number", "address",
                 "year", "pages", "chapter", "note", "howpublished" ] do
    if IsBound(r.(field)) then
      if field <> "year" then
        Append(str, ", "); 
      fi;
      txt(field);
    fi;
  od;
  
  # some LDFM specific
  if IsBound(r.BUCHSTABE) then
    Append(str, Concatenation(", Einsortiert unter ", r.BUCHSTABE));
  fi;
  if IsBound(r.LDFM) then
    Append(str, Concatenation(", Signatur ", r.LDFM));
  fi;

##    str := FormatParagraph(Filtered(str, x-> not x in "{}"), 72);
  str := FormatParagraph(str, 72);
  Add(str, '\n');
  return str;
end);

InstallGlobalFunction(PrintBibAsText, function(arg)
  PrintFormattedString(CallFuncList(StringBibAsText, arg));
end);


