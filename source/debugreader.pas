{
    This file is part of Dev-C++
    Copyright (c) 2004 Bloodshed Software

    Dev-C++ is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Dev-C++ is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Dev-C++; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit debugreader;

interface

uses 
{$IFDEF WIN32}
  Sysutils, Classes, Windows, ShellAPI,
  version, Dialogs, editor, ComCtrls, StrUtils, Forms;
{$ENDIF}
{$IFDEF LINUX}
  Sysutils, Classes, debugreader,
  version, QDialogs, QComCtrls, StrUtils, QForms;
{$ENDIF}

type
  TAnnotateType = (TPrePrompt, TPrompt, TPostPrompt,
                   TSource,
                   TDisplayBegin, TDisplayEnd,
                   TDisplayExpression,
                   TFrameSourceFile, TFrameSourceBegin, TFrameSourceLine, TFrameFunctionName, TFrameWhere,
                   TFrameArgs,
                   TFrameBegin,TFrameEnd,
                   TErrorBegin, TErrorEnd,
                   TArrayBegin, TArrayEnd,
                   TElt,TEltRep,TEltRepEnd,
                   TExit,
                   TSignal,TSignalName,TSignalNameEnd,TSignalString,TSignalStringEnd,
                   TValueHistoryValue,
                   TArgBegin, TArgEnd, TArgValue, TArgNameEnd,
                   TFieldBegin, TFieldEnd, TFieldValue, TFieldNameEnd,
                   TInfoReg, TInfoAsm,
                   TUnknown,TEOF);

  PWatchParent = ^TWatchParent;
  TWatchParent = record
    name : AnsiString;
    value : AnsiString;
    gdbindex : integer;
    node : TTreeNode;
  end;

  PWatchMember = ^TWatchMember;
  TWatchMember = record
    name : AnsiString;
    value : AnsiString;
  end;

  PBreakPoint = ^TBreakPoint;
  TBreakPoint = record
    line : integer;
    editor : TEditor;
  end;

  PTrace = ^TTrace;
  TTrace = record
    funcname : AnsiString;
    filename : AnsiString;
    line : AnsiString;
  end;

  TDebugReader = class(TThread)
  public
    hPipeRead : THandle;
    Registers : TList;
    Disassembly : TStringList; // convert to TList with proper data formatting?
    Backtrace : TList;
    BreakpointList : TList;
    WatchVarList : TList; // contains all parents
    DebugTree : TTreeView;
  private
    curpos : integer;
    len : integer;
    bline : integer;
    bfile : AnsiString;
    gdbout : AnsiString;
    evalvalue : AnsiString;
    signal : AnsiString;
    nextannotation : TAnnotateType;

	// attempt to cut down on Synchronize calls
	dobacktraceready : boolean;
	dodisassemblerready : boolean;
	doregistersready : boolean;
	dorescanwatches : boolean;
	doevalready : boolean;
	doprocessexited : boolean;
	doupdatecpuwindow : boolean;
	doupdateexecution : boolean;
	doreceivedsignal : boolean;

	// Evaluation tree output handlers
    procedure ProcessWatchStruct(parentnode : TTreeNode);
    function ProcessEvalStruct(indent : integer) : AnsiString;

    procedure Analyze;

    // synching with GUI
    procedure SyncFinishedParsing;

    // parsing
    procedure SkipSpaces; // skips space and tab
    procedure SkipToAnnotation; // skips until it finds #26#26 (GDB annotation for interfaces)
    function FindAnnotation(an : TAnnotateType) : boolean; // Finds the given annotation, returns false on EOF
    function GetNextAnnotation : TAnnotateType; // Returns the next annotation
    function PeekAnnotation : TAnnotateType; // Returns the next annotation, but does not modify current scanning positions
    function GetNextWord : AnsiString; // copies the next word, stops when it finds chars 0..32
    function GetNextLine : AnsiString; // skips until enter sequence, skips ONE enter sequence, copies until next enter sequence
    function GetNextFilledLine : AnsiString; // skips until enter sequence, skips enter sequences, copies until next enter sequence
    function GetRemainingLine : AnsiString; // copies until enter sequence

  protected
    procedure Execute; override;
  end;

implementation

uses
  main, devcfg, CPUFrm, debugger, utils;

// macro for all the things that need to be done when we are finished parsing the current block
procedure TDebugReader.SyncFinishedParsing;
begin
	if doprocessexited then begin
		MainForm.fDebugger.Stop(nil);
		Exit;
	end;

	if doreceivedsignal then
		MsgErr(signal); // can't miss that one

	if doevalready and Assigned(MainForm.fDebugger.OnEvalReady) then
		MainForm.fDebugger.OnEvalReady(evalvalue);

	// Delete unimportant stuff to reduce clutter
	gdbout := StringReplace(gdbout,#26,'->',[rfReplaceAll]);
	//gdbout := StringReplace(gdbout,'->->pre-prompt'#13#10,'',[rfReplaceAll]);
	//gdbout := StringReplace(gdbout,'->->prompt'#13#10,'',[rfReplaceAll]);
	//gdbout := StringReplace(gdbout,'->->post-prompt'#13#10,'',[rfReplaceAll]);
	MainForm.DebugOutput.Lines.Add(gdbout);
	//MainForm.DebugOutput.Lines.Add('-----------------------------');

	if Assigned(CPUForm) then begin
		if doregistersready then
			CPUForm.OnRegistersReady;

		if dodisassemblerready then
			CPUForm.OnAssemblerReady;

		if dobacktraceready then
			CPUForm.OnBacktraceReady;
	end;

	if doupdateexecution then begin
		MainForm.GotoBreakpoint(bfile, bline); // set active line
		MainForm.fDebugger.RefreshWatchVars; // update variable information
	end;

	if doupdatecpuwindow and Assigned(CPUForm) then begin
		MainForm.fDebugger.SendCommand('disas','');
		MainForm.fDebugger.SendCommand('info registers','');
		MainForm.fDebugger.SendCommand('backtrace','');
	end;
end;

procedure TDebugReader.SkipSpaces;
begin
	while (curpos < len) and (gdbout[curpos] in [#9,#32]) do
		Inc(curpos);
end;

procedure TDebugReader.SkipToAnnotation;
begin
	// Walk up to the next annotation
	while (curpos < len) and not (gdbout[curpos] in [#26]) do
		Inc(curpos);

	// Crawl through the remaining ->'s
	while (curpos < len) and (gdbout[curpos] in [#26]) do
		Inc(curpos);
end;

function TDebugReader.FindAnnotation(an : TAnnotateType) : boolean;
var
	curran : TAnnotateType;
begin
	result := false;

	repeat
		curran := GetNextAnnotation;
		if curran = TEOF then
			Exit;
	until curran = an;

	result := true;
end;

function TDebugReader.GetNextWord : AnsiString;
begin
	Result:='';

	// Called when at a space? Skip over
	SkipSpaces;

	while (curpos < len) and not (gdbout[curpos] in [#0..#32]) do begin
		Result := Result + gdbout[curpos];
		Inc(curpos);
	end;
end;

function TDebugReader.GetRemainingLine : AnsiString;
begin
	Result := '';

	// Return part of line still ahead of us
	while (curpos < len) and not (gdbout[curpos] in [#13, #10]) do begin
		Result := Result + gdbout[curpos];
		Inc(curpos);
	end;
end;

function TDebugReader.GetNextLine : AnsiString;
begin
	Result := '';

	// Walk up to an enter sequence
	while (curpos < len) and not (gdbout[curpos] in [#13, #10]) do
		Inc(curpos);

	// Skip ONE enter sequence (CRLF, CR, LF, etc.)
	if (curpos+1 < len) and (gdbout[curpos] = #13) and (gdbout[curpos] = #13) then // DOS
		Inc(curpos,2)
	else if (curpos < len) and (gdbout[curpos] = #13) then // UNIX
		Inc(curpos)
	else if (curpos < len) and (gdbout[curpos] = #10) then // MAC
		Inc(curpos);

	// Return next line
	Result := GetRemainingLine;
end;

function TDebugReader.GetNextFilledLine : AnsiString;
begin
	Result := '';

	// Walk up to an enter sequence
	while (curpos < len) and not (gdbout[curpos] in [#13, #10]) do
		Inc(curpos);

	// Skip enter sequences (CRLF, CR, LF, etc.)
	while (curpos < len) and (gdbout[curpos] in [#13, #10]) do
		Inc(curpos);

	// Return next line
	Result := GetRemainingLine;
end;

function TDebugReader.PeekAnnotation : TAnnotateType;
var
	oldpos : integer;
begin
	oldpos := curpos;
	Result := GetNextAnnotation;
	nextannotation := Result;
	curpos := oldpos;
end;

function TDebugReader.GetNextAnnotation : TAnnotateType;
var
	s : AnsiString;
	oldpos : integer;
begin
	// Skip until end of #26's, i.e. GDB formatted output
	SkipToAnnotation;

	// Get part this line, after #26#26
	s := GetNextWord;

	if SameStr(s,'pre-prompt') then
		result := TPrePrompt
	else if SameStr(s,'prompt') then
		result := TPrompt
	else if SameStr(s,'post-prompt') then begin // todo: clean up
		result := TPostPrompt;

		oldpos := curpos;
		s := GetNextFilledLine;
		curpos := oldpos;

		// Hack fix to catch register dump
		if Assigned(Registers) then
			if StartsStr('rax ',s) or StartsStr('eax ',s) then
				result := TInfoReg;

		// Another hack to catch assembler
		if Assigned(Disassembly) then
			if StartsStr('Dump of assembler code for function ',s) then
				result := TInfoAsm;

	end else if SameStr(s,'error-begin') then
		result := TErrorBegin
	else if SameStr(s,'error-end') then
		result := TErrorEnd
	else if SameStr(s,'display-begin') then
		result := TDisplayBegin
	else if SameStr(s,'display-expression') then
		result := TDisplayExpression
	else if SameStr(s,'display-end') then
		result := TDisplayEnd
	else if SameStr(s,'frame-source-begin') then
		result := TFrameSourceBegin
	else if SameStr(s,'frame-source-file') then
		result := TFrameSourceFile
	else if SameStr(s,'frame-source-line') then
		result := TFrameSourceLine
	else if SameStr(s,'frame-function-name') then
		result := TFrameFunctionName
	else if SameStr(s,'frame-args') then
		result := TFrameArgs
	else if SameStr(s,'frame-begin') then
		result := TFrameBegin
	else if SameStr(s,'frame-end') then
		result := TFrameEnd
	else if SameStr(s,'frame-where') then
		result := TFrameWhere
	else if SameStr(s,'source') then
		result := TSource
	else if SameStr(s,'exited') then
		result := TExit
	else if SameStr(s,'arg-begin') then
		result := TArgBegin
	else if SameStr(s,'arg-name-end') then
		result := TArgNameEnd
	else if SameStr(s,'arg-value') then
		result := TArgValue
	else if SameStr(s,'arg-end') then
		result := TArgEnd
	else if SameStr(s,'array-section-begin') then
		result := TArrayBegin
	else if SameStr(s,'array-section-end') then
		result := TArrayEnd
	else if SameStr(s,'elt') then
		result := TElt
	else if SameStr(s,'elt-rep') then
		result := TEltRep
	else if SameStr(s,'elt-rep-end') then
		result := TEltRepEnd
	else if SameStr(s,'field-begin') then
		result := TFieldBegin
	else if SameStr(s,'field-name-end') then
		result := TFieldNameEnd
	else if SameStr(s,'field-value') then
		result := TFieldValue
	else if SameStr(s,'field-end') then
		result := TFieldEnd
	else if SameStr(s,'value-history-value') then
		result := TValueHistoryValue
	else if SameStr(s,'signal') then
		result := TSignal
	else if SameStr(s,'signal-name') then
		result := TSignalName
	else if SameStr(s,'signal-name-end') then
		result := TSignalNameEnd
	else if SameStr(s,'signal-string') then
		result := TSignalString
	else if SameStr(s,'signal-string-end') then
		result := TSignalStringEnd
	else if (curpos = len) then
		result := TEOF
	else
		result := TUnknown;
end;

procedure TDebugReader.ProcessWatchStruct(parentnode : TTreeNode);
var
	s : AnsiString;
	newnode : TTreeNode;
	wmember : PWatchMember;
begin
	wmember := nil;
	newnode := nil;

	while curpos < len do begin
		case GetNextAnnotation of

			TFieldBegin : begin

				// Add to current parent
				wmember := new(PWatchMember);

				// Field name
				wmember^.name := GetNextLine;

				// =
				if not FindAnnotation(TFieldNameEnd) then begin
					Dispose(PWatchMember(wmember));
					Exit;
				end;

				// field value
				if not FindAnnotation(TFieldValue) then begin
					Dispose(PWatchMember(wmember));
					Exit;
				end;

				wmember^.value := GetNextLine;

				// Add node to debug tree
				newnode := DebugTree.Items.AddChildObject(parentnode,wmember^.name + ' = ' + wmember^.value,wmember);

				// This might be a struct too...
				if EndsStr('{',wmember^.value) then begin
					case PeekAnnotation of
						TFieldBegin:
							ProcessWatchStruct(newnode);
					end;
				end;
			end;

			// Add value to current indent
			TArrayBegin,TArrayEnd,TElt,TEltRep : begin

				s := GetNextLine;

				if Assigned(wmember) then // update current value
					wmember^.value := wmember^.value + s;

				if Assigned(newnode) then
					newnode.Text := wmember^.name + ' = ' + wmember^.value;
			end;

			// Add, complete current indent
			TFieldEnd : begin
				s := GetNextLine;

				// End of structure, return to parent
				if EndsStr('}',s) then
					break;
			end;
		end;
	end;
end;

function TDebugReader.ProcessEvalStruct(indent : integer) : AnsiString;
var
	i : integer;
	s : AnsiString;
begin
	result := '';
	while curpos < len do begin
		case GetNextAnnotation of

			TFieldBegin : begin

				for i := 0 to (4*indent) - 1 do
					result := result + ' ';

				// Field name
				result := result + GetNextLine;

				// =
				if not FindAnnotation(TFieldNameEnd) then Exit;

				result := result + GetNextLine;

				// field value
				if not FindAnnotation(TFieldValue) then Exit;

				s := GetNextLine;
				result := result + s;

				// This might be a struct too...
				if EndsStr('{',s) then begin
					case PeekAnnotation of
						TArrayBegin:
							result := result + ProcessEvalStruct(indent+1);
						TFieldBegin:
							result := result + #13#10 + ProcessEvalStruct(indent+1);
					end;
				end;
			end;

			// Add value to current indent
			TArrayBegin,TArrayEnd,TElt,TEltRep : begin
				s := GetNextLine;
				result := result + s;
				if EndsStr('{',s) then
					result := result + ProcessEvalStruct(indent+1)
				else if EndsStr('}',s) then
					break;
			end;

			// Add, complete current indent
			TFieldEnd : begin
				s := GetNextLine;
				result := result + ';' + #13#10;

				// End of structure, complete braces
				if EndsStr('}',s) then begin

					for i := 0 to (4*(indent-1)) - 1 do
						result := result + ' ';

					result := result + s;
					break;
				end;
			end;
		end;
	end;
end;

procedure TDebugReader.Analyze;
var
	s,t,u : AnsiString;
	i,x,y : integer;
	wparent : PWatchParent;
	node : TTreeNode;
	reg : PRegister;
	trace : PTrace;
begin

	evalvalue := '';
	len := Length(gdbout);
	curpos := 1;

	dobacktraceready := false;
	dodisassemblerready := false;
	doregistersready := false;
	dorescanwatches := false;
	doevalready := false;
	doprocessexited := false;
	doupdateexecution := false;
	doreceivedsignal := false;
	doupdatecpuwindow := false;

	while curpos < len do begin
		case GetNextAnnotation of
			TValueHistoryValue : begin
				evalvalue := GetNextLine; // value, might be empty
				if SameStr(evalvalue,'') then
					evalvalue := 'Error evaluating input'
				else if EndsStr('{',evalvalue) then begin
					case PeekAnnotation of
						TFieldBegin:
							evalvalue := evalvalue + #13#10 + ProcessEvalStruct(1);
						TArrayBegin:
							evalvalue := evalvalue + ProcessEvalStruct(1);
					end;
				end;
				doevalready := true;
			end;
			TSignal : begin

				// Assemble user string

				signal := GetNextFilledLine; // Program received signal

				if not FindAnnotation(TSignalName) then Exit;

				signal := signal + GetNextFilledLine; // signal code

				if not FindAnnotation(TSignalNameEnd) then Exit;

				signal := signal + GetNextFilledLine; // comma

				if not FindAnnotation(TSignalString) then Exit;

				signal := signal + GetNextFilledLine; // user friendly description

				if not FindAnnotation(TSignalStringEnd) then Exit;

				signal := signal + GetNextFilledLine; // period

				doreceivedsignal := true;
			end;
			TExit : begin
				doprocessexited := true;
			end;
			TFrameBegin : begin

				s := GetNextLine;

				// Is this a backtrace dump?
				if Assigned(Backtrace) and StartsStr('#',s) then begin

					trace := new(PTrace);

					// Find function name
					if not FindAnnotation(TFrameFunctionName) then begin
						Dispose(PTrace(trace));
						Exit;
					end;

					trace^.funcname := GetNextLine;

					// Find argument list start
					if not FindAnnotation(TFrameArgs) then begin
						Dispose(PTrace(trace));
						Exit;
					end;

					// Arguments are either () or detailed list
					s := GetNextLine;

					while (PeekAnnotation = TArgBegin) do begin

						// argument name
						if not FindAnnotation(TArgBegin) then begin
							Dispose(PTrace(trace));
							Exit;
						end;

						s := s + GetNextLine;

						// =
						if not FindAnnotation(TArgNameEnd) then begin
							Dispose(PTrace(trace));
							Exit;
						end;

						s := s + ' ' + GetNextLine + ' '; // should be =

						// argument value
						if not FindAnnotation(TArgValue) then begin
							Dispose(PTrace(trace));
							Exit;
						end;

						s := s + GetNextLine;

						// argument end
						if not FindAnnotation(TArgEnd) then begin
							Dispose(PTrace(trace));
							Exit;
						end;

						s := s + GetNextLine;
					end;

					trace^.funcname := trace^.funcname + Trim(s);

					// If source info can't be found, skip
					if PeekAnnotation = TFrameSourceBegin then begin

						// Find filename
						if not FindAnnotation(TFrameSourceFile) then begin
							Dispose(PTrace(trace));
							Exit;
						end;

						trace^.filename := GetNextLine;

						// find line
						if not FindAnnotation(TFrameSourceLine) then begin
							Dispose(PTrace(trace));
							Exit;
						end;

						trace^.line := GetNextLine;
					end else begin
						trace^.filename := '';
						trace^.line := '';
					end;

					Backtrace.Add(trace);

					// Skip over the remaining frame part...
					if not FindAnnotation(TFrameEnd) then Exit;

					// Not another one coming? Done!
					if PeekAnnotation <> TFrameBegin then begin

						// End of stack trace dump!
						dobacktraceready := true;
					end;
				end else
					doupdatecpuwindow := true;
			end;
			TInfoAsm : begin
				if Assigned(Disassembly) then begin

					// Get info message
					s := GetNextLine; // Dump of ... foo()

					// the current function name will be saved at index 0
					Disassembly.Add(Copy(s,37,Length(s)-37));

					s := GetNextLine;

					// Add lines of disassembly
					while not SameStr('End of assembler dump.',s) do begin
						Disassembly.Add(s);
						s := GetNextLine;
					end;

					dodisassemblerready := true;
				end;
			end;
			TInfoReg : begin
				if Assigned(Registers) then begin

					// Scan all registers until end of gdb output
					s := GetNextFilledLine;

					repeat

						// name(spaces)hexvalue(tab)decimalvalue
						reg := new(PRegister);
						x := Pos(' ',s);
						if x > 0 then begin
							reg^.name := Copy(s,1,x-1);
							y := Pos(#9,s);
							if y > 0 then
								reg^.value := Copy(s,y+1,Length(s)-y+1);
						end;

						Registers.Add(reg);

						s := GetNextFilledLine;

					until StartsStr(#26#26,s);

					doregistersready := true;
				end;
			end;
			TErrorBegin : begin
				s := GetNextLine; // error text
				if StartsStr('No symbol "',s) then begin
					x := Pos('"',s);
					y := GetLastPos('"',s);
					t := Copy(s,x+1,y-x-1);

					// Update current...
					for I := 0 to WatchVarList.Count - 1 do begin
						wparent := PWatchParent(WatchVarList.Items[I]);
						if SameStr(wparent^.name,t) then begin

							wparent^.value := 'Not found in current context';
							wparent^.node.Text := wparent^.name + ' = ' + wparent^.value;

							// Delete now invalid children
							while wparent^.node.HasChildren do begin
								node := wparent^.node.GetLastChild;
								Dispose(PWatchMember(node.Data));
								node.Delete;
							end;

							break;
						end;
					end;

					dorescanwatches := true;
				end;
			end;
			TDisplayBegin : begin

				wparent := nil;

				s := GetNextLine; // watch index

				if not FindAnnotation(TDisplayExpression) then Exit;

				t := GetNextLine; // watch name

				// Find parent we're talking about
				for I := 0 to WatchVarList.Count - 1 do begin
					wparent := PWatchParent(WatchVarList.Items[I]);
					if SameStr(wparent^.name,t) then begin

						// Delete now invalid children
						while wparent^.node.HasChildren do begin
							node := wparent^.node.GetLastChild;
							Dispose(PWatchMember(node.Data));
							node.Delete;
						end;

						break;
					end;
				end;

				if not Assigned(wparent) then Exit;

				if not FindAnnotation(TDisplayExpression) then Exit;

				u := GetNextLine; // variable value (can be empty)
				if u = '{' then // scan fields recursively
					ProcessWatchStruct(wparent^.node);

				wparent^.gdbindex := StrToInt(s);
				wparent^.value := u;
				wparent^.node.Text := wparent^.name + ' = ' + wparent^.value;
			end;
			TSource : begin // source filename:line:offset:beg/middle/end:addr
				s := TrimLeft(GetRemainingLine);

				// remove offset, beg/middle/end, address
				for I := 1 to 3 do begin
					x := Length(s);
					y := GetLastPos(':',s);
					if y > 0 then begin
						Delete(s,y,x-y+1);
					end;
				end;

				// get line
				x := Length(s);
				y := GetLastPos(':',s);
				if y > 0 then begin
					bline := StrToInt(Copy(s,y+1,x-y));
					Delete(s,y,x-y+1);
				end;

				// get file
				bfile := s;

				doupdateexecution := true;
				doupdatecpuwindow := true;
			end;
		end;
	end;

	Synchronize(SyncFinishedParsing);
end;

procedure TDebugReader.Execute;
var
	tmp : array [0..20000] of char; // should be enough for anything
	bytesread : DWORD;
begin
	bytesread := 0;
	while not Terminated do begin

		FillChar(tmp,bytesread+1,0);

		// ReadFile returns when there's something to read
		if not ReadFile(hPipeRead, tmp, 20000, bytesread, nil) or (bytesread = 0) then break;

		gdbout := gdbout + tmp;

		if not Terminated and (Pos('(gdb)',gdbout) > 0) then begin //(GDB does NOT always prompt when ready?)
			Analyze;
			gdbout := '';
		end;
	end;
end;

end.
