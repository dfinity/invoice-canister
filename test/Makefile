default:
	moc $(shell vessel sources) -wasi-system-api -o Test.wasm *InvoiceTest.mo && wasmtime Test.wasm
	rm -f Test.wasm
