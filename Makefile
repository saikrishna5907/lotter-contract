build:; forge build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops --no-commit && forge install smartcontractkit/chainlink-brownie-contracts --no-commit && forge install foundry-rs/forge-std --no-commit

# Update Dependencies
update:; forge update

test :; forge test

coverage-report:; forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

testReport:; make coverage-report -w

snapshot :; forge snapshot

format :; forge fmt

NETWORK_ARGS := --rpc-url http://localhost:8545 --account Account1 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	forge script script/DeployFundCollector.s.sol:DeployFundCollector $(NETWORK_ARGS)

# As of writing, the Alchemy zkSync RPC URL is not working correctly 
deploy-zk:
	forge create src/FundMe.sol:FundMe --rpc-url http://127.0.0.1:8011 --account default --constructor-args $(shell forge create test/mock/MockV3Aggregator.sol:MockV3Aggregator --rpc-url http://127.0.0.1:8011 --private-key $(DEFAULT_ZKSYNC_LOCAL_KEY) --constructor-args 8 200000000000 --legacy --zksync | grep "Deployed to:" | awk '{print $$3}') --legacy --zksync

deploy-zk-sepolia:
	forge create src/FundMe.sol:FundMe --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default --constructor-args 0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF --legacy --zksync

# For deploying Interactions.s.sol:FundFundMe as well as for Interactions.s.sol:WithdrawFundMe we have to include a sender's address `--sender <ADDRESS>`
SENDER_ADDRESS := <sender's address>
 
fund:
	@forge script script/Interactions.s.sol:DonateFundCollector --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

withdraw:
	@forge script script/Interactions.s.sol:WithDrawFundCollector --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)