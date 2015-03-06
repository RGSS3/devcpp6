#ifndef VARIABLE_INCLUDE
#define VARIABLE_INCLUDE

#include <cstring> // strdup
#include "Console.h" // console writing
#include "Object.h" // var type union, cannot forward declare
#include "Path.h" // var type union, cannot forward declare
#include "float3.h" // var type union, cannot forward declare
#include "Timer.h" // var type union, cannot forward declare

enum VarKind {
    vtInt,
    vtFloat,
    vtString,
    vtObject,
    vtPath, // bezier access
    vtFloat3,
    vtTimer,
    vtUnknown,
};

class Var {
		void SetTypeFromString(const char* type);
	public:
		Var(VarKind type,const char* name,int level); // set from generic
		Var(const char* type,const char* name,int level); // set from string type
		~Var();
		int GetIntValue();
		float GetFloatValue();
		char* GetStringValue();
		float3* GetFloat3Value();
		bool Equals(Var* rvalue);
		bool Greater(Var* rvalue);
		bool Less(Var* rvalue);

		char* name;
		VarKind type;
		int level;
		union {
			int intvalue;
			float floatvalue;
			char* stringvalue;
			Object* objectvalue;
			Path* pathvalue;
			float3* float3value;
			Timer* timervalue;
		};
};

#endif
