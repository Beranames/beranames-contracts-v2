
testnet--deploy-system:
	forge script script/System.s.sol:ContractScript \
	--private-key ${WALLET_DEV_PRIVATE_KEY} \
	--rpc-url "https://bartio.rpc.berachain.com" \
	--broadcast -vvvvv

testnet--deploy-and-verify-system:
	forge script script/System.s.sol:ContractScript \
	--private-key ${WALLET_DEV_PRIVATE_KEY} \
	--broadcast --verify \
	--rpc-url "https://bartio.rpc.berachain.com" \
	--verifier-url "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan" \
	--etherscan-api-key "verifyContract" \
	--gas-price 6000000000000

testnet--mint-name:
	forge script script/MintScript.s.sol:MintScript \
	--private-key ${WALLET_DEV_PRIVATE_KEY} \
	--rpc-url "https://bartio.rpc.berachain.com" \
	--broadcast -vvvvv

anvil--deploy-system: 
	forge script script/System.s.sol:ContractScript \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--rpc-url "http://127.0.0.1:8545" \
	--broadcast -vvvvv --force

anvil--mint-name:
	forge script script/MintScript.s.sol:MintScript \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--rpc-url "http://127.0.0.1:8545" \
	--broadcast -vvvvv
