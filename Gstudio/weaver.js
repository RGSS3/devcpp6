let weaver = module.exports = {}
weaver.do_compiler_output = function(out, add, fname) {
	if (out.match(/\S/)) {
		let current = -1
		out.split("\n").forEach(line => {
			if (line.match("^((..[^:]+: In function)|(cc1(plus)?\.exe)|\s*note:)")) {
		  		return;  //  discard	
		  	}
		  	if (line.match("^..[^:]+: In function")) {
	  			return;  //  discard	
	  		}
	  		let c = line.match("^(..[^:]+):(\\d+):(\\d+):(.*)")
	  		if (!c) {
	  			add(current, line)
	  		    return;
	  		}
	  		if (fname && c[1] != fname) {
	  			current = -1
	  			return;
	  		}
	  		let lnn = +c[2];
	  		let col = +c[3];
	  		let code = "";
	  		current = lnn;
	  		add(lnn, line)
	    })
	}	
}

weaver.do_generic_output = function(out, add, fname) {
	if (out.match(/\S/)) {
		let current = -1
		out.split("\n").forEach(line => {
			let c = line.match("^(..[^:]+):(\\d+):(\\d+):(.*)")
	  		if (!c) {
	  			if (current != -1) { 
	  				add(current, line)
	  			}
	  		    return;
	  		}
	  		if (fname && c[1] != fname) {
	  			current = -1
	  			return;
	  		}
	  		let lnn = +c[2];
	  		let col = +c[3];
	  		let code = "";
	  		current = lnn;
	  		add(lnn, line)
	    })
	}	
}

weaver.prepare_source_map = function(source) {
	let sourcelines = source.split("\n")
	let sourcemap = []
	for (let i = 0; i < sourcelines.length; ++i) {
		sourcemap[i + 1] = {source: sourcelines[i], tagged: false, info: {}};
	}
	sourcemap.push({source: "", tagged: true, info: {}})
	sourcemap.addText = (index, type, text) => {
		if (sourcemap[index]) {
			let obj = sourcemap[index]
			obj.tagged = true;
			obj.info[type] = obj.info[type] || []
			obj.info[type].push(text)
		}
	}
	return sourcemap
}
