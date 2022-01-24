default:
	moc $(shell vessel sources) -wasi-system-api -o Test.wasm Test.mo && wasmtime Test.wasm
	rm -f Test.wasm
