const hlbase   = require(__dirname + '\\hlbase')
const SDL2PATH = process.env['devcpp.dir'] + "\\Vendor\\SDL2"
const TARGET   = process.env['devcpp.compiler.name'].indexOf("64-bit") > -1 ? "x86_64-w64-mingw32" : "i686-w64-mingw32"
const EXENAME = process.env['devcpp.file.name'] + ".exe"
const SDL2     = `-o ${EXENAME} -I${SDL2PATH}\\${TARGET}\\include\\SDL2 -L${SDL2PATH}\\${TARGET}\\lib -lmingw32 -lSDL2main -lSDL2`
const cp = hlbase.highlight({compile_args: SDL2.split(" "), open_page_on_fail: true})
process.env.path += `;${SDL2PATH}\\${TARGET}\\bin`
const rp = require('child_process').spawnSync(EXENAME, {cwd: process.env['devcpp.file.dir'], stdio: [0, 1, 2]})
