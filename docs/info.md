https://docs.polkadot.com/smart-contracts/get-started/

Item,TestNet (Polkadot Hub TestNet),Mainnet (Polkadot Hub)
Network Name,Polkadot Hub TestNet,Polkadot Hub
Chain ID,420420417,420420419
Currency Symbol,PAS,DOT
ETH-RPC (for MetaMask/Foundry/Hardhat/Remix),"https://eth-rpc-testnet.polkadot.io/ 
or https://services.polkadothub-rpc.com/testnet/","https://eth-rpc.polkadot.io/ 
or https://services.polkadothub-rpc.com/mainnet/"
Block Explorers,"https://blockscout-testnet.polkadot.io/ 
https://polkadot.testnet.routescan.io/",https://blockscout.polkadot.io/
Faucet (get test tokens),https://faucet.polkadot.io/ (select Polkadot Hub TestNet → paste address → Get PAS),Real DOT (use only after testing)
Wallet,MetaMask (add custom network) or Talisman,Same





/aura
│
├── apps/
│   ├── frontend/        → Next.js dashboard
│   └── agent-ui/        → (optional AI interface)
│
├── services/
│   ├── agent/           → Eliza AI brain
│   ├── executor/        → Gelato / scripts
│   ├── router/          → LI.FI → XCM later
│   └── engine/          → Rust (ZK / compute)
│
├── contracts/
│   ├── commander/       → Solidity vault (Yearn-based)
│
├── substrate/
│   └── polkadot-sdk/    → (external OR submodule, not mixed)
│
├── scripts/
│   ├── deploy/          → deploy contracts
│   ├── test/            → test flows
│
├── config/
│   ├── chains.json
│   ├── strategy.json
│
├── README.md
└── package.json