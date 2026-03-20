import { createPublicClient, http, createWalletClient, custom } from 'viem'
import 'viem/window';


const transport = http('https://eth-rpc-testnet.polkadot.io/')

// Configure the Passet Hub chain
export const passetHub = {
  id: 420420417,
  name: 'Polkadot Hub Testnet ',
  network: 'polkadot-hub-testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'PAS',
    symbol: 'PAS',
  },
  rpcUrls: {
    default: {
      http: ['https://eth-rpc-testnet.polkadot.io/'],
    },
  },
} as const

// Create a public client for reading data
export const publicClient = createPublicClient({
  chain: passetHub,
  transport
})

// Create a wallet client for signing transactions
export const getWalletClient = async () => {
  if (typeof window !== 'undefined' && window.ethereum) {
    const [account] = await window.ethereum.request({ method: 'eth_requestAccounts' });
    return createWalletClient({
      chain: passetHub,
      transport: custom(window.ethereum),
      account,
    });
  }
  throw new Error('No Ethereum browser provider detected');
};