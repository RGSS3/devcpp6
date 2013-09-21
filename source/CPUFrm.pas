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

unit CPUFrm;

interface

uses
{$IFDEF WIN32}
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, SynEdit, SynEditTypes, ClipBrd, StrUtils, ComCtrls, ExtCtrls, Menus;
{$ENDIF}
{$IFDEF LINUX}
  SysUtils, Variants, Classes, QGraphics, QControls, QForms,
  QDialogs, QStdCtrls, QButtons, QSynEdit;
{$ENDIF}

type

  PRegister = ^TRegister;
  TRegister = record
    name : AnsiString;
    value : AnsiString;
  end;

  TCPUForm = class(TForm)
    edFunc: TEdit;
    lblFunc: TLabel;
    CodeList: TSynEdit;
    RegisterListbox: TListView;
    DisasPanel: TPanel;
    StackTrace: TListView;
    RadioATT: TRadioButton;
    RadioIntel: TRadioButton;
    lblBacktrace: TLabel;
    CPUPopup: TPopupMenu;
    MenuCopy: TMenuItem;
    MenuCopyAll: TMenuItem;
    MenuPaste: TMenuItem;
    MenuCut: TMenuItem;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure edFuncKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure gbSyntaxClick(Sender: TObject);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuCopyAllClick(Sender: TObject);
    procedure MenuPasteClick(Sender: TObject);
    procedure MenuCutClick(Sender: TObject);
    procedure StackTraceClick(Sender: TObject);
  private
    fRegisters : TList;
    fAssembler : TStringList;
    fBacktrace : TList;

    procedure LoadText;
  public
    procedure OnAssemblerReady;
    procedure OnRegistersReady;
    procedure OnBacktraceReady;
  end;

var
  CPUForm: TCPUForm = nil;

implementation

uses
  main, version, MultiLangSupport, debugger, debugreader, datamod, utils,
  devcfg, editor, Types;

{$R *.dfm}

procedure TCPUForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
	I : integer;
begin
	for I := 0 to fRegisters.Count - 1 do
		Dispose(PRegister(fRegisters.Items[I]));
	fRegisters.Free;

	fAssembler.Free;

	for I := 0 to fBacktrace.Count - 1 do
		Dispose(PTrace(fBacktrace.Items[I]));
	fBackTrace.Free;

	MainForm.fDebugger.SetRegisters(nil);
	MainForm.fDebugger.SetDisassembly(nil);
	MainForm.fDebugger.SetBacktrace(nil);

	action := caFree;
	CPUForm := nil;
end;

procedure TCPUForm.edFuncKeyPress(Sender: TObject; var Key: Char);
var
	propercmd : AnsiString;
begin
	if MainForm.fDebugger.Executing then begin
		if Key = Chr(VK_RETURN) then begin
			Key := #0;

			// Although GDB omits void the C++ way in its own output, it only accepts C style empty parameter lists for input...
			propercmd := TEdit(edFunc).Text;
			if EndsStr('()',propercmd) then
				propercmd := ReplaceLastStr(propercmd,'()','(void)');
			MainForm.fDebugger.SendCommand('disas',propercmd);
		end;
	end;
end;

procedure TCPUForm.LoadText;
begin
	// Set interface font
	Font.Name := devData.InterfaceFont;
	Font.Size := devData.InterfaceFontSize;

	Caption := Lang[ID_CPU_CAPTION];
	lblFunc.Caption := Lang[ID_CPU_FUNC];
	lblBacktrace.Caption := Lang[ID_DEB_BACKTRACE];

	MenuCut.Caption := Lang[ID_ITEM_CUT];
	MenuCopy.Caption := Lang[ID_ITEM_COPY];
	MenuCopyAll.Caption := Lang[ID_ITEM_COPYALL];
	MenuPaste.Caption := Lang[ID_ITEM_PASTE];
end;

procedure TCPUForm.OnBacktraceReady;
var
	I : integer;
	item : TListItem;
begin
	StackTrace.Items.BeginUpdate;
	StackTrace.Clear;
	for I := 0 to fBacktrace.Count - 1 do begin
		item := StackTrace.Items.Add;
		item.Caption := PTrace(fBacktrace.Items[I])^.funcname;
		item.SubItems.Add(PTrace(fBacktrace.Items[I])^.filename);
		item.SubItems.Add(PTrace(fBacktrace.Items[I])^.line);
	end;
	StackTrace.Items.EndUpdate;

	// Free list for reuse
	for I := 0 to fBacktrace.Count - 1 do
		Dispose(PTrace(fBacktrace.Items[I]));
	fBacktrace.Clear;
end;

procedure TCPUForm.OnAssemblerReady;
var
	I,activeline : integer;
begin
	activeline := -1;
	edFunc.Text := fAssembler.Strings[0];

	CodeList.BeginUpdate;
	CodeList.Clear;
	for I := 1 to fAssembler.Count - 1 do begin
		CodeList.Lines.Add(fAssembler.Strings[i]);
		if StartsStr('=>',fAssembler.Strings[i]) then
			activeline := i + 1;
	end;
	CodeList.EndUpdate;

	// Free list for reuse
	fAssembler.Clear;

	if activeline <> -1 then
		CodeList.CaretXY := BufferCoord(1,activeline);
end;

procedure TCPUForm.OnRegistersReady;
var
	item : TListItem;
	I : integer;
begin
	RegisterListbox.Items.BeginUpdate;
	RegisterListBox.Clear;
	for I := 0 to fRegisters.Count - 1 do begin
		item := RegisterListbox.Items.Add;
		item.Caption := UpperCase(PRegister(fRegisters.Items[I])^.name);
		item.SubItems.Add(PRegister(fRegisters.Items[I])^.value);
	end;
	RegisterListBox.Items.EndUpdate;

	// Free list for reuse
	for I := 0 to fRegisters.Count - 1 do
		Dispose(PRegister(fRegisters.Items[I]));
	fRegisters.Clear;
end;

procedure TCPUForm.FormCreate(Sender: TObject);
begin
	LoadText;

	RadioATT.Checked := devData.UseATTSyntax;
	RadioIntel.Checked := not devData.UseATTSyntax;

	fRegisters := TList.Create;
	fAssembler := TStringList.Create;
	fBacktrace := TList.Create;

	if MainForm.fDebugger.Executing then begin

		// Load the registers...
		MainForm.fDebugger.SetRegisters(fRegisters);
		MainForm.fDebugger.SendCommand('info','registers');

		// Set disassembly flavor and load the current function
		MainForm.fDebugger.SetDisassembly(fAssembler);
		if devData.UseATTSyntax then // gbSyntaxClick has NOT been called yet...
			gbSyntaxClick(nil);

		// Obtain stack trace too
		MainForm.fDebugger.SetBacktrace(fBacktrace);
		MainForm.fDebugger.SendCommand('backtrace','');
	end;
end;

procedure TCPUForm.gbSyntaxClick(Sender: TObject);
var
	key : Char;
begin
	// Set disassembly flavor
	if RadioAtt.Checked then begin
		MainForm.fDebugger.SendCommand('set disassembly-flavor','att');
		RadioIntel.Checked := false;
		devData.UseATTSyntax := true;
	end else if RadioIntel.Checked then begin
		MainForm.fDebugger.SendCommand('set disassembly-flavor','intel');
		RadioAtt.Checked := false;
		devData.UseATTSyntax := false;
	end;

	// load the current function
	key := Chr(VK_RETURN);
	edFuncKeyPress(nil,key);
end;

procedure TCPUForm.MenuCopyClick(Sender: TObject);
begin
	if edFunc.Focused then
		edFunc.CopyToClipboard
	else if CodeList.Focused then
		CodeList.CopyToClipboard
	else if StackTrace.Focused then
		Clipboard.AsText := GetPrettyLine(StackTrace)
	else if RegisterListbox.Focused then
		Clipboard.AsText := GetPrettyLine(RegisterListbox);
end;

procedure TCPUForm.MenuCopyAllClick(Sender: TObject);
var
	i:integer;
begin
	if edFunc.Focused then
		edFunc.CopyToClipboard
	else if CodeList.Focused then
		CodeList.CopyToClipboard
	else if StackTrace.Focused then begin
		ClipBoard.AsText := '';
		for i:=0 to pred(StackTrace.Items.Count) do
			Clipboard.AsText := Clipboard.AsText + GetPrettyLine(StackTrace,i) + #13#10;
	end else if RegisterListbox.Focused then begin
		ClipBoard.AsText := '';
		for i:=0 to pred(RegisterListbox.Items.Count) do
			Clipboard.AsText := Clipboard.AsText + GetPrettyLine(RegisterListbox,i) + #13#10;
	end;
end;

procedure TCPUForm.MenuPasteClick(Sender: TObject);
begin
	if edFunc.Focused then
		edFunc.PasteFromClipboard;
end;

procedure TCPUForm.MenuCutClick(Sender: TObject);
begin
	if edFunc.Focused then
		edFunc.CutToClipboard;
end;

procedure TCPUForm.StackTraceClick(Sender: TObject);
var
	sel : TListItem;
	e : TEditor;
begin
	sel := StackTrace.Selected;
	if Assigned(sel) then begin
		e := MainForm.GetEditorFromFileName(sel.SubItems[0]);
		if Assigned(e) then
			e.GotoLineNr(StrToIntDef(sel.SubItems[1],1));
	end;
end;

end.
