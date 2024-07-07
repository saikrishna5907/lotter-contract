-include .env

.PHONY: all test deploy

all: clean remove install update build

build:; forge build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops --no-commit && forge install smartcontractkit/chainlink-brownie-contracts --no-commit && forge install foundry-rs/forge-std --no-commit && forge install transmissions11/solmate --no-commit

# Update Dependencies
update:; forge update

test :; forge test

coverage-report:; forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

testReport:; make coverage-report -w

snapshot :; forge snapshot

format :; forge fmt

deploy-sepolia:
	forge script script/DeployLottery.s.sol:DeployLottery --rpc-url $(ZKSYNC_SEPOLIA_RPC_URL) --account Account1 --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-anvil:
	forge script script/DeployLottery.s.sol:DeployLottery --rpc-url http://localhost:8545 --account Account1 --broadcast

# As of writing, the Alchemy zkSync RPC URL is not working correctly 
deploy-zk:
	forge create src/DeployLottery.sol:DeployLottery --rpc-url http://127.0.0.1:8011 --account default --constructor-args $(shell forge create test/mock/MockV3Aggregator.sol:MockV3Aggregator --rpc-url http://127.0.0.1:8011 --private-key $(DEFAULT_ZKSYNC_LOCAL_KEY) --constructor-args 8 200000000000 --legacy --zksync | grep "Deployed to:" | awk '{print $$3}') --legacy --zksync

deploy-zk-sepolia:
	forge create src/DeployLottery.sol:DeployLottery --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default --constructor-args 0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF --legacy --zksync
 

