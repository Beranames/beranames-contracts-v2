
testnet--deploy-system: 
	@forge script script/System.s.sol:ContractScript \
	--private-key ${WALLET_DEV_PRIVATE_KEY} \
	--rpc-url "${RPC_BASE_URL_BERA_TESTNET}${RPC_API_KEY}" \
	--broadcast -vvvvv

anvil--deploy-system: 
	forge script script/System.s.sol:ContractScript \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--rpc-url "http://127.0.0.1:8545" \
	--broadcast -vvvvv --force
