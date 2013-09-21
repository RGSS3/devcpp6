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
  version, Dialogs, ComCtrls, StrUtils, Forms;
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
                   TFrameSourceFile, TFrameSourceLine, TFrameFunctionName,
                   TFrameBegin,TFrameEnd,
                   TErrorBegin, TErrorEnd,
                   TExit,
                   TValueHistory,
                   TInfoReg, TInfoAsm,
                   TUnknown,TEOF);

  PWatchVar = ^TWatchVar;
  TWatchVar = record
    name : AnsiString;
    value : AnsiString;
    gdbindex : integer;
  end;

  {PInstruction = ^TInstruction;
  TInstruction = record
    address : AnsiString;
    offset : AnsiString;
    opcode : AnsiString;
    operands : AnsiString;
  end;}

  PTrace = ^TTrace;
  TTrace = record
    funcname : AnsiString;
    filename : AnsiString;
    line : AnsiString;
  end;

  TDebugReader = class(TThread)
  public
    hPipeRead : THandle;
    DebugTree : TTreeView;
    Registers : TList;
    Disassembly : TStringList; // convert to TList with proper data formatting?
    Backtrace : TList;
  protected
    curpos : integer;
    len : integer;
    bline : integer;
    bfile : AnsiString;
    gdbout : AnsiString;
    evalvalue : AnsiString;

    // main thread functions
    procedure Execute; override;
    procedure Analyze;

    // synching with GUI
    procedure SyncGotoBreakpoint;
    procedure SyncRefreshWatchVars;
    procedure SyncExited;
    procedure SyncRegistersReady;
    procedure SyncDisassemblerReady;
    procedure SyncBacktraceReady;
    procedure SyncEvaluate;
    procedure SyncOutput;

    // parsing
    procedure SkipSpaces; // skips space and tab
    procedure SkipToAnnotation; // skips until it finds #26#26 (GDB annotation for interfaces)
    function FindAnnotation(an : TAnnotateType) : boolean; // Finds the next annotation, returns false on EOF
    function GetNextAnnotation : TAnnotateType; // Returns the next annotation
    function PeekAnnotation : TAnnotateType; // Finds the next annotation, but does not modify current scanning positions
    function GetNextWord : AnsiString; // copies the next word, stops when it finds 0..32
    function GetNextLine : AnsiString; // skips until enter sequence, copies until next enter sequence
    function GetRemainingLine : AnsiString; // copies until enter sequence
  end;

implementation

uses
  main, devcfg, CPUFrm, debugger, utils;

procedure TDebugReader.SyncGotoBreakpoint;
begin
	MainForm.GotoBreakpoint(bfile, bline);
end;

procedure TDebugReader.SyncRefreshWatchVars;
begin
	MainForm.fDebugger.RefreshWatchVars;
end;

procedure TDebugReader.SyncExited;
begin
	MainForm.fDebugger.Stop(nil);
end;

procedure TDebugReader.SyncRegistersReady;
begin
	CPUForm.OnRegistersReady;
end;

procedure TDebugReader.SyncDisassemblerReady;
begin
	CPUForm.OnAssemblerReady;
end;

procedure TDebugReader.SyncBacktraceReady;
begin
	CPUForm.OnBacktraceReady;
end;

procedure TDebugReader.SyncEvaluate;
begin
	MainForm.EvalOutput.Text := evalvalue;
end;

procedure TDebugReader.SyncOutput;
begin
	// Delete unimportant stuff to reduce clutter
	gdbout := StringReplace(gdbout,#26,'->',[rfReplaceAll]);
	//gdbout := StringReplace(gdbout,'->->pre-prompt'#13#10,'',[rfReplaceAll]);
	//gdbout := StringReplace(gdbout,'->->prompt'#13#10,'',[rfReplaceAll]);
	//gdbout := StringReplace(gdbout,'->->post-prompt'#13#10,'',[rfReplaceAll]);

	MainForm.DebugOutput.Lines.Add(gdbout);

	//MainForm.DebugOutput.Lines.Add('---------------------------------------------------------');
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
		s := GetNextLine;
		curpos := oldpos;

		// Hack fix to catch register dump
		if Assigned(Registers) then
			if StartsStr('rax ',s) or StartsStr('eax',s) then
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
	else if SameStr(s,'frame-source-file') then
		result := TFrameSourceFile
	else if SameStr(s,'frame-source-line') then
		result := TFrameSourceLine
	else if SameStr(s,'frame-function-name') then
		result := TFrameFunctionName
	else if SameStr(s,'frame-begin') then
		result := TFrameBegin
	else if SameStr(s,'frame-end') then
		result := TFrameEnd
	else if SameStr(s,'source') then
		result := TSource
	else if SameStr(s,'exited') then
		result := TExit
	else if SameStr(s,'value-history-value') then
		result := TValueHistory
	else if (curpos = len) then
		result := TEOF
	else
		result := TUnknown;
end;

procedure TDebugReader.Analyze;
var
	s,t : AnsiString;
	i,x,y : integer; // dump
	wvar : PWatchVar;
	reg : PRegister;
	trace : PTrace;
begin
	evalvalue := '';
	len := Length(gdbout);
	curpos := 1;

	while curpos < len do begin
		case GetNextAnnotation of
			TValueHistory : begin
				evalvalue := GetNextLine; // value
				Synchronize(SyncEvaluate);
			end;
			TExit : begin
				Synchronize(SyncExited);
			end;
			TFrameBegin : begin
				s := GetNextLine;
				if StartsStr('#',s) and Assigned(Backtrace) then begin

					trace := new(PTrace);

					if not FindAnnotation(TFrameFunctionName) then Exit;

					trace^.funcname := GetNextLine;

					if not FindAnnotation(TFrameSourceFile) then Exit;

					trace^.filename := GetNextLine;

					if not FindAnnotation(TFrameSourceLine) then Exit;

					trace^.line := GetNextLine;

					Backtrace.Add(trace);

					if not FindAnnotation(TFrameEnd) then Exit;

					if PeekAnnotation <> TFrameBegin then begin
						// End of stack trace dump!
						Synchronize(SyncBacktraceReady);
					end;
				end;
			end;
			TInfoAsm : begin

				// Skip info messages
				s := GetNextLine; // Dump of ... foo()

				// the current function name will be saved at index 0
				Disassembly.Add(Copy(s,37,Length(s)-37));

				s := GetNextLine;

				repeat
					Disassembly.Add(s);
					s := GetNextLine;
				until SameStr('End of assembler dump.',s);

				// Is Disassembly assigned? Assume CPU window called for this
				Synchronize(SyncDisassemblerReady);
			end;
			TInfoReg : begin
				// Scan all registers until end of gdbout

				s := GetNextLine;

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

					s := GetNextLine;

				until StartsStr(#26#26,s);

				// Is Registers assigned? Assume CPU window called for this
				Synchronize(SyncRegistersReady);
			end;
			TErrorBegin : begin
				s := GetNextLine; // error text
				if StartsStr('No symbol "',s) then begin
					x := Pos('"',s);
					y := GetLastPos('"',s);
					t := Copy(s,x+1,y-x-1);

					// Update current...
					for I := 0 to DebugTree.Items.Count - 1 do begin
						wvar := PWatchVar(DebugTree.Items[I].Data);
						if SameStr(wvar^.name,t) then begin

							wvar^.value := 'Not found in current context';
							DebugTree.Items[i].Text := wvar^.name + ' = ' + wvar^.value;
							break;
						end;
					end;

					Synchronize(SyncRefreshWatchVars);
				end;
			end;
			TDisplayBegin : begin

				GetNextLine; // watch index

				if not FindAnnotation(TDisplayExpression) then Exit;

				s := GetNextLine; // variable name

				if not FindAnnotation(TDisplayExpression) then Exit;

				t := GetNextLine; // variable value

				// Update...
				for I := 0 to DebugTree.Items.Count - 1 do begin
					wvar := PWatchVar(DebugTree.Items[I].Data);
					if SameStr(wvar^.name,s) then begin
						wvar^.value := t;
						DebugTree.Items[I].Text := wvar^.name + ' = ' + wvar^.value;
						break;
					end;
				end;
			end;
			{TFrameSourceFile : begin // Current file is on the next line
				bfile := GetNextLine;
			end;
			TFrameSourceLine : begin // Current line is on the next line
				bline := StrToInt(GetNextLine);

				Synchronize(SyncGotoBreakpoint);

				// Update vars when scope changes!
				Synchronize(SyncRefreshWatchVars);
			end;
			TFrameFunctionName : begin // Current function is on the next line
				bfunc := GetNextLine;
			end;}
			TSource: begin // source filename:line:offset:beg/middle/end:addr
				s := TrimLeft(GetRemainingLine);

				// remove offset, beg/middle/end, addr
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

				Synchronize(SyncGotoBreakpoint);

				// Update vars when scope changes
				Synchronize(SyncRefreshWatchVars);
			end;
		end;
	end;

	Synchronize(SyncOutput);
end;

procedure TDebugReader.Execute;
var
	tmp : array [0..4096] of char;
	bytesread : DWORD;
begin
	while not Terminated do begin

		FillChar(tmp,4096,0);

		// ReadFile returns when there's something to read (GDB does NOT always prompt when ready?)
		if not ReadFile(hPipeRead, tmp, 4096, bytesread, nil) or (bytesread = 0) then break;

		gdbout := gdbout + tmp;

		if not Terminated and (Pos('(gdb) ',gdbout) > 0) then begin
			Analyze;
			gdbout := '';
		end;
	end;
end;

end.
