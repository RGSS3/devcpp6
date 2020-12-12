const fs = require('fs')
module.exports = {}
module.exports.highlight = function(opt) {
	let {compile_args: compile_args, open_page: open_page, open_page_on_fail: open_page_on_fail} = opt
	const child_process = require('child_process')
	let fname = process.env['devcpp.file.name']
	let source = fs.readFileSync(fname).toString().replace(/\n/g, "\r\n").replace(/\r+/, "\r")
	let newdir = fname + ".dir"
	try { fs.mkdirSync(newdir)  } catch (e) {}
	const sourcelines = source.split("\n")
	let sourcemap = []
	for (let i = 0; i < sourcelines.length; ++i) {
		sourcemap[i + 1] = {source: sourcelines[i], tagged: false, info: {}};
	}
	
	sourcemap.push({source: "", tagged: true, info: {}})
	const addText = (index, type, text) => {
		if (sourcemap[index]) {
			let obj = sourcemap[index]
			obj.tagged = true;
			obj.info[type] = obj.info[type] || []
			obj.info[type].push(text)
		}
	}
	
	
	
	const big5 = compile_args || ["-Wall", "-Werror", "-Wextra", "-pedantic", "-Wconversion"] 
	const args = [fname].concat(big5)
	const compile_info  = child_process.spawnSync(process.env['devcpp.compiler.dir'] + '\\bin\\gcc.exe', args)
	let cerr = compile_info.stderr.toString()
	if (cerr.match(/\S/)) {
		let current = -1
		cerr.split("\n").forEach(line => {
			if (line.match("^((..[^:]+: In function)|(cc1(plus)?\.exe)|\s*note:)")) {
		  		return;  //  discard	
		  	}
		  	if (line.match("^..[^:]+: In function")) {
	  			return;  //  discard	
	  		}
	  		let c = line.match("^(..[^:]+):(\\d+):(\\d+):(.*)")
	  		if (!c) {
	  			addText(current, "compiler", line)
	  		    return;
	  		}
	  		if (c[1] != fname) {
	  			current = -1
	  			return;
	  		}
	  		let lnn = +c[2];
	  		let col = +c[3];
	  		let code = "";
	  		current = lnn;
	  		addText(lnn, "compiler", line)
	    })
	}
	
	
	const cppcheckargs = "-q --enable=all --error-exitcode=1 ".split(" ").concat([fname])
	const cppcheck_info  = child_process.spawnSync(process.env['devcpp.dir'] + '\\Vendor\\cppcheck\\cppcheck.exe', cppcheckargs)
	cerr = cppcheck_info.stderr.toString()
	if (cerr.match(/\S/)) {
		let current = -1
		cerr.split("\n").forEach(line => {
			let c = line.match("^(..[^:]+):(\\d+):(\\d+):(.*)")
	  		if (!c) {
	  			addText(current, "cppcheck", line)
	  		    return;
	  		}
	  		if (c[1] != fname) {
	  			current = -1
	  			return;
	  		}
	  		let lnn = +c[2];
	  		let col = +c[3];
	  		let code = "";
	  		current = lnn;
	  		addText(lnn, "cppcheck", line)
	    })
	}
	
	
	const object_code = escape(JSON.stringify({
		source,
		stdout: compile_info.stdout.toString(),
		stderr: compile_info.stderr.toString(),
		map: sourcemap,
		filename: fname
	}))
	open_page = open_page || compile_info.status != 0
	
	html = fs.readFileSync(__dirname + "/hl.html").toString()
	html = html.replace("<%ESCAPED_CONTENT%>", object_code)
	fs.writeFileSync(newdir + "/highlight.html", html)
	if (open_page) {
		require('child_process').exec('start ' + newdir + "\\highlight.html")
	}
	return compile_info
}
