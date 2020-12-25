const fs = require('fs')
const child_process = require('child_process')
const weaver = require(__dirname + "\\weaver.js")
const EXENAME = process.env['devcpp.file.name'] + ".exe"
if (!fs.existsSync(EXENAME)) {
	console.log("Not compiled")	
} else {
	let fname = process.env['devcpp.file.name']
	let source = fs.readFileSync(fname).toString().replace(/\n/g, "\r\n").replace(/\r+/, "\r")
	let newdir = fname + ".dir"
	try { fs.mkdirSync(newdir)  } catch (e) { }
	const compile_info  = child_process.spawnSync(EXENAME, {stdio: [0, 1, 'pipe']})
	let cerr = compile_info.stderr.toString().replace(/\r\n/g, "\n").replace(/\r+/, "")
	let sourcemap = weaver.prepare_source_map(source)
	let output = []
	weaver.do_generic_output(cerr, (num, line) => {if (!line.match(/^\s*$/)) output.push([num, line])}, fname)
	const object_code = escape(JSON.stringify({
			source,
			stdout: null,
			stderr: compile_info.stderr.toString(),
			map: null,
			filename: fname,
			output,
	}))
	open_page = true
		
	html = fs.readFileSync(__dirname + "/hl.html").toString()
	html = html.replace("<%ESCAPED_CONTENT%>", object_code)
	fs.writeFileSync(newdir + "/highlight-run.html", html)
	if (open_page) {
		require('child_process').exec('start "" "' + newdir + '\\highlight-run.html"')
	}
}
