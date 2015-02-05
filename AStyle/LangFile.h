#ifndef LANGFILE_H
#define LANGFILE_H

#include <vector>
using std::vector;
#include <string>
using std::string;
#include <stdio.h>
#include <windows.h>

struct LangItem {
	int ID;
	string text;
};

class LangFile {
	private:
		HWND LogBox;
		LangItem* FindID(int ID);
		vector<LangItem> contents;
		void Log(const char* text);

	public:
		LangFile(HWND LogBox);
		LangFile(HWND LogBox,const char* FileName);
		~LangFile();
		void OpenFile(const char* FileName);
};

#endif