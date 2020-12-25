const fs = require('fs')
const weaver = require(__dirname + "\\weaver.js")
module.exports = {}
module.exports.highlight = function(opt) {
	let {compile_args: compile_args, open_page: open_page, open_page_on_fail: open_page_on_fail} = opt
	const child_process = require('child_process')
	let fname = process.env['devcpp.file.name']
	let source = fs.readFileSync(fname).toString().replace(/\n/g, "\r\n").replace(/\r+/, "\r")
	let newdir = fname + ".dir"
	let compiler = fname.match(/\.c$/) ? "gcc.exe" : "g++.exe"
	try { fs.mkdirSync(newdir)  } catch (e) { }

	let sourcemap = weaver.prepare_source_map(source)
	const EXENAME = process.env['devcpp.file.name'] + ".exe"
	
	
	const big5 = compile_args || ["-Wall", "-Werror", "-Wextra", "-pedantic", "-Wconversion"] 
	const args = [fname].concat(big5).concat(["-o", EXENAME])
	const compile_info  = child_process.spawnSync(process.env['devcpp.compiler.dir'] + '\\bin\\' + compiler, args)
	let cerr = compile_info.stderr.toString()
	weaver.do_compiler_output(cerr, (num, line) => sourcemap.addText(num, "compiler", line), fname)
	
	
	const cppcheckargs = "-q --enable=all --error-exitcode=1 ".split(" ").concat([fname])
	const cppcheck_info  = child_process.spawnSync(process.env['devcpp.dir'] + '\\Vendor\\cppcheck\\cppcheck.exe', cppcheckargs)
	cerr = cppcheck_info.stderr.toString()
	weaver.do_generic_output(cerr, (num, line) => sourcemap.addText(num, "cppcheck", line), fname)
	
	const object_code = escape(JSON.stringify({
		source,
		stdout: compile_info.stdout.toString(),
		stderr: compile_info.stderr.toString(),
		map: sourcemap,
		filename: fname,
		output: [],
	}))
	open_page = open_page || compile_info.status != 0
	
	html = fs.readFileSync(__dirname + "/hl.html").toString()
	html = html.replace("<%ESCAPED_CONTENT%>", object_code)
	fs.writeFileSync(newdir + "/highlight.html", html)
	if (open_page) {
		require('child_process').exec('start "" "' + newdir + '\\highlight.html"')
	}
	return compile_info
}



